import os
import sys
from alembic import context
from sqlalchemy import create_engine,pool
sys.path.insert(0,os.getcwd())
from app.main import Base
target_metadata=Base.metadata
if context.is_offline_mode():
    context.configure(url=os.environ["DATABASE_URL"],target_metadata=target_metadata,literal_binds=True,compare_type=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    engine=create_engine(os.environ["DATABASE_URL"],poolclass=pool.NullPool)
    with engine.connect() as conn:
        context.configure(connection=conn,target_metadata=target_metadata,compare_type=True)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()
