import asyncio, os, logging, socket, subprocess

from dotenv import load_dotenv
from fastapi import FastAPI

from . import BaseModule

load_dotenv()
logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# EnvironmentVariablesModule
# ----------------------------------------------------------------------------
# Where the process reads its machine: the environment variables, the
# hostname, and the versions of the system libraries the image installs.
# Everything is read ONCE at startup and served from memory.
#
# Machine getters use the standard library only. ffmpeg is read from
# `ffmpeg -version` (the first line); the three ODBC libraries from the
# Debian package database (`dpkg-query`). A library or tool that is absent
# (a macOS machine has no dpkg-query) reads None. Library versions are for a
# logged-in administrator only; this module serves them and gates nothing.
#
# -- Contract ----------------------------------------------------------------
#   get(var_name: str) -> str | None          a loaded variable, None if absent
#   get_hostname() -> str                     socket.gethostname()
#   get_ffmpeg_version() -> str | None
#   get_libodbc2_version() -> str | None
#   get_msodbcsql18_version() -> str | None
#   get_unixodbc_version() -> str | None
#
# UNITY_ENTRYPOINT is loaded with the others: each launch script exports its
# own file name. The host refuses to start without it.
#
# -- Dependencies ------------------------------------------------------------
#   None. Every other module waits on this one, directly or not.
# ----------------------------------------------------------------------------

# Seconds a version probe may take before it reads None.
PROBE_TIMEOUT = 5


class EnvironmentVariablesModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._env: dict[str, str] = {}
    self._hostname: str | None = None
    self._ffmpeg_version: str | None = None
    self._libodbc2_version: str | None = None
    self._msodbcsql18_version: str | None = None
    self._unixodbc_version: str | None = None

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def startup(self):
    self._load_all()
    self._hostname = socket.gethostname()
    self._ffmpeg_version = await asyncio.to_thread(self._read_ffmpeg_version)
    self._libodbc2_version = await asyncio.to_thread(self._read_package_version, "libodbc2")
    self._msodbcsql18_version = await asyncio.to_thread(self._read_package_version, "msodbcsql18")
    self._unixodbc_version = await asyncio.to_thread(self._read_package_version, "unixodbc")
    self.raise_ready()

  async def shutdown(self):
    self._env.clear()

  def _load_all(self):
    required = [
      "SQL_PROVIDER",
      "AZURE_SQL_CONNECTION_STRING",
      "POSTGRESQL_CONNECTION_STRING",
      "MYSQL_CONNECTION_STRING",
      "NS_HASH",
      "SETUP_ENABLED",
      "DISCORD_SECRET",
      "UNITY_ENTRYPOINT",
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

  def _probe(self, command: list[str]) -> str | None:
    # One read of the machine: the first line the command prints, None when
    # the tool is absent, fails, times out or prints nothing.
    try:
      result = subprocess.run(command, capture_output=True, text=True, timeout=PROBE_TIMEOUT, check=False)
    except (OSError, subprocess.SubprocessError):
      return None
    if result.returncode != 0:
      return None
    lines = result.stdout.strip().splitlines()
    return lines[0].strip() if lines and lines[0].strip() else None

  def _read_ffmpeg_version(self) -> str | None:
    return self._probe(["ffmpeg", "-version"])

  def _read_package_version(self, package: str) -> str | None:
    return self._probe(["dpkg-query", "-W", "-f", "${Version}", package])

  def get(self, var_name: str) -> str | None:
    value = self._env.get(var_name)
    if value is None:
      logger.error("Variable '%s' not available", var_name)
    return value

  def get_hostname(self) -> str:
    if self._hostname is None:
      raise RuntimeError("hostname is not read: EnvironmentVariablesModule has not started")
    return self._hostname

  def get_ffmpeg_version(self) -> str | None:
    return self._ffmpeg_version

  def get_libodbc2_version(self) -> str | None:
    return self._libodbc2_version

  def get_msodbcsql18_version(self) -> str | None:
    return self._msodbcsql18_version

  def get_unixodbc_version(self) -> str | None:
    return self._unixodbc_version
