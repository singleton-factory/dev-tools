#!/usr/bin/env bash
#
# Test für Linux/opencode/setup.sh
#
# Getestet wird der TATSÄCHLICHE Code aus setup.sh: die Funktionen und die
# Konfigurationsvariablen werden per awk/sed aus setup.sh extrahiert und
# ausgewertet (nichts wird dupliziert). curl wird durch eine Shell-Funktion
# ersetzt, der Test läuft daher ohne Netzwerkzugriffe.
#
#   bash Linux/opencode/tests/test_setup.sh
#   SETUP_SH=/pfad/zu/setup.sh bash Linux/opencode/tests/test_setup.sh
#
# Der Test schlägt fehl, wenn die Agent-Dateien nicht dynamisch ermittelt
# werden (feste Agent-Namen), wenn vorhandene Zieldateien überschrieben
# werden oder wenn die Fallback-Pipeline unter set -euo pipefail hart
# abbricht (fehlendes "|| true").
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SH="${SETUP_SH:-${TESTS_DIR}/../setup.sh}"
if [[ ! -f "${SETUP_SH}" ]]; then
  printf 'setup.sh nicht gefunden: %s\n' "${SETUP_SH}"
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

FAILS=0
fail() { printf '  FEHLER: %b\n' "$*"; FAILS=$((FAILS + 1)); }
ok() { printf '  ok: %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Fixture-Antwort der GitHub-Contents-API. newagent.md ist in keiner festen
# Liste hinterlegt und kann nur über die dynamische Auflistung auftauchen.
# ---------------------------------------------------------------------------
cat > "${WORK}/fixture_pretty.json" <<'JSON'
[
  {
    "name": "implementer.md",
    "path": "Linux/opencode/agents/implementer.md",
    "sha": "1111111111111111111111111111111111111111",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/implementer.md?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/implementer.md",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/1111111111111111111111111111111111111111",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/agents/implementer.md",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/implementer.md?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/1111111111111111111111111111111111111111",
      "html": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/implementer.md"
    }
  },
  {
    "name": "reviewer.md",
    "path": "Linux/opencode/agents/reviewer.md",
    "sha": "2222222222222222222222222222222222222222",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/reviewer.md?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/reviewer.md",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/2222222222222222222222222222222222222222",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/agents/reviewer.md",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/reviewer.md?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/2222222222222222222222222222222222222222",
      "html": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/reviewer.md"
    }
  },
  {
    "name": "newagent.md",
    "path": "Linux/opencode/agents/newagent.md",
    "sha": "3333333333333333333333333333333333333333",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/newagent.md?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/newagent.md",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/3333333333333333333333333333333333333333",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/agents/newagent.md",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/newagent.md?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/3333333333333333333333333333333333333333",
      "html": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/newagent.md"
    }
  },
  {
    "name": "unterordner",
    "path": "Linux/opencode/agents/unterordner",
    "sha": "4444444444444444444444444444444444444444",
    "size": 0,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/unterordner?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/tree/main/Linux/opencode/agents/unterordner",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/trees/4444444444444444444444444444444444444444",
    "download_url": null,
    "type": "dir",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/unterordner?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/trees/4444444444444444444444444444444444444444"
    }
  }
]
JSON

# Kompaktform derselben Antwort (GNU-tools müssen beide Formen beherrschen)
printf '%s\n' '[{"name":"implementer.md","path":"Linux/opencode/agents/implementer.md","sha":"1111111111111111111111111111111111111111","size":10,"url":"u","html_url":"h","git_url":"g","download_url":"d","type":"file","_links":{"self":"s","git":"g"}},{"name":"reviewer.md","path":"Linux/opencode/agents/reviewer.md","sha":"2222222222222222222222222222222222222222","size":10,"url":"u","html_url":"h","git_url":"g","download_url":"d","type":"file","_links":{"self":"s","git":"g"}},{"name":"newagent.md","path":"Linux/opencode/agents/newagent.md","sha":"3333333333333333333333333333333333333333","size":10,"url":"u","html_url":"h","git_url":"g","download_url":"d","type":"file","_links":{"self":"s","git":"g"}},{"name":"unterordner","path":"Linux/opencode/agents/unterordner","sha":"4444444444444444444444444444444444444444","size":0,"url":"u","html_url":"h","git_url":"g","download_url":null,"type":"dir","_links":{"self":"s","git":"g"}}]' > "${WORK}/fixture_compact.json"

# Fixture ohne Treffer (nur Unterordner) und leere Antwort: der Fallback muss
# unter set -euo pipefail weich bleiben, weil grep exit 1 liefert
printf '%s\n' '[{"name":"unterordner","path":"Linux/opencode/agents/unterordner","sha":"4444444444444444444444444444444444444444","size":0,"url":"u","html_url":"h","git_url":"g","download_url":null,"type":"dir","_links":{"self":"s","git":"g"}}]' > "${WORK}/fixture_only_dirs.json"
printf '%s\n' '[]' > "${WORK}/fixture_empty.json"

