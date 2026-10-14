import logging, os

from fastapi import FastAPI
from contextlib import asynccontextmanager

from server.kernel import KernelModuleManager

logger = logging.getLogger(__name__.split('.')[-1])

@asynccontextmanager
async def lifespan(app: FastAPI):
  modules = KernelModuleManager(app)
  try:
    try:
      await modules.startup()
    except (RuntimeError, SystemExit) as stop:
      # RuntimeError: the kernel refused to start (e.g. database version
      # mismatch). SystemExit: it finished a startup task and asks to stop.
      # One line, no traceback: Starlette would otherwise print the stack.
      if isinstance(stop, RuntimeError):
        logger.error("Startup refused: %s", stop)
      await modules.shutdown()
      os._exit(stop.code if isinstance(stop, SystemExit) else 1)

    # mcp_module = app.state.mcp_io_service
    # if mcp_module and mcp_module.session_manager:
    #   async with mcp_module.session_manager.run():
    #     yield
    # else:
    #   yield
    yield
  finally:
    await modules.shutdown()
  