import logging, aioodbc, json

from . import BaseDatabaseProvider


class MssqlProvider(BaseDatabaseProvider):
  async def connect(self):
    self.pool = await aioodbc.create_pool(dsn=self._dsn, minsize=1, maxsize=5)
    logging.info("Connection pool created")

  async def disconnect(self):
    if self.pool:
      self.pool.close()
      await self.pool.wait_closed()
      self.pool = None
      logging.info("Connection pool closed")

  async def query(self, query: str, params: tuple | None = None) -> any:
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

  async def execute(self, query: str, params: tuple | None = None) -> int | None:
    async with self.pool.acquire() as conn:
      async with conn.cursor() as cur:
        await cur.execute(query, params or ())
        return cur.rowcount