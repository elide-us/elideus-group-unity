import logging
from abc import abstractmethod

from pydantic import BaseModel

from server.kernel import BaseProvider, BaseWorker
from server.kernel.database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# ServiceHost: one row of service_hosts, as the read operation returns it.
# ----------------------------------------------------------------------------
# A running process: its boot key, its host_status, the host name and pid it
# is displayed by, the kernel version it runs, the core version it sealed
# with (NULL until sealed), its connection count, when it started and when
# it last beat. pub_lease_until is reserved for the primary lease and is not
# written in v1.
# ----------------------------------------------------------------------------

class ServiceHost(BaseModel):
  key_guid: str
  ref_status_enum_guid: str
  pub_host_name: str
  pub_pid: int
  pub_kernel_version: str
  pub_core_version: str | None = None
  pub_connections: int
  pub_started_on: str
  pub_heartbeat_on: str
  pub_lease_until: str | None = None


# ----------------------------------------------------------------------------
# BaseKernelHostProvider
# ----------------------------------------------------------------------------
# Provider contract for the HOST REGISTRY (service_hosts). One registry
# operation per verb, each a single statement the kernel commits, so every
# call is atomic by itself. A write that affects any number of rows other
# than one is an error, raised, never swallowed.
#
#   register(key_guid, status, host_name, pid, kernel_version) -> None
#                                 the process's own row, STARTING
#   seal(key_guid, status, core_package_guid) -> None
#                                 SEALED, stamping the core manifest version it sealed with
#   set_status(key_guid, status) -> None        DRAINING, STOPPED
#   heartbeat(key_guid) -> None
#   read(key_guid) -> ServiceHost | None
#   release_stale(stopped, grace_seconds) -> int
#                                 every row not STOPPED whose heartbeat is older than the
#                                 grace period becomes STOPPED
#   reload(key_guid, reloading, sealed) -> None
#                                 a SEALED row becomes RELOADING; the workflow side's one write
# ----------------------------------------------------------------------------

class BaseKernelHostProvider(BaseProvider):
  def __init__(self, database: DatabaseOperationsModule):
    self._database = database

  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  @abstractmethod
  async def register(self, key_guid: str, status: str, host_name: str, pid: int, kernel_version: str) -> None:
    pass

  @abstractmethod
  async def seal(self, key_guid: str, status: str, core_package_guid: str) -> None:
    pass

  @abstractmethod
  async def set_status(self, key_guid: str, status: str) -> None:
    pass

  @abstractmethod
  async def heartbeat(self, key_guid: str) -> None:
    pass

  @abstractmethod
  async def read(self, key_guid: str) -> ServiceHost | None:
    pass

  @abstractmethod
  async def release_stale(self, stopped: str, grace_seconds: int) -> int:
    pass

  @abstractmethod
  async def reload(self, key_guid: str, reloading: str, sealed: str) -> None:
    pass


# ----------------------------------------------------------------------------
# BaseKernelHostWorker
# ----------------------------------------------------------------------------
# The heartbeat and observer loop, owned by the host executor. It waits for the
# manager to seal; then on its cadence it beats and reads the process's own
# row, and stops when the row says RELOADING (the module drains and exits).
# ----------------------------------------------------------------------------

class BaseKernelHostWorker(BaseWorker):
  @abstractmethod
  async def start(self) -> None:
    pass

  @abstractmethod
  async def stop(self) -> None:
    pass
