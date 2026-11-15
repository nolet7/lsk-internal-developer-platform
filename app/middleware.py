"""PII-minimizing structured request logs, correlation IDs and headers."""
import json
import logging
import time
from uuid import uuid4
from starlette.middleware.base import BaseHTTPMiddleware
log=logging.getLogger("lsk.access")
log.setLevel(logging.INFO)
class EnterpriseRequestMiddleware(BaseHTTPMiddleware):
    async def dispatch(self,request,call_next):
        request_id=str(uuid4())
        started=time.perf_counter()
        status=500
        route="unmatched"
        try:
            response=await call_next(request)
            status=response.status_code
            route=str(getattr(request.scope.get("route"),"path","unmatched"))[:120]
            response.headers["X-Request-ID"]=request_id
            response.headers["X-Content-Type-Options"]="nosniff"
            response.headers["Cache-Control"]="no-store"
            response.headers["Referrer-Policy"]="no-referrer"
            response.headers["Strict-Transport-Security"]="max-age=31536000"
            return response
        finally:
            log.info(json.dumps({"event":"http_request","request_id":request_id,
                "method":request.method,"route":route,"status_code":status,
                "duration_ms":round((time.perf_counter()-started)*1000,2)},separators=(",",":")))
