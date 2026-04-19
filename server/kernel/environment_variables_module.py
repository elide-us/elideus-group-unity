import os, logging

from dotenv import load_dotenv
from fastapi import FastAPI

from . import BaseModule

load_dotenv()
logger = logging.getLogger(__name__.split('.')[-1])

class EnvironmentVariablesModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._env: dict[str, str] = {}

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass
  
  async def startup(self):
    self._load_all()
    self.raise_seal()

  async def shutdown(self):
    self._env.clear()

  def _load_all(self):
    required = [
      "SQL_PROVIDER",
      "AZURE_SQL_CONNECTION_STRING",
      "POSTGRESQL_CONNECTION_STRING",
      "MYSQL_CONNECTION_STRING",
      "NS_HASH",
    ]

    for var in required:
      value = os.getenv(var)
      if value is None:
        logger.warning("Variable: '%s' is not present", var)
        continue
      if not value:
        logger.warning("Variable: %s is not set", var)
        continue
      self._env[var] = value

    logger.info("Loaded %d/%d variables", len(self._env), len(required))

  def get(self, var_name: str) -> str | None:
    value = self._env.get(var_name)
    if value is None:
      logger.error("Variable '%s' not available", var_name)
    return value
