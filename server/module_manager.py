import asyncio, importlib, inspect, logging, os
from fastapi import FastAPI
from typing import Dict, Type

from server.helpers import snake_to_pascal
from server.kernel import BaseModule, T

logger = logging.getLogger(__name__.split('.')[-1])


# ----------------------------------------------------------------------------
# ModuleManager
# ----------------------------------------------------------------------------
# RESPONSIBILITY: loading and unloading modules. That is it. Code that is
# not that does not belong here; if it lands here it is called out below.
#
# Module loading: the gather. Index the whole server folder for *_module.py
# files, import each, instantiate its class, register the instance, and start
# the instances. That is the only responsibility. Phases past startup, the
# sealed state and the exit are the lifecycle manager's, which calls here.
#
#   discover() -> list[type]
#       Walk server/ (every package, any depth) for files ending in
#       _module.py. Each file must define the class named by its stem
#       (snake_to_pascal, the same rule as the providers), a concrete
#       BaseModule; anything else stops the boot. Instantiate and register
#       every class found. Deterministic order: folders and files sorted.
#
#   start_all(module_classes) -> None
#       Concurrent startup() on the given registered modules: the same
#       multi-fire init as before. Ordering emerges from await_ready() waits
#       inside the modules; the manager enforces none.
#
#   stop_all() -> None
#       Concurrent shutdown() on every registered module, then the registry
#       is cleared: the unload, the mirror of start_all.
#
#   get(module_type) / get_by_name(name)
#       The registry, by type and by class name.
#
# -- Design principles -------------------------------------------------------
# The module manager only calls the contract. It does not pass references
# between modules, know which module depends on which, or enforce ordering.
# Modules are self-sufficient: they use get_module() to find each other and
# await_ready() to sequence themselves.
#
# -- Circular dependency guard -----------------------------------------------
# No runtime detection. Two modules that each await the other's
# await_ready() will deadlock silently. This is a code error. The
# dependency graph must be a DAG.
# ----------------------------------------------------------------------------

SUFFIX = "_module.py"


class ModuleManager:
  def __init__(self, app: FastAPI):
    self.app = app
    self._instances: Dict[type, BaseModule] = {}

  @property
  def instances(self) -> Dict[type, BaseModule]:
    return self._instances

  def discover(self) -> list[type]:
    root = os.path.dirname(os.path.abspath(__file__))
    found: list[type] = []
    for folder, dirs, files in os.walk(root):
      dirs.sort()
      for fname in sorted(files):
        if not fname.endswith(SUFFIX):
          continue
        stem = fname[:-3]
        relative = os.path.relpath(os.path.join(folder, stem), root).replace(os.sep, ".")
        path = "server.%s" % relative
        class_name = snake_to_pascal(stem)
        module = importlib.import_module(path)
        if not hasattr(module, class_name):
          raise ImportError("'%s' missing expected class '%s'" % (path, class_name))
        module_class = getattr(module, class_name)
        if not (isinstance(module_class, type) and issubclass(module_class, BaseModule) and not inspect.isabstract(module_class)):
          raise ImportError("'%s' in %s is not a concrete BaseModule" % (class_name, path))
        found.append(module_class)
    for module_class in found:
      self._instances[module_class] = module_class(self.app)
    logger.info("discover - %d modules loaded", len(found))
    return found

  async def start_all(self, module_classes: list[type]):
    async def _start_module(module_class: type, module: BaseModule):
      await module.startup()
      logger.info("'%s' started", module_class.__name__)

    await asyncio.gather(*(
      _start_module(module_class, self._instances[module_class]) for module_class in module_classes
    ))
    logger.info("start_all successful")

  async def stop_all(self):
    async def _stop_module(module_class: type, module: BaseModule):
      await module.shutdown()
      logger.info("'%s' stopped", module_class.__name__)

    await asyncio.gather(*(
      _stop_module(module_class, module) for module_class, module in self._instances.items()
    ))
    self._instances.clear()
    logger.info("stop_all successful")

  def get(self, module_type: Type[T]) -> T:
    instance = self._instances.get(module_type)
    if instance is None:
      logger.error("'%s' not registered", module_type.__name__)
      return None
    return instance

  def get_by_name(self, name: str) -> BaseModule | None:
    # A contract names a module by its class name (a workflow step, later an
    # RPC contract row); the registry answers by name as it does by type.
    for module_class, instance in self._instances.items():
      if module_class.__name__ == name:
        return instance
    logger.error("'%s' not registered", name)
    return None