EXPECTED_ENTRIES='Linux/opencode/agents/implementer.md|.opencode/agents/implementer.md
Linux/opencode/agents/reviewer.md|.opencode/agents/reviewer.md
Linux/opencode/agents/newagent.md|.opencode/agents/newagent.md'

# ---------------------------------------------------------------------------
# Code aus setup.sh extrahieren (Functionen + Konfiguration)
# ---------------------------------------------------------------------------
EXTRACTED="${WORK}/extracted.sh"
MISSING=0

extract_fn() {
  local fn="$1" body
  body="$(awk -v fn="${fn}" '
    $0 ~ "^" fn "\\(\\) \\{" {
      print
      if ($0 ~ /\}$/) { exit }
      while ((getline line) > 0) {
        print line
        if (line == "}") { exit }
      }
      exit
    }
  ' "${SETUP_SH}")"
  if [[ -z "${body}" ]]; then
    printf '  FEHLER: Funktion %s fehlt in %s\n' "${fn}" "${SETUP_SH}" >&2
    MISSING=$((MISSING + 1))
    return 1
  fi
  printf '%s\n' "${body}"
}

: > "${EXTRACTED}"
for fn in log download list_repo_files agent_workspace_entries install_as deploy_file; do
  extract_fn "${fn}" >> "${EXTRACTED}" || true
done

# Konfiguration (REPO_*, RAW_BASE, API_BASE, WORKSPACE_FILES) aus setup.sh
sed -n '/^REPO_OWNER=/,/^OPENCODE_INSTALL_URL=/p' "${SETUP_SH}" >> "${EXTRACTED}"
sed -n '/^WORKSPACE_FILES=(/,/^)/p' "${SETUP_SH}" >> "${EXTRACTED}"

# curl-Stub: keine Netzwerkzugriffe
CURL_URL=""
CURL_FAIL=0
FIXTURE=""
curl() {
  local out="" url="" content
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) out="$2"; shift 2 ;;
      --retry|--retry-delay) shift 2 ;;
      -*) shift ;;
      *) url="$1"; shift ;;
    esac
  done
  CURL_URL="${url}"
  if [[ "${CURL_FAIL}" -eq 1 ]]; then
    return 22
  fi
  case "${url}" in
    *"/contents/"*) content="$(cat "${FIXTURE}")" ;;
    *) content="Inhalt (Fixture) von ${url##*/}" ;;
  esac
  if [[ -n "${out}" ]]; then
    printf '%s\n' "${content}" > "${out}"
  else
    printf '%s\n' "${content}"
  fi
}

# jq bei Bedarf als nicht vorhanden melden (Fallback-Test)
NO_JQ=0
command() {
  if [[ "${NO_JQ}" -eq 1 && "${1}" == "-v" && "${2}" == "jq" ]]; then
    return 1
  fi
  builtin command "$@"
}

TARGET_USER="$(id -un)"

if [[ "${MISSING}" -gt 0 ]]; then
  fail "setup.sh enthält die dynamische Agent-Auflistung nicht (es fehlen ${MISSING} Funktion(en))"
fi

source "${EXTRACTED}"

# ---------------------------------------------------------------------------
# 1) Dynamische Auflistung: jq-Pfad
# ---------------------------------------------------------------------------
printf '\nTest 1: Auflistung mit jq (Pretty-Print-Antwort)\n'
FIXTURE="${WORK}/fixture_pretty.json"
NO_JQ=0
out="$(agent_workspace_entries 2>/dev/null)"
if [[ "${out}" == "${EXPECTED_ENTRIES}" ]]; then
  ok "drei Einträge im Format \"<Repo-Pfad>|<Zielpfad>\", Unterordner übersprungen"
else
  fail "erwartet:\n${EXPECTED_ENTRIES}\nerhalten:\n${out}"
fi

# ---------------------------------------------------------------------------
# 2) Dynamische Auflistung: grep/sed-Fallback ohne jq
# ---------------------------------------------------------------------------
printf '\nTest 2: Auflistung ohne jq\n'
NO_JQ=1
for form in pretty compact; do
  FIXTURE="${WORK}/fixture_${form}.json"
  out="$(agent_workspace_entries 2>/dev/null)"
  if [[ "${out}" == "${EXPECTED_ENTRIES}" ]]; then
    ok "Fallback (${form}): dieselben drei Einträge"
  else
    fail "Fallback (${form}) erwartet:\n${EXPECTED_ENTRIES}\nerhalten:\n${out}"
  fi
done
NO_JQ=0

# ---------------------------------------------------------------------------
# 3) API-URL wird aus REPO_OWNER/REPO_NAME/REPO_REF gebaut
# ---------------------------------------------------------------------------
printf '\nTest 3: API-URL\n'
expected_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/Linux/opencode/agents?ref=${REPO_REF}"
FIXTURE="${WORK}/fixture_pretty.json"
list_repo_files "Linux/opencode/agents" >/dev/null
if [[ "${CURL_URL}" == "${expected_url}" ]]; then
  ok "API_BASE genutzt: ${CURL_URL}"
else
  fail "erwartet ${expected_url}, erhalten ${CURL_URL}"
fi
config_block="$(sed -n '/^REPO_OWNER=/,/^OPENCODE_INSTALL_URL=/p' "${SETUP_SH}")"
if [[ "$(printf '%s\n' "${config_block}" | grep -c 'singleton-factory')" != "1" ]]; then
  fail "REPO_OWNER-Literal im Konfigurationsblock dupliziert"
else
  ok "Owner/Name/Ref nur in den Konfigurationsvariablen"
fi

# ---------------------------------------------------------------------------
# 4) Weicher Fehler unter set -euo pipefail (API nicht erreichbar)
# ---------------------------------------------------------------------------
printf '\nTest 4: weicher Fehler (API-Aufruf schlägt fehl)\n'
CURL_FAIL=1
out="$( ( set -euo pipefail; agent_workspace_entries ) 2>/dev/null )"
status=$?
err="$( ( set -euo pipefail; agent_workspace_entries ) 2>&1 1>/dev/null )"
CURL_FAIL=0
if [[ "${status}" -eq 0 && -z "${out}" && "${err}" == *WARNUNG* ]]; then
  ok "leere Eintragsliste auf Standardausgang, Warnung auf Standardfehler, kein harter Abbruch"
else
  fail "exit=${status}, stdout='${out}', stderr='${err}'"
fi

# ---------------------------------------------------------------------------
# 5) End-to-End: Workspace-Installation (Abschnitt 4a aus setup.sh)
#    vorhandene Dateien werden NIEMALS überschrieben
# ---------------------------------------------------------------------------
printf '\nTest 5: Workspace-Installation (existierende Datei bleibt erhalten)\n'
WS="${WORK}/workspace"
mkdir -p "${WS}/.opencode/agents"
printf 'BESTEHEND (darf nicht ersetzt werden)\n' > "${WS}/AGENTS.md"
printf 'BESTEHEND (darf nicht ersetzt werden)\n' > "${WS}/.opencode/agents/reviewer.md"
WORKSPACE_DIR="${WS}"

block="$(sed -n '/^# 4a)/,/^fi$/p' "${SETUP_SH}")"
if [[ -z "${block}" ]]; then
  fail "Abschnitt 4a in ${SETUP_SH} nicht gefunden"
else
  eval "${block}"
  if [[ "$(cat "${WS}/AGENTS.md")" == "BESTEHEND (darf nicht ersetzt werden)" ]]; then
    ok "AGENTS.md (fester Eintrag) nicht überschrieben"
  else
    fail "AGENTS.md wurde überschrieben"
  fi
  if [[ "$(cat "${WS}/.opencode/agents/reviewer.md")" == "BESTEHEND (darf nicht ersetzt werden)" ]]; then
    ok "existierende Agent-Datei nicht überschrieben"
  else
    fail "existierende Agent-Datei wurde überschrieben"
  fi
  if [[ -f "${WS}/opencode.json" ]]; then
    ok "repo-config.json -> opencode.json (fester Eintrag) installiert"
  else
    fail "opencode.json fehlt"
  fi
  for name in implementer.md newagent.md; do
    if [[ -f "${WS}/.opencode/agents/${name}" ]]; then
      ok "dynamisch installiert: .opencode/agents/${name}"
    else
      fail ".opencode/agents/${name} fehlt (nur hardcoded Namen würden installiert)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 6) Keine einzeln aufgeführten Agent-Namen
# ---------------------------------------------------------------------------
printf '\nTest 6: keine hartcodierten Agent-Namen\n'
hardcoded="$(grep -nE 'agents/[A-Za-z0-9_-]+\.md' "${SETUP_SH}" | head -1)"
if [[ -n "${hardcoded}" ]]; then
  fail "setup.sh enthält einen hartcodierten Agent-Namen: ${hardcoded}"
else
  ok "Agent-Dateien werden nicht einzeln aufgeführt"
fi

# ---------------------------------------------------------------------------
# 7) Fallback-Pipeline unter set -euo pipefail, wenn nichts passt
#    (grep exit 1; ohne "|| true" bricht das Skript hart ab)
# ---------------------------------------------------------------------------
printf '\nTest 7: Fallback ohne Treffer unter set -euo pipefail\n'
NO_JQ=1
for fixture in fixture_only_dirs.json fixture_empty.json; do
  FIXTURE="${WORK}/${fixture}"
  out="$( ( set -euo pipefail; list_repo_files "Linux/opencode/agents" ) 2>/dev/null )"
  status=$?
  if [[ "${status}" -eq 0 && -z "${out}" ]]; then
    ok "${fixture}: kein harter Abbruch (exit 0), leere Liste"
  else
    fail "${fixture}: exit=${status}, stdout='${out}' (Pipeline bricht ab)"
  fi
done
NO_JQ=0

printf '\n'
if [[ "${FAILS}" -gt 0 ]]; then
  printf 'TEST FEHLGESCHLAGEN: %s\n' "${FAILS}"
  exit 1
fi
printf 'ALLE TESTS BESTANDEN\n'
