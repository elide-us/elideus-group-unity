import logging
import uuid

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.helpers import discover_classes, deterministic_guid
from .security_entitlements_execution_providers import BaseSecurityEntitlementsProvider

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityEntitlementsExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Security Entitlements subsystem: owns the entitlements
# catalogue (service_security_entitlements). Holds the catalogue in memory, keys new
# rows by formula (uuid5 over NS_HASH, 'service_security_entitlements:<name>'), and
# hands every read and write to its provider, which dispatches the registry
# operations. The catalogue is reloaded after every write so the cache and
# the table never disagree.
#
# This is the catalogue, not the assignment: user-to-entitlement mapping is another
# subsystem.
#
# -- Contract ----------------------------------------------------------------
#   entitlements() -> dict[str, dict]                [sync, cache-only]
#   entitlement_guid(name: str) -> str | None        [sync, cache-only]
#   create(name, display, notes=None, package_guid=None) -> str   (the key)
#   update(name, display=None, notes=None) -> None
#   delete(name) -> None
#     Unknown name raises KeyError; duplicate name on create raises ValueError.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH)
#   security_entitlements_execution_providers/*_provider
# ----------------------------------------------------------------------------

TABLE = "service_security_entitlements"
PROVIDER = "database_security_entitlements_provider"


class SecurityEntitlementsExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._provider: BaseSecurityEntitlementsProvider | None = None
    self._namespace: uuid.UUID | None = None
    self._entitlements: dict[str, dict] = {}

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    providers = discover_classes(f"{__package__}.security_entitlements_execution_providers", "_provider")
    self._provider = providers[PROVIDER](self._database)
    await self._provider.connect()
    await self._reload()
    self.raise_ready()

  async def _reload(self):
    self._entitlements = {row["pub_name"]: row for row in await self._provider.read_all()}
    if self._entitlements:
      logger.info("Loaded %d security entitlements", len(self._entitlements))
    else:
      logger.warning("No security entitlements loaded (empty table or operation not found)")

  def entitlements(self) -> dict[str, dict]:
    return self._entitlements

  def entitlement_guid(self, name: str) -> str | None:
    row = self._entitlements.get(name)
    return row["key_guid"] if row else None

  async def create(self, name: str, display: str, notes: str | None = None, package_guid: str | None = None) -> str:
    if name in self._entitlements:
      raise ValueError("security entitlement '%s' already exists" % name)
    key_guid = deterministic_guid(self._namespace, TABLE, name)
    await self._provider.create({
      "key_guid": key_guid, "ref_package_guid": package_guid,
      "pub_name": name, "pub_display": display, "pub_notes": notes,
    })
    await self._reload()
    logger.info("Created security entitlement '%s' (%s)", name, key_guid)
    return key_guid

  async def update(self, name: str, display: str | None = None, notes: str | None = None) -> None:
    row = self._entitlements.get(name)
    if row is None:
      raise KeyError("security entitlement '%s' not found" % name)
    await self._provider.update({
      "pub_display": row["pub_display"] if display is None else display,
      "pub_notes": row.get("pub_notes") if notes is None else notes,
      "key_guid": row["key_guid"],
    })
    await self._reload()
    logger.info("Updated security entitlement '%s'", name)

  async def delete(self, name: str) -> None:
    row = self._entitlements.get(name)
    if row is None:
      raise KeyError("security entitlement '%s' not found" % name)
    await self._provider.delete(row["key_guid"])
    await self._reload()
    logger.info("Deleted security entitlement '%s'", name)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    self._entitlements.clear()

  async def shutdown(self):
    if self._provider:
      await self._provider.disconnect()
      self._provider = None
    self._entitlements.clear()
    self._database = None
