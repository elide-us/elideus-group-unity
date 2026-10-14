from __future__ import annotations
import asyncio

from scriptlib import connect, make_installer, install, list_packages, uninstall, make_package, populate


HELP_TEXT = """\
Available commands:
  help                          Show this help message
  exit, quit                    Exit the console
  reconnect <dbname>            Connect to a different database
  populate                      Reflect sys.* into contracts_db_* (fill kernel tables)
  make installer [name]         Read contracts_db_*, write <name>_YYYYMMDD.sql (the kernel installer)
  make package [name]           Export one package's owned rows -> <name>.json.gz (default: kernel)
  install <file>                Install a package file (.json or .json.gz): register → schema → materialize → data → seal
  list packages                 Show installed packages and row ownership
  uninstall <name>              Show uninstall plan (dry run)
  uninstall <name> confirm      Execute uninstall
  <raw sql>                     Run as-is, print rows or rowcount
"""


async def interactive_console(conn):
  print("Type 'help' for commands. Type 'exit' to quit.")
  while True:
    raw = input('SQL> ').strip()
    if not raw:
      continue
    cmd = raw.split()
    match cmd:
      case ['quit'] | ['exit']:
        break
      case ['help']:
        print(HELP_TEXT)
      case ['reconnect', dbname]:
        try:
          await conn.close()
          conn = await connect(dbname)
        except Exception as e:
          print('Error reconnecting: %s' % e)
      case ['populate']:
        try:
          await populate(conn)
        except Exception as e:
          print('Error populating: %s' % e)
      case ['make', 'installer']:
        try:
          await make_installer(conn)
        except Exception as e:
          print('Error making installer: %s' % e)
      case ['make', 'installer', name]:
        try:
          await make_installer(conn, name)
        except Exception as e:
          print('Error making installer: %s' % e)
      case ['make', 'package']:
        try:
          await make_package(conn)
        except Exception as e:
          print('Error making package: %s' % e)
      case ['make', 'package', name]:
        try:
          await make_package(conn, name)
        except Exception as e:
          print('Error making package: %s' % e)
      case ['install', path]:
        try:
          await install(conn, path)
        except Exception as e:
          print('Error installing: %s' % e)
      case ['list', 'packages']:
        try:
          await list_packages(conn)
        except Exception as e:
          print('Error listing: %s' % e)
      case ['uninstall', name]:
        try:
          await uninstall(conn, name, confirm=False)
        except Exception as e:
          print('Error: %s' % e)
      case ['uninstall', name, 'confirm']:
        try:
          await uninstall(conn, name, confirm=True)
        except Exception as e:
          print('Error: %s' % e)
      case _:
        try:
          async with conn.cursor() as cur:
            await cur.execute(raw)
            try:
              rows = await cur.fetchall()
              cols = [d[0] for d in cur.description]
              for row in rows:
                print(dict(zip(cols, row)))
            except Exception:
              print(cur.rowcount)
        except Exception as e:
          print('Error: %s' % e)


async def main():
  conn = await connect()
  try:
    await interactive_console(conn)
  finally:
    await conn.close()


if __name__ == '__main__':
  asyncio.run(main())
