import os, logging

from dotenv import load_dotenv
from fastapi import FastAPI

from . import BaseModule

load_dotenv()


class EnvironmentVariablesModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._env: dict[str, str] = {}

  async def startup(self):
    self._load_all()
    self.mark_ready()

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
        logging.warning("Environment variable: '%s' is not present", var)
        continue
      if not value:
        logging.warning("Environment Variable: %s is not set", var)
        continue
      self._env[var] = value

    logging.info("[Module] EnvironmentVariablesModule loaded %d/%d variables", len(self._env), len(required))

  def get(self, var_name: str) -> str | None:
    value = self._env.get(var_name)
    if value is None:
      logging.error("Environment variable '%s' not available", var_name)
    return value
