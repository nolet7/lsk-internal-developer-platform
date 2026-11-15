from app.main import Base, engine
# Lab schema bootstrap ONLY. Replace with versioned Alembic migrations for production.
Base.metadata.create_all(bind=engine)
