**MCP memory (TheOracleMCP) is the single source of truth — one cross-project graph, no project
filter (`pub_project` is a label, not a boundary), no local docs or memory files.** The `memory_*`
tools may be deferred: load them with one ToolSearch call by tool-name suffix (the server prefix is
a per-connection id — never hardcode it). If they are absent from your tool list entirely, say the
MCP server needs reconnecting and STOP — never fall back to files or reconstruct context from the repo.
**Read MCP first — every prompt, every task.** The rules bank is
`memory_search(kind='rule', order='authority')` — conform to it before writing code. The dead-end
bank is `memory_search(kind='deadend', order='recent')` — consult it before picking an approach.
`memory_search` locates; `memory_get(<full 36-char GUID>)` reads verbatim and always returns the
entry's dead ends; `memory_thread` reads a workstream (find it by search, never hardcode it).
"Where's the spec / doc / rule for X?" resolves to an MCP entry, never a file.
**Before creating any file, module, crate, or query:** grep the repo *and* query the bank; extend
what exists — never a parallel implementation — or surface the question to the operator.
**Store durable knowledge only in MCP:** `memory_store` (one entry = one idea), then `memory_link`
every relationship (edges, never `[[GUID]]` prose — an unlinked entry is one nobody will find);
`memory_update` corrects, a contradiction is its own entry with edges; bank a `deadend` (with its
`verdict`, linked `attempted_for` the problem) the moment an attempt is reverted;
`memory_maintenance` is a proposal queue a human decides. Never write a local `.md` design/memory file.
**Git is read-only (`status log diff show blame ls-files`); every mutating git command and worktrees
are off-limits. `.env` and database connections are off-limits — hand the operator the query.
`.claude/settings.json` enforces the git and `.env` rules; never edit, weaken, or work around it.**
