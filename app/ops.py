"""AWS CloudWatch error-count diagnostic tool; read-only and allowlisted."""
import os
import re
import time
from fastapi import HTTPException
from app.ai import generate_advice

def evidence_for_aws(service: str) -> dict:
    allowed={x.strip() for x in os.getenv("LSK_OPS_ALLOWED_SERVICES","").split(",") if x.strip()}
    region=os.getenv("AWS_REGION")
    group=os.getenv("LSK_AWS_LOG_GROUP")
    if not region or not group or not allowed:
        raise HTTPException(503,"AWS operations telemetry is not configured")
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,48}",service) or service not in allowed:
        raise HTTPException(403,"CloudWatch service not allowlisted")
    try:
        import boto3
        client=boto3.client("logs",region_name=region)
        response=client.filter_log_events(logGroupName=group,
            startTime=int((time.time()-3600)*1000),filterPattern="?ERROR ?Exception",limit=25)
        count=len(response.get("events",[]))
    except Exception as exc:
        raise HTTPException(502,"CloudWatch evidence unavailable") from exc
    return {"service":service,"region":region,"window_minutes":60,
            "error_entries_sampled":count,"sample_truncated":count==25,
            "source":"CloudWatch metadata","raw_log_payloads_shared":False}

def advise(evidence: dict) -> str:
    return generate_advice(
        "LSK AWS operations triage: suggest bounded read-only investigation steps. "
        "No root-cause certainty, no destructive steps, do not claim actions executed. "
        f"Region {evidence['region']}; service {evidence['service']}; "
        f"errors sampled {evidence['error_entries_sampled']} over 60 minutes. "
        "No raw logs are available to the model."
    )
