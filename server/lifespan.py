import logging

from fastapi import FastAPI
from contextlib import asynccontextmanager

from server.kernel import ModuleManager

logger = logging.getLogger(__name__.split('.')[-1])

@asynccontextmanager
async def lifespan(app: FastAPI):
  modules = ModuleManager(app)
  await modules.startup()

  try:
    # mcp_module = app.state.mcp_io_service
    # if mcp_module and mcp_module.session_manager:
    #   async with mcp_module.session_manager.run():
    #     yield
    # else:
    #   yield
    yield
  except Exception:
    logging.exception("lifespan failed to yield")
