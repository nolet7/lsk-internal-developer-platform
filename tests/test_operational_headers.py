from fastapi.testclient import TestClient
from app.main import app

def test_http_headers():
    response=TestClient(app).get("/healthz",headers={"X-Request-ID":"untrusted"})
    assert response.status_code==200
    assert response.headers["X-Content-Type-Options"]=="nosniff"
    assert response.headers["Cache-Control"]=="no-store"
    assert len(response.headers["X-Request-ID"])==36
    assert response.headers["X-Request-ID"]!="untrusted"
