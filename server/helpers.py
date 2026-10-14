import uuid, re, os, importlib

def deterministic_guid(deterministic_hash: uuid.UUID, entity_type: str, natural_key: str) -> str:
  return str(uuid.uuid5(deterministic_hash, f'{entity_type}:{natural_key}')).upper()

# Use Case: module_name to ClassName
def snake_to_pascal(name: str) -> str:
  """Convert snake_case to PascalCase."""
  return "".join(part.capitalize() for part in name.split("_"))

# Use Case: ClassName to module_name
def pascal_to_snake(name: str) -> str:
  """Convert PascalCase to snake_case."""
  return re.sub(r'(?<=[a-z0-9])(?=[A-Z])', '_', name).lower()

# Use Case: FIIK
def camel_to_snake(name: str) -> str:
  """Convert camelCase to snake_case."""
  return pascal_to_snake(name)

# Use Case: function_name to .affixationName
def snake_to_camel(name: str) -> str:
  """Convert snake_case to camelCase."""
  parts = name.split("_")
  return parts[0] + "".join(part.capitalize() for part in parts[1:])

# Use Case: an executor module loads the provider classes in its providers package
def discover_classes(package: str, suffix: str) -> dict[str, type]:
  """Import every <stem><suffix>.py in the package and return {stem: class}.
  The class is named snake_to_pascal(stem) — the same rule the module loader
  applies to *_module.py. A file without its class stops the boot."""
  classes: dict[str, type] = {}
  folder = importlib.import_module(package).__path__[0]
  for fname in sorted(os.listdir(folder)):
    if not fname.endswith(f"{suffix}.py") or fname == "__init__.py":
      continue
    file_stem = fname[:-3]
    class_name = snake_to_pascal(file_stem)
    module = importlib.import_module(f"{package}.{file_stem}")
    if not hasattr(module, class_name):
      raise ImportError(f"'{file_stem}' missing expected class '{class_name}'")
    classes[file_stem] = getattr(module, class_name)
  return classes
