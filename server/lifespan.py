import logging

from fastapi import FastAPI
from contextlib import asynccontextmanager

from server.modules import ModuleManager

@asynccontextmanager
async def lifespan(app: FastAPI):
  module_manager = ModuleManager(app)
  await module_manager.startup_all()
  app.state.module_manager = module_manager
  try:
    yield # This is the point that Azure Web App stops executing code, everything after here is only useful in local development environment
  except Exception:
    logging.exception('lifespan failed to yield')
  finally:
    await module_manager.shutdown_all()
