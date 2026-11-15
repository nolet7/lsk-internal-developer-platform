"""LSK Internal Developer Platform: safe service-catalog and governed request API.

Infrastructure is never provisioned from an API handler. Approved requests yield
a deterministic GitOps handoff plan for a separate reviewed delivery pipeline.
"""
from __future__ import annotations

from app.middleware import EnterpriseRequestMiddleware

import hashlib
import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import uuid4

import jwt
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, String, UniqueConstraint, create_engine, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL must be configured")
engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=5, max_overflow=2)
SessionLocal = sessionmaker(engine, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

def utcnow() -> datetime:
    return datetime.now(timezone.utc)

class PlatformRequest(Base):
    __tablename__ = "platform_requests"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    tenant_id: Mapped[str] = mapped_column(String(100), index=True)
    requester: Mapped[str] = mapped_column(String(200))
    idempotency_key: Mapped[str] = mapped_column(String(128))
    payload_hash: Mapped[str] = mapped_column(String(64))
    template: Mapped[str] = mapped_column(String(80))
    template_version: Mapped[str] = mapped_column(String(20))
    service_name: Mapped[str] = mapped_column(String(63))
    environment: Mapped[str] = mapped_column(String(20))
    justification: Mapped[str] = mapped_column(String(1000))
    state: Mapped[str] = mapped_column(String(24), default="pending")
    approver: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (UniqueConstraint("tenant_id", "idempotency_key"),)

class AuditEvent(Base):
    __tablename__ = "audit_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    tenant_id: Mapped[str] = mapped_column(String(100), index=True)
    request_id: Mapped[str] = mapped_column(String(36), index=True)
    actor: Mapped[str] = mapped_column(String(200))
    action: Mapped[str] = mapped_column(String(30))
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

CATALOG = {
    "ecs-fargate-api": {
        "version": "1.0.0",
        "description": "Internal ECS Fargate API behind a private HTTPS ALB, least-privilege task identity and autoscaling",
        "parameters": {"cpu": "512", "memory": "1024", "max_instances": 2},
        "network": "private-alb",
    },
    "managed-postgres": {
        "version": "1.0.0",
        "description": "Amazon RDS PostgreSQL private Multi-AZ request with reviewed backups and subnet group",
        "parameters": {"engine": "POSTGRES_16", "backup": True},
        "network": "private-connection-review",
    },
    "private-service-connectivity": {
        "version": "1.0.0",
        "description": "Connectivity request for a separately reviewed VPC/network change",
        "parameters": {"egress": "restricted", "approval": "network-security"},
        "network": "private",
    },
}

@dataclass(frozen=True)
class Principal:
    subject: str
    tenant_id: str
    scopes: frozenset[str]

bearer = HTTPBearer(auto_error=False)
def get_principal(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)) -> Principal:
    if not credentials:
        raise HTTPException(401, "Bearer token required")
    issuer, audience, jwks = (os.getenv("OIDC_ISSUER"), os.getenv("OIDC_AUDIENCE"), os.getenv("OIDC_JWKS_URL"))
    if not all([issuer, audience, jwks]):
        raise HTTPException(503, "OIDC not configured")
    try:
        key = PyJWKClient(jwks).get_signing_key_from_jwt(credentials.credentials)
        claims = jwt.decode(
            credentials.credentials, key.key, algorithms=["RS256"], issuer=issuer,
            audience=audience, options={"require": ["sub", "iss", "aud", "iat", "exp"]},
        )
    except Exception as exc:
        raise HTTPException(401, "Invalid access token") from exc
    tenant = claims.get("tenant_id")
    if not isinstance(tenant, str) or not tenant:
        raise HTTPException(403, "Tenant claim required")
    from app.regional_policy import enforce_residency
    enforce_residency(claims, tenant)
    scopes = claims.get("scope", "")
    return Principal(claims["sub"], tenant, frozenset(scopes.split() if isinstance(scopes, str) else []))

def require(scope: str):
    def dependency(p: Principal = Depends(get_principal)) -> Principal:
        if scope not in p.scopes:
            raise HTTPException(403, "Missing required scope")
        return p
    return dependency

def get_db():
    with SessionLocal() as session:
        yield session

class RequestIn(BaseModel):
    template: str = Field(min_length=3, max_length=80)
    service_name: str = Field(pattern=r"^[a-z][a-z0-9-]{2,40}$")
    environment: str = Field(pattern=r"^(dev|stage|prod)$")
    justification: str = Field(min_length=12, max_length=1000)

app = FastAPI(title="LSK Internal Developer Platform", version="1.0.0")
app.add_middleware(EnterpriseRequestMiddleware)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.get("/readyz")
def readyz(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"status": "ready"}

@app.get("/v1/catalog")
def catalog(_p: Principal = Depends(require("catalog:read"))):
    return [{"key": key, **value} for key, value in CATALOG.items()]

def as_dict(request: PlatformRequest):
    return {
        "id": request.id, "template": request.template,
        "template_version": request.template_version, "service_name": request.service_name,
        "environment": request.environment, "state": request.state,
        "requester": request.requester, "approver": request.approver,
    }

