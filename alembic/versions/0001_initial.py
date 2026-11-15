"""LSK IDP requests and audit baseline."""
from alembic import op
import sqlalchemy as sa
revision="0001_initial"
down_revision=None
branch_labels=None
depends_on=None

def upgrade():
    op.create_table("platform_requests",
      sa.Column("id",sa.String(36),primary_key=True),
      sa.Column("tenant_id",sa.String(100),nullable=False),
      sa.Column("requester",sa.String(200),nullable=False),
      sa.Column("idempotency_key",sa.String(128),nullable=False),
      sa.Column("payload_hash",sa.String(64),nullable=False),
      sa.Column("template",sa.String(80),nullable=False),
      sa.Column("template_version",sa.String(20),nullable=False),
      sa.Column("service_name",sa.String(63),nullable=False),
      sa.Column("environment",sa.String(20),nullable=False),
      sa.Column("justification",sa.String(1000),nullable=False),
      sa.Column("state",sa.String(24),nullable=False),
      sa.Column("approver",sa.String(200),nullable=True),
      sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),
      sa.UniqueConstraint("tenant_id","idempotency_key"))
    op.create_index("ix_platform_requests_tenant_id","platform_requests",["tenant_id"])
    op.create_table("audit_events",
      sa.Column("id",sa.String(36),primary_key=True),
      sa.Column("tenant_id",sa.String(100),nullable=False),
      sa.Column("request_id",sa.String(36),nullable=False),
      sa.Column("actor",sa.String(200),nullable=False),
      sa.Column("action",sa.String(30),nullable=False),
      sa.Column("at",sa.DateTime(timezone=True),nullable=False))
    op.create_index("ix_audit_events_tenant_id","audit_events",["tenant_id"])
    op.create_index("ix_audit_events_request_id","audit_events",["request_id"])

def downgrade():
    op.drop_index("ix_audit_events_request_id",table_name="audit_events")
    op.drop_index("ix_audit_events_tenant_id",table_name="audit_events")
    op.drop_table("audit_events")
    op.drop_index("ix_platform_requests_tenant_id",table_name="platform_requests")
    op.drop_table("platform_requests")
