# Development State

## Current objective
- None.

## Current state
- User updated `Linux/opencode/agents/reviewer.md` (and its mirrored `.opencode/agents/` copy): `webfetch` and
  `websearch` are now `allow`, plus a new "External research" section with read-only research guidelines.
- `PROJECT.md` records that rule as a lasting constraint.
- Both copies of `reviewer.md` are identical (`diff -q`); the file now ends without a trailing newline.
- No implementation code changed; `setup.sh` and its test are untouched since `0bebe7b`.

## Next actions / TODO
- [ ] Confirm the two open questions listed under "To confirm" in `PROJECT.md`
      (`.opencode/agents/` duplication, supported distributions).

## Blockers and decisions
- None.

## Verification status
- Completed: `bash Linux/opencode/tests/test_setup.sh` (all pass), `diff -q` on the mirrored agent files,
  frontmatter key structure checked by hand (no YAML module available), `git status`/`git diff` inspected.
- Pending or unavailable: `shellcheck` not installed in this container.
