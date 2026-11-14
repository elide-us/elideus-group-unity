import json
import logging
import uuid

logging.basicConfig(level=logging.INFO)


from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
# from fastapi.staticfiles import StaticFiles

from server.lifespan import lifespan
from server.core.gateway_execution_providers import IoRequest
from server.core.gateway_operations_module import GatewayOperationsModule

app = FastAPI(lifespan=lifespan)
# app.include_router(web_router.router)

# ----------------------------------------------------------------------------
# POST /rpc
# ----------------------------------------------------------------------------
# Body {"urn": str, "params": object}. The route decides nothing: it passes
# what it received to the gateway on channel 'rpc' and RPC refuses. A body
# that is not a JSON object, a urn that is not a string (sent as ''), or
# params that are not an object (sent as their JSON text) all reach RPC and
# come back MALFORMED_OP through the one path, so every refusal is recorded.
# An Authorization header is passed as the credential (the value after
# 'Bearer ', or the whole value); it is never logged. The answer: 200 with
# the result JSON ('null' when the function returns nothing); otherwise only
# {"error": <reason>} with the status mapped below, 500 for anything else.
# ----------------------------------------------------------------------------

RPC_CHANNEL = "rpc"
RPC_MODEL = "rpc_request"
BEARER = "Bearer "
STATUS = {
  "MALFORMED_OP": 400,
  "NO_IDENTITY": 401,
  "REVOKED": 401,
  "DISABLED_ACCOUNT": 401,
  "NO_GRANT": 403,
  "UNKNOWN_TERM": 404,
}
FAILED = "FAILED"


@app.get("/")
async def get_root():
  logging.info("Web router is misconfigured.")
  return JSONResponse(status_code=200, content={"message": "FastAPI Root Router"})


@app.post("/rpc")
async def post_rpc(http_request: Request) -> JSONResponse:
  correlation_key = str(uuid.uuid4()).upper()
  try:
    try:
      body = await http_request.json()
    except Exception:
      body = None
    urn = body.get("urn") if isinstance(body, dict) else None
    params = body.get("params") if isinstance(body, dict) else None
    authorization = http_request.headers.get("authorization")
    credential = None
    if authorization is not None:
      credential = authorization[len(BEARER):] if authorization.startswith(BEARER) else authorization
    gateway = http_request.app.state.module_manager.get(GatewayOperationsModule)
    if gateway is None:
      raise RuntimeError("the gateway is not loaded")
    response = await gateway.dispatch(IoRequest(
      channel=RPC_CHANNEL,
      operation=urn if isinstance(urn, str) else "",
      model=RPC_MODEL,
      params=json.dumps(params),
      correlation_key=correlation_key,
      credential=credential,
    ))
  except Exception as e:
    # Never a stack trace to the caller, never the request in the log line.
    logging.error("POST /rpc failed (%s): %s", correlation_key, type(e).__name__)
    return JSONResponse(status_code=500, content={"error": FAILED})
  if response.ok:
    try:
      content = json.loads(response.result) if response.result is not None else None
    except Exception as e:
      logging.error("POST /rpc result is not JSON (%s): %s", correlation_key, type(e).__name__)
      return JSONResponse(status_code=500, content={"error": FAILED})
    return JSONResponse(status_code=200, content=content)
  reason = response.error if isinstance(response.error, str) and response.error else FAILED
  return JSONResponse(status_code=STATUS.get(reason, 500), content={"error": reason})


@app.exception_handler(Exception)
async def log_exceptions(request: Request, exc: Exception):
  logging.exception("FastAPI: Unhandled Exception")
  return JSONResponse(status_code=500, content={"message": "Internal Server Error"})