@app.post("/v1/requests", status_code=201)
def submit(
    body: RequestIn,
    idempotency_key: str = Header(min_length=8, max_length=128, alias="Idempotency-Key"),
    p: Principal = Depends(require("platform:request")),
    db: Session = Depends(get_db),
):
    template = CATALOG.get(body.template)
    if not template:
        raise HTTPException(422, "Unknown catalog template")
    # The environment is deliberately part of the business key and approval scope.
    canonical = body.model_dump()
    digest = hashlib.sha256(json.dumps(canonical, sort_keys=True).encode()).hexdigest()
    previous = db.scalar(select(PlatformRequest).where(
        PlatformRequest.tenant_id == p.tenant_id,
        PlatformRequest.idempotency_key == idempotency_key,
    ))
    if previous:
        if previous.payload_hash != digest or previous.requester != p.subject:
            raise HTTPException(409, "Idempotency key reused for different request or actor")
        return {**as_dict(previous), "replayed": True}
    row = PlatformRequest(
        tenant_id=p.tenant_id, requester=p.subject, idempotency_key=idempotency_key,
        payload_hash=digest, template=body.template,
        template_version=template["version"], service_name=body.service_name,
        environment=body.environment, justification=body.justification,
    )
    db.add(row)
    try:
        db.flush()
        db.add(AuditEvent(tenant_id=p.tenant_id, request_id=row.id,
                          actor=p.subject, action="submitted"))
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Concurrent idempotency key conflict; retry")
    return {**as_dict(row), "replayed": False}

@app.get("/v1/requests")
def list_requests(p: Principal = Depends(require("platform:read")), db: Session = Depends(get_db)):
    rows = db.scalars(
        select(PlatformRequest).where(PlatformRequest.tenant_id == p.tenant_id)
        .order_by(PlatformRequest.created_at.desc()).limit(100)
    )
    return [as_dict(item) for item in rows]

def find_request(db: Session, tenant_id: str, request_id: str, lock: bool = False):
    query = select(PlatformRequest).where(
        PlatformRequest.id == request_id, PlatformRequest.tenant_id == tenant_id
    )
    if lock:
        query = query.with_for_update()
    request = db.scalar(query)
    if not request:
        raise HTTPException(404, "Platform request not found")
    return request

@app.post("/v1/requests/{request_id}/approve")
def approve(request_id: str, p: Principal = Depends(require("platform:approve")),
            db: Session = Depends(get_db)):
    row = find_request(db, p.tenant_id, request_id, lock=True)
    if row.requester == p.subject:
        raise HTTPException(403, "Separation of duties: no self approval")
    if row.state != "pending":
        raise HTTPException(409, "Request already decided")
    if row.environment == "prod" and "platform:approve:prod" not in p.scopes:
        raise HTTPException(403, "Production approval requires additional scope")
    row.state, row.approver = "approved", p.subject
    db.add(AuditEvent(tenant_id=p.tenant_id, request_id=row.id,
                      actor=p.subject, action="approved"))
    db.commit()
    return {**as_dict(row), "provisioned": False}

@app.post("/v1/requests/{request_id}/reject")
def reject(request_id: str, p: Principal = Depends(require("platform:approve")),
           db: Session = Depends(get_db)):
    row = find_request(db, p.tenant_id, request_id, lock=True)
    if row.requester == p.subject:
        raise HTTPException(403, "Separation of duties: no self decision")
    if row.state != "pending":
        raise HTTPException(409, "Request already decided")
    row.state, row.approver = "rejected", p.subject
    db.add(AuditEvent(tenant_id=p.tenant_id, request_id=row.id,
                      actor=p.subject, action="rejected"))
    db.commit()
    return as_dict(row)

@app.get("/v1/requests/{request_id}/gitops-plan")
def plan(request_id: str, p: Principal = Depends(require("platform:plan")),
         db: Session = Depends(get_db)):
    row = find_request(db, p.tenant_id, request_id)
    if row.state != "approved":
        raise HTTPException(409, "Independent approval required before plan export")
    spec = {
        "apiVersion": "platform.lsk.dev/v1alpha1",
        "kind": "PlatformRequest",
        "metadata": {"name": row.service_name, "labels": {"environment": row.environment}},
        "spec": {
            "requestId": row.id, "tenant": row.tenant_id, "template": row.template,
            "templateVersion": row.template_version, "environment": row.environment,
            "parameters": CATALOG[row.template]["parameters"],
            "networkPolicy": CATALOG[row.template]["network"],
        },
    }
    # Artifact only. GitOps repository PR, policy checks, and deployment are separate.
    return {
        "filename": f"{row.id}.json",
        "gitops_spec": spec,
        "provisioned": False,
        "next_action": "Commit to protected infrastructure repo, review plan, approve and apply separately",
    }

@app.get("/v1/requests/{request_id}/audit")
def audit(request_id: str, p: Principal = Depends(require("platform:audit")),
          db: Session = Depends(get_db)):
    find_request(db, p.tenant_id, request_id)
    return [
        {"actor": x.actor, "action": x.action, "at": x.at.isoformat()}
        for x in db.scalars(
            select(AuditEvent).where(AuditEvent.tenant_id == p.tenant_id,
                                     AuditEvent.request_id == request_id)
            .order_by(AuditEvent.at)
        )
    ]

@app.get("/v1/ai/catalog-advisory/{template_key}")
def catalog_advisory(
    template_key: str,
    _p: Principal = Depends(require("catalog:read")),
):
    entry = CATALOG.get(template_key)
    if not entry:
        raise HTTPException(404, "Unknown catalog template")
    from app.ai import explain_template
    advice = explain_template(template_key, entry["description"])
    return {"template": template_key, "advisory": advice,
            "authoritative": False, "provisioned": False}

@app.get("/v1/ops/aws/{service_name}/triage")
def cloud_run_triage(
    service_name: str,
    _operator: Principal = Depends(require("platform:ops:read")),
):
    """Privileged operations-only triage. No tenant-owned resource discovery."""
    from app.ops import evidence_for_aws, advise

    evidence = evidence_for_aws(service_name)
    advice = advise(evidence)
    return {
        "evidence": evidence,
        "advice": advice,
        "read_only": True,
        "remediation_performed": False,
    }
