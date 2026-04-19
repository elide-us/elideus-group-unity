import logging, aioodbc, json
from typing import Any

from . import DatabaseTransactionProvider

logger = logging.getLogger(__name__.split('.')[-1])

class MssqlProvider(DatabaseTransactionProvider):
  async def connect(self):
    self.pool = await aioodbc.create_pool(dsn=self._dsn, minsize=1, maxsize=5)
    logger.info("Connection pool created")

  async def disconnect(self):
    if self.pool:
      self.pool.close()
      await self.pool.wait_closed()
      self.pool = None
      logger.info("Connection pool closed")

  async def query(self, query: str, params: tuple | None = None) -> Any:
    async with self.pool.acquire() as conn:
      async with conn.cursor() as cur:
        await cur.execute(query, params or ())
        parts = []
        while True:
          row = await cur.fetchone()
          if not row or not row[0]:
            break
          parts.append(row[0])
        if not parts:
          return None
        return json.loads("".join(parts))

  async def execute(self, query: str, params: tuple | None = None) -> int:
    try:
      async with self.pool.acquire() as conn:
        async with conn.cursor() as cur:
          await cur.execute(query, params or ())
          return cur.rowcount
    except Exception as e:
      logger.error("Execute failed: %s", e)
      return -1