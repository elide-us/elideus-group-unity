import logging

from fastapi import FastAPI

from . import BaseModule, DATABASE_VERSION
from .database_execution_module import DatabaseExecutionModule
from .environment_variables_module import EnvironmentVariablesModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# KernelConfigurationModule
# ----------------------------------------------------------------------------
# Key/value configuration lookup backed by `system_configuration`.
#
# Bootstrap-phase registry module. Loads ALL config rows at startup into
# an in-memory cache keyed by pub_key. All access is synchronous against
# the cache — config values are critical path and must be available
# without async overhead.
#
# No lazy-load path. If a key is missing from the cache it was not seeded.
# This is deliberate: config must be fully loaded at startup so callers
# can depend on synchronous access without async overhead. Module restart
# recaches the whole table.
#
# -- Contract ----------------------------------------------------------------
#   get(key: str) -> str | None                          [sync, cache-only]
#     Returns the pub_value for the given pub_key, or None if not found.
#     A None return means the key was never seeded — this is a code error,
#     not a runtime condition.
#
#   get_all() -> dict[str, str]                          [sync, cache-only]
#     Returns a copy of the full cache as {pub_key: pub_value}.
#
#   flush() -> None
#     Clears the in-memory cache.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseExecutionModule — all SQL goes through its contract.
#
# ----------------------------------------------------------------------------

class KernelConfigurationModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._cache: dict[str, str | None] = {}

  async def startup(self):
    db = self.get_module(DatabaseExecutionModule)
    await db.await_ready()

    bootstrap_sql = """
      SELECT
        [ssc].[pub_key],
        [ssc].[pub_value]
      FROM [dbo].[service_system_configuration] AS [ssc]
      FOR JSON PATH;
    """
    raw = await db.query(bootstrap_sql)
    rows = [] if raw is None else raw if isinstance(raw, list) else [raw]
    for entry in rows:
      self._cache[entry["pub_key"]] = entry.get("pub_value")

    logger.info("Loaded %d config entries", len(self._cache))
    self._check_database_version()
    self.raise_ready()

  def _check_database_version(self):
    # The kernel refuses to run against a database at another schema version.
    # Setup mode is where migration happens.
    setup_enabled = self.get_module(EnvironmentVariablesModule).get("SETUP_ENABLED") == "1"
    database_version = self._cache.get("database_version")
    if database_version == DATABASE_VERSION:
      logger.info("Database version %s matches the kernel", database_version)
      return
    if database_version is None:
      message = "database_version is not set; this database has not been initialised (kernel %s)" % DATABASE_VERSION
    elif tuple(int(p) for p in database_version.split('.')) < tuple(int(p) for p in DATABASE_VERSION.split('.')):
      if setup_enabled:
        logger.info("HERE IS WHERE WE WOULD MIGRATE THE DATABASE TO THE NEW SCHEMA (%s -> %s)", database_version, DATABASE_VERSION)
        # This becomes a reboot action once the migration has run. Until the
        # upgrade script exists, stop here as a success so we never loop.
        raise SystemExit(0)
      message = "database version %s is older than the kernel %s; set SETUP_ENABLED=1 to migrate the database" % (database_version, DATABASE_VERSION)
    else:
      message = "database version %s is newer than the kernel %s; apply this version of container: %s" % (database_version, DATABASE_VERSION, database_version)
    logger.error(message)
    raise RuntimeError(message)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._cache.clear()

  def get(self, key: str) -> str | None:
    if key in self._cache:
      return self._cache[key]
    logger.warning("Key '%s' not in cache", key)
    return None

  def get_all(self) -> dict[str, str | None]:
    return dict(self._cache)

  def flush(self):
    self._cache.clear()
    logger.info("Cache flushed")