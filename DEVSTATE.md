# Development State

## Current objective
- None. Dynamic template deployment in `Linux/opencode/setup.sh` is implemented, tested, reviewed (PASS) and
  committed.

## Current state
- `setup.sh`: fixed `WORKSPACE_FILES` list removed. `list_opencode_dir()` caches one contents-API listing of
  `Linux/opencode` per run (shared by 4a and 4b); `workspace_entries_from_dir()` maps it by rules
  (`repo-config.json` -> `opencode.json`, `global-*.json` -> handled globally in 4b, `*.sh` and directories ->
  skipped, other regular files -> same name in the workspace). 4b resolves its source from the same listing via
  `global-*.json` and logs a `HINWEIS` when none is found. Agent `.md` files stay fully dynamic
  (`agent_workspace_entries` -> `.opencode/agents/<filename>`). Exactly 2 API listings per run.
- `Linux/opencode/tests/test_setup.sh`: 12 groups; extraction fails loudly when a function/section is missing.
- Reviewer PASS; its only finding (a misleading `list_opencode_dir` comment) is fixed.
- Commits created: `95c05f9` (setup.sh + tests), `62a3e9f` (AGENTS.md rework), `91fc828` (context 131072 ->
  196608 in `opencode.json` and `Linux/opencode/global-config.json`), `7c01947` (docs), `97ce319` (agent model
  `qwen3.8-flash-next-parallel` -> dedicated `...-implementer` / `...-reviewer` in both agent-file copies).
- Nothing pushed: `origin/main` is still `9f157b9`, so the new installer behavior is not yet live in devcontainers
  (the installer reads the pushed `main`).
- `AGENTS.md` and `Linux/opencode/AGENTS.md` are identical again; `.opencode/agents/*` matches
  `Linux/opencode/agents/*`.

## Next actions / TODO
- [ ] Push to `origin/main` on explicit user request only — required before the new setup.sh behavior takes effect.
- [ ] Answer the two open questions in `PROJECT.md` "To confirm" (keep `.opencode/agents/` in the repo? supported
      distributions?).

## Blockers and decisions
- None.

## Verification status
- Completed: `bash -n` on `setup.sh`, the test file and the previous version; `bash Linux/opencode/tests/test_setup.sh`
  -> exit 0, all 12 groups (re-run after the comment fix); `SETUP_SH=/tmp/opencode/old_setup.sh bash ...` -> exit 1
  with 15 failures (regression proof); live contents-API listing of both folders matches the mapping rules; staged
  diffs reviewed for credentials before each commit (only instruction text matched, no secrets).
- Unavailable: `shellcheck` (not installed in this container). The reviewer had no shell access in its environment,
  so its conclusions are static; the executed runs above are the primary agent's.
