import uuid, re

DETERMINISTIC_NS = uuid.UUID('DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB')

def deterministic_guid(determinisic_hash: uuid.UUID, entity_type: str, natural_key: str) -> str:
  return str(uuid.uuid5(determinisic_hash, f'{entity_type}:{natural_key}')).upper()

# -----------------------------------------------------------------------------
# Symbol Name Conversion Utilities
# -----------------------------------------------------------------------------
def snake_to_pascal(name: str) -> str:
  """Convert snake_case to PascalCase."""
  return "".join(part.capitalize() for part in name.split("_"))
  # regex: re.sub(r'(?:^|_)([a-z])', lambda m: m.group(1).upper(), name)

def pascal_to_snake(name: str) -> str:
  """Convert PascalCase to snake_case."""
  return re.sub(r'(?<=[a-z0-9])(?=[A-Z])', '_', name).lower()

def camel_to_snake(name: str) -> str:
  """Convert camelCast to snake_case."""
  return pascal_to_snake(name)

def snake_to_camel(name: str) -> str:
  """Convert snake_case to camelCase."""
  parts = name.split("_")
  return parts[0] + "".join(part.capitalize() for part in parts[1:])

