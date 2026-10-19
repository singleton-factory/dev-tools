# Development State

## Current objective
- None.

## Current state
- `AGENTS.md` and the agent definitions were updated by the user (PROJECT.md rules, reviewer shell
  permissions, commit/push rules); the installer change (`Linux/opencode/setup.sh` + test) is committed in
  `0bebe7b`.
- `PROJECT.md` did not exist and was created as the minimal evidence-based version (primary agent,
  documentation-only task, no reviewer).
- `Linux/opencode/agents/*.md` and `.opencode/agents/*.md` are identical for `implementer.md` and
  `reviewer.md` (verified with `diff -q`).

## Next actions / TODO
- [ ] Confirm the two open questions listed under "To confirm" in `PROJECT.md`
      (`.opencode/agents/` duplication, supported distributions).

## Blockers and decisions
- None.

## Verification status
- Completed: `bash Linux/opencode/tests/test_setup.sh` (all pass), `bash -n` on `setup.sh` and the test,
  `diff -q` on the mirrored agent files, `git status`/`git diff` inspected.
- Pending or unavailable: `shellcheck` not installed in this container.
