import json
import pytest
from fastapi import HTTPException
from app.regional_policy import enforce_residency

@pytest.fixture
def residency(monkeypatch):
    monkeypatch.setenv("LSK_ENFORCE_RESIDENCY","true")
    monkeypatch.setenv("LSK_DEPLOYMENT_REGION","us-central1")
    monkeypatch.setenv("LSK_TENANT_REGION_POLICY",json.dumps({"us-tenant":["us-central1"],"eu-tenant":["europe-west1"]}))

def test_allowed(residency):
    enforce_residency({"data_region":"us-central1"},"us-tenant")

@pytest.mark.parametrize("claims,tenant",[
    ({"data_region":"europe-west1"},"us-tenant"),
    ({"data_region":"us-central1"},"eu-tenant"),
    ({},"us-tenant"),
    ({"data_region":"us-central1"},"unknown")
])
def test_denied(residency,claims,tenant):
    with pytest.raises(HTTPException) as err:
        enforce_residency(claims,tenant)
    assert err.value.status_code==403

def test_fail_closed(residency,monkeypatch):
    monkeypatch.setenv("LSK_TENANT_REGION_POLICY","bad json")
    with pytest.raises(HTTPException) as err:
        enforce_residency({"data_region":"us-central1"},"us-tenant")
    assert err.value.status_code==503
