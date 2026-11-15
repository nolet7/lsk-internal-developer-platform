"""Read-only, bounded Google Cloud Run error evidence for LSK platform operators.

No raw log payloads, message strings, secrets or user data are returned to the AI.
This is an explicit allowlisted operations tool, never an auto-remediation agent.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
import os
import re

from fastapi import HTTPException

_SERVICE_RE = re.compile(r"^[a-z][a-z0-9-]{1,48}$")


def evidence_for_cloud_run(service: str) -> dict:
    allowed = {s.strip() for s in os.getenv("LSK_OPS_ALLOWED_SERVICES", "").split(",") if s.strip()}
    project = os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project or not allowed:
        raise HTTPException(503, "Operations evidence source is not configured")
    if not _SERVICE_RE.fullmatch(service) or service not in allowed:
        raise HTTPException(403, "Cloud Run service not allowed")
    # One hour is a hard bound for exploratory lab diagnostics.
    since = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    query = (
        'resource.type="cloud_run_revision" '
        f'AND resource.labels.service_name="{service}" '
        'AND severity>=ERROR '
        f'AND timestamp>="{since}"'
    )
    try:
        from google.cloud import logging_v2
        client = logging_v2.Client(project=project)
        events = list(client.list_entries(filter_=query, page_size=25, max_results=25))
    except Exception as exc:
        raise HTTPException(502, "Unable to retrieve Cloud Logging evidence") from exc
    return {
        "service": service,
        "time_window_minutes": 60,
        "max_entries": 25,
        "error_entries_sampled": len(events),
        "sample_truncated": len(events) == 25,
        "source": "Google Cloud Logging metadata",
        "raw_log_payloads_shared": False,
    }


def advise(evidence: dict) -> str:
    project = os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("GOOGLE_CLOUD_LOCATION")
    model = os.getenv("GOOGLE_GENAI_MODEL")
    if not all([project, location, model]):
        raise HTTPException(503, "AI model is not configured")
    from google import genai
    prompt = (
        "You are an infrastructure incident triage assistant. Only explain the "
        "bounded metadata provided. Do not assert a root cause. Never request "
        "secrets, recommend disabling IAM, or claim to have executed changes. "
        "Return probable investigation steps and explicit uncertainty. "
        f"\nEvidence: service={evidence['service']}; "
        f"errors_sampled={evidence['error_entries_sampled']}; "
        f"window_minutes={evidence['time_window_minutes']}; "
        f"truncated={evidence['sample_truncated']}."
    )
    try:
        with genai.Client(vertexai=True, project=project, location=location) as client:
            result = client.models.generate_content(model=model, contents=prompt)
        if not result.text:
            raise HTTPException(502, "No AI advice produced")
        return result.text[:1600]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(502, "AI troubleshooting advice unavailable") from exc
