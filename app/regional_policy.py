"""Regional data-residency authorization for the LSK enterprise deployment."""
import json
import os
from fastapi import HTTPException

def enforce_residency(claims: dict, tenant_id: str) -> None:
    if os.getenv("LSK_ENFORCE_RESIDENCY", "false").lower() != "true":
        return
    region=os.getenv("LSK_DEPLOYMENT_REGION","")
    raw=os.getenv("LSK_TENANT_REGION_POLICY","")
    if not region or not raw:
        raise HTTPException(503,"Regional residency policy is not configured")
    try:
        policy=json.loads(raw)
    except (ValueError,TypeError) as exc:
        raise HTTPException(503,"Regional residency policy is invalid") from exc
    if not isinstance(policy,dict):
        raise HTTPException(503,"Regional residency policy must map tenants to regions")
    approved=policy.get(tenant_id)
    if not isinstance(approved,list) or not approved or not all(isinstance(x,str) for x in approved):
        raise HTTPException(403,"Tenant is not assigned to this region")
    claimed=claims.get("data_region")
    if not isinstance(claimed,str) or not claimed or claimed!=region or region not in approved:
        raise HTTPException(403,"Tenant data region mismatch")
