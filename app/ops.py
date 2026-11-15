"""Azure Monitor read-only aggregate error evidence with allowlisted services."""
import os
import re
from datetime import timedelta
from fastapi import HTTPException
from app.ai import generate_advice

def evidence_for_azure(service: str) -> dict:
    allowed={s.strip() for s in os.getenv("LSK_OPS_ALLOWED_SERVICES","").split(",") if s.strip()}
    workspace=os.getenv("LSK_AZURE_WORKSPACE_ID")
    location=os.getenv("LSK_DEPLOYMENT_REGION")
    if not workspace or not allowed or not location:
        raise HTTPException(503,"Azure Monitor diagnostics not configured")
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,48}",service) or service not in allowed:
        raise HTTPException(403,"Container App not allowlisted")
    try:
        from azure.identity import DefaultAzureCredential
        from azure.monitor.query import LogsQueryClient
        query=(
            'ContainerAppConsoleLogs_CL '
            f'| where ContainerAppName_s == "{service}" '
            '| where Log_s has_any ("ERROR", "Exception") '
            '| summarize count()'
        )
        result=LogsQueryClient(DefaultAzureCredential()).query_workspace(
            workspace_id=workspace,query=query,timespan=timedelta(hours=1))
        count=int(result.tables[0].rows[0][0]) if result.tables and result.tables[0].rows else 0
    except Exception as exc:
        raise HTTPException(502,"Azure Monitor evidence unavailable") from exc
    return {"service":service,"region":location,"window_minutes":60,
            "error_entries_sampled":count,"sample_truncated":False,
            "source":"Azure Monitor aggregate","raw_log_payloads_shared":False}

def advise(evidence: dict) -> str:
    return generate_advice(
        "LSK Azure operations triage: suggest non-destructive diagnostic steps. "
        "No access changes, no asserted root cause or executed actions. "
        f"Region {evidence['region']}; service {evidence['service']}; "
        f"aggregated error count {evidence['error_entries_sampled']} in one hour. "
        "Model does not receive raw log content."
    )
