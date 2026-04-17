import uuid, re

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
