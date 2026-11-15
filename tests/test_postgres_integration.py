from uuid import uuid4
import os
import pytest
from sqlalchemy import create_engine,select
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from app.main import PlatformRequest

@pytest.mark.skipif(not os.getenv("DATABASE_URL","").startswith("postgresql"),reason="PostgreSQL-only test")
def test_pg_idp_tenant_and_idempotency():
    engine=create_engine(os.environ["DATABASE_URL"])
    tenant="test-"+str(uuid4())
    data=dict(tenant_id=tenant,requester="dev",idempotency_key="key-123456789",
        payload_hash="abc",template="ecs-fargate-api",template_version="1.0.0",
        service_name="test-api",environment="dev",justification="Synthetic development test",
        state="pending")
    with Session(engine) as session:
        session.add(PlatformRequest(**data));session.commit()
        assert session.scalar(select(PlatformRequest).where(PlatformRequest.tenant_id=="other")) is None
        session.add(PlatformRequest(**data))
        with pytest.raises(IntegrityError):
            session.commit()
        session.rollback()
