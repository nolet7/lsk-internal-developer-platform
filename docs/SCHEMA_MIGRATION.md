# LSK database schema lifecycle — Alembic

## What's implemented

- `alembic/versions/0001_initial.py` is the explicit baseline migration for this project's current SQLAlchemy models.
- `scripts/migrate.py` runs `alembic upgrade head`. API startup never creates or modifies tables.
- A dedicated PostgreSQL 16 GitHub Actions service runs the baseline migration followed by real database integration checks. SQLite unit tests remain separate.
- Each image bundles the Alembic configuration and version files, so the documented Cloud Run **one-off migration Job** can run the same entrypoint.

## Fresh database deployment

Configure a private, least-privilege `DATABASE_URL` in Secret Manager and a dedicated migration identity. For development, provide `DATABASE_URL` in your shell.

```bash
python -m pip install -r requirements-dev.txt
python scripts/migrate.py
python -m alembic current
python -m alembic history
```

For cloud deployment, create the Cloud Run Job using `scripts/deploy-migration-job.sh`. After a separate review, execute it once with `gcloud run jobs execute ... --wait`. Do not run schema migrations inside the autoscaling web process.

## Brownfield database warning

If your database was previously initialized using `Base.metadata.create_all()`, tables may exist **without an Alembic revision**. **Do not run the initial migration on it blindly**: it can fail trying to create existing tables.

1. Back up the database and perform a tested restore in a disposable isolated environment.
2. Compare actual PostgreSQL schema, indexes, constraints and nullability with the baseline migration.
3. Resolve any mismatches through reviewed, versioned corrective SQL/migrations.
4. Only if a qualified reviewer verifies schema equivalence, consider `alembic stamp 0001_initial` on the existing database, followed by `alembic current`.
5. Create future forward-compatible revisions; test rolling deployment with old/new application versions.

Never apply destructive downgrades to production automatically. Create a tested forward-fix and rollback plan instead.

## Multinational release gates

Execute migrations separately in each approved regional GCP project/database, under an explicit local change window. Record schema version, DB backup/PITR timestamp, migration reviewer, change ticket, audit evidence and rollback/restore test. Never restore a regional production backup into a different jurisdiction without documented authorization.

CI passing is proof of basic migration tests on synthetic PostgreSQL, **not** certification of real-data retention, HA recovery, regional legal compliance, or zero-downtime migration safety.
