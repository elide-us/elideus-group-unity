import logging

from .. import BaseWorker

logger = logging.getLogger(__name__.split('.')[-1])


# -----------------------------------------------------------------------------
# DatabaseManagementWorker (probably should be in init with the other base classes)
# -----------------------------------------------------------------------------
# Stub. The DDL worker's work-intake contract will be supplied by the core-tier
# automation substrate (the tenatively named WorkQueueSubscriber contract), which
# is not yet specified or implemented.
# 
# See docs/future/task_automation_design.md
#
# Today this class exists only to satisfy the Maintenance/Management composition
# pattern, start() and stop() are noops.

class DatabsaeManagementWorker(BaseWorker):
  async def start(self) -> None:
    pass

  async def stop(self) -> None:
    pass

  