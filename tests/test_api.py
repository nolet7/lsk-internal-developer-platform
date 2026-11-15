import pytest
from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app import main as m

@pytest.fixture
def lab():
    engine = create_engine("sqlite+pysqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    m.Base.metadata.create_all(engine)
    factory = sessionmaker(engine, expire_on_commit=False)
    identities = {}
    def db():
        with factory() as session:
            yield session
    def principal(req: Request):
        token = req.headers.get("Authorization", "").removeprefix("Bearer ")
        if token not in identities:
            raise HTTPException(401, "Unauthorized")
        return identities[token]
    m.app.dependency_overrides[m.get_db] = db
    m.app.dependency_overrides[m.get_principal] = principal
    with TestClient(m.app) as client:
        def auth(subject, tenant, scopes):
            token = str(len(identities))
            identities[token] = m.Principal(subject, tenant, frozenset(scopes))
            return {"Authorization": "Bearer " + token}
        yield client, auth
    m.app.dependency_overrides.clear()
    engine.dispose()

def create(client, headers, template="cloud-run-api", env="dev"):
    return client.post("/v1/requests", headers={**headers, "Idempotency-Key": "unique-key-123"},
        json={"template": template, "service_name": "customer-api",
              "environment": env, "justification": "Corporate IT self service request"})

def test_health_and_catalog(lab):
    client, auth = lab
    p = auth("dev", "a", ["catalog:read"])
    assert client.get("/healthz").status_code == 200
    assert len(client.get("/v1/catalog", headers=p).json()) == 3
    assert client.get("/v1/catalog").status_code == 401

def test_approval_and_plan_handoff(lab):
    client, auth = lab
    developer = auth("dev", "a", ["platform:request", "platform:plan", "platform:approve"])
    reviewer = auth("reviewer", "a", ["platform:approve", "platform:audit"])
    request = create(client, developer)
    assert request.status_code == 201, request.text
    rid = request.json()["id"]
    assert client.get(f"/v1/requests/{rid}/gitops-plan", headers=developer).status_code == 409
    assert client.post(f"/v1/requests/{rid}/approve", headers=developer).status_code == 403
    approved = client.post(f"/v1/requests/{rid}/approve", headers=reviewer)
    assert approved.status_code == 200 and approved.json()["provisioned"] is False
    assert client.post(f"/v1/requests/{rid}/approve", headers=reviewer).status_code == 409
    plan = client.get(f"/v1/requests/{rid}/gitops-plan", headers=developer)
    assert plan.status_code == 200
    assert plan.json()["gitops_spec"]["spec"]["template"] == "cloud-run-api"
    assert plan.json()["provisioned"] is False
    assert len(client.get(f"/v1/requests/{rid}/audit", headers=reviewer).json()) == 2

def test_tenant_isolation_and_replay(lab):
    client, auth = lab
    a = auth("dev", "a", ["platform:request", "platform:read", "platform:plan"])
    b = auth("other", "b", ["platform:request", "platform:read", "platform:plan"])
    result = create(client, a)
    assert result.status_code == 201
    assert create(client, a).json()["replayed"] is True
    rid = result.json()["id"]
    assert client.get("/v1/requests", headers=b).json() == []
    assert client.get(f"/v1/requests/{rid}/gitops-plan", headers=b).status_code == 404
    assert create(client, b).status_code == 201  # per-tenant key uniqueness

def test_production_requires_extra_approval(lab):
    client, auth = lab
    maker = auth("maker", "a", ["platform:request"])
    reviewer = auth("reviewer", "a", ["platform:approve"])
    lead = auth("lead", "a", ["platform:approve", "platform:approve:prod"])
    request = create(client, maker, env="prod")
    assert request.status_code == 201
    rid = request.json()["id"]
    path = f"/v1/requests/{rid}/approve"
    assert client.post(path, headers=reviewer).status_code == 403
    assert client.post(path, headers=lead).status_code == 200

def test_invalid_template_and_conflicting_key(lab):
    client, auth = lab
    maker = auth("maker", "a", ["platform:request"])
    assert create(client, maker, template="not-supported").status_code == 422
    assert create(client, maker).status_code == 201
    assert create(client, maker, env="stage").status_code == 409

def test_reject_then_no_plan(lab):
    client, auth = lab
    maker = auth("maker", "a", ["platform:request", "platform:plan"])
    reviewer = auth("reviewer", "a", ["platform:approve"])
    rid = create(client, maker).json()["id"]
    assert client.post(f"/v1/requests/{rid}/reject", headers=reviewer).status_code == 200
    assert client.get(f"/v1/requests/{rid}/gitops-plan", headers=maker).status_code == 409

def test_missing_auth():
    with pytest.raises(HTTPException) as error:
        m.get_principal(None)
    assert error.value.status_code == 401
