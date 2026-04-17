import logging

logging.basicConfig(level=logging.DEBUG)

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
# from fastapi.staticfiles import StaticFiles

from server.lifespan import lifespan

app = FastAPI(lifespan=lifespan)
# app.include_router(web_router.router)

@app.get("/")
async def get_root():
  logging.info("Web router is misconfigured.")
  return JSONResponse(status_code=200, content={"message": "FastAPI Root Router"})

@app.exception_handler(Exception)
async def log_exceptions(request: Request, exc: Exception):
  logging.exception("FastAPI: Unhandled Exception")
  return JSONResponse(status_code=500, content={"message": "Internal Server Error"})
