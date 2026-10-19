# Development State

## Current objective
- None — task complete.

## Current state
- `Linux/opencode/setup.sh` installs the subagent files dynamically: `list_repo_files()`
  enumerates `Linux/opencode/agents/` via the GitHub contents API (built from
  `REPO_OWNER`/`REPO_NAME`/`REPO_REF`), `agent_workspace_entries()` builds the
  `"<repo path>|<workspace path>"` entries, and the unchanged `deploy_file()` deploys each
  file to `<workspace>/.opencode/agents/<filename>` only if it does not exist. No agent
  names are hardcoded; `AGENTS.md` and `repo-config.json` entries are unchanged.
- Parsing works with jq and with a grep/sed fallback (jq is not guaranteed in the container);
  soft failure only (warning on stderr, stdout stays parseable). Known parser limitation
  (documented in the comment): filenames containing `}{` or escaped quotes are not recognized.
- Tests: `Linux/opencode/tests/test_setup.sh` (plain bash, no network, tests the actual code
  extracted from setup.sh) — 7 test groups, 14 assertions.

## Blockers and decisions
- No hardcoded fallback list: if the API is unreachable/rate-limited (60 req/h
  unauthenticated), agent files are skipped with a warning. Accepted trade-off, since the
  script runs via `curl | bash` without a local checkout.
- The installer reads the pushed `main` branch, so `implementer.md` is only installed after
  the agent files are committed and pushed.

## Verification status
- Completed: `bash Linux/opencode/tests/test_setup.sh` → all pass (14 assertions);
  pre-fix run against `git show HEAD:Linux/opencode/setup.sh` → fails for the intended reason
  (missing implementer.md/newagent.md, hardcoded agent name); guard-stripped copy fails only
  in Test 7 (proves the `set -euo pipefail` no-match case is covered); `bash -n` on both files;
  live API check: jq path and fallback path return the same list.
- Review: reviewer found no implementation defects; its MEDIUM finding (untested `|| true`
  guard) and two LOW test findings were implemented and re-verified.
- Pending or unavailable: shellcheck not installed in this environment; nothing committed.
