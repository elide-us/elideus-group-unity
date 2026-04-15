from abc import ABC, abstractmethod
from fastapi import FastAPI
from typing import Dict, TypeVar, Type
import asyncio, logging, os, importlib

from server.helpers import snake_to_pascal

MODULES_FOLDER = os.path.dirname(__file__)

T = TypeVar("T", bound="BaseModule")

class BaseModule(ABC):
  def __init__(self, app: FastAPI):
    self.app = app
    self._ready_event = asyncio.Event()

  @abstractmethod
  async def startup(self):
    pass

  @abstractmethod
  async def shutdown(self):
    pass

  def mark_ready(self):
    self._ready_event.set()

  async def on_ready(self):
    await self._ready_event.wait()

  @property
  def module_manager(self) -> "ModuleManager":
    return self.app.state.module_manager

  def get_module(self, module_type: Type[T]) -> T:
    return self.module_manager.get(module_type)


class ModuleManager:
  def __init__(self, app: FastAPI):
    self.app = app
    self._instances: Dict[type, BaseModule] = {}

    app.state.module_manager = self
    self._discover_and_register()

  def _discover_and_register(self):
    for fname in os.listdir(MODULES_FOLDER):
      if not fname.endswith("_module.py") or fname == "__init__.py":
        continue

      file_stem = fname[:-3] # Strip file extension ".py"
      class_name = snake_to_pascal(file_stem) # Convert to PascalCase
      module_path = f"{__name__}.{file_stem}" # Module import reference

      module = importlib.import_module(module_path)

      if not hasattr(module, class_name):
        logging.error("Module '%s' missing expected class '%s'", file_stem, class_name)
        continue

      module_class = getattr(module, class_name)
      instance = module_class(self.app)

      self._instances[module_class] = instance

  def get(self, module_type: Type[T]) -> T:
    instance = self._instances.get(module_type)
    if instance is None:
      logging.error(f"Module '%s' not registered", module_type.__name__)
      return None
    return instance

  async def startup_all(self):
    async def _start(module_class: type, module: BaseModule):
      await module.startup()
      logging.info("[Module] %s started", module_class.__name__)

    await asyncio.gather(*(
      _start(module_class, module) for module_class, module in self._instances.items()
    ))

  async def shutdown_all(self):
    await asyncio.gather(*(module.shutdown() for module in self._instances.values()))
    self._instances.clear()

  async def restart(self, module_type: Type[T]) -> T:
    instance = self.get(module_type)
    await instance.shutdown()
    new_instance = module_type(self.app)
    self._instances[module_type] = new_instance
    await new_instance.startup()
    return new_instance