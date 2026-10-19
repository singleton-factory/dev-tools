#!/usr/bin/env bash
#
# Test für Linux/opencode/setup.sh
#
# Getestet wird der TATSÄCHLICHE Code aus setup.sh: die Funktionen, die
# Konfigurationsvariablen und die Abschnitte 4a/4b werden per awk/sed aus
# setup.sh extrahiert und ausgewertet (nichts wird dupliziert). curl wird
# durch eine Shell-Funktion ersetzt, der Test läuft daher ohne Netzwerkzugriffe.
#
#   bash Linux/opencode/tests/test_setup.sh
#   SETUP_SH=/pfad/zu/setup.sh bash Linux/opencode/tests/test_setup.sh
#
# Der Test schlägt fehl, wenn
#   - deployed Dateien über feste Dateipfade ermittelt werden statt über die
#     Ordnerauflösung von Linux/opencode (WORKSPACE_FILES, fester Pfad zur
#     globalen Config),
#   - Agent-Dateien einzeln aufgeführt werden (feste Agent-Namen),
#   - eine Top-Level-Datei fehlt, die nur aus der Ordnerauflösung kommen kann
#     (extra-template.md),
#   - Skript-/Testdateien des Ordners in den Workspace installiert werden,
#   - ein Ordner pro Lauf mehr als einmal über die API aufgelistet wird,
#   - vorhandene Zieldateien überschrieben werden,
#   - die Fallback-Pipeline unter set -euo pipefail hart abbricht
#     (fehlendes "|| true") oder
#   - ein Download/eine Auflistung fehlschlägt und das Skript hart abbricht.
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
# Fixture-Antworten der GitHub-Contents-API
#
# a) Linux/opencode/agents: newagent.md ist in keiner festen Liste hinterlegt
#    und kann nur über die dynamische Auflistung auftauchen.
# b) Linux/opencode: extra-template.md ist ebenfalls in keiner festen Liste
#    hinterlegt; setup.sh/tests sind als Einträge enthalten und dürfen nicht
#    im Workspace landen.
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
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/1111111111111111111111111111111111111111"
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
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/2222222222222222222222222222222222222222"
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
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/3333333333333333333333333333333333333333"
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

cat > "${WORK}/fixture_compact.json" <<'JSON'
[{"name":"implementer.md","path":"Linux/opencode/agents/implementer.md","sha":"1111111111111111111111111111111111111111","size":10,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/implementer.md?ref=main","html_url":"https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/implementer.md","git_url":"https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/1111111111111111111111111111111111111111","download_url":"https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/agents/implementer.md","type":"file","_links":{"self":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/implementer.md?ref=main","git":"https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/1111111111111111111111111111111111111111"}},{"name":"reviewer.md","path":"Linux/opencode/agents/reviewer.md","sha":"2222222222222222222222222222222222222222","size":10,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/reviewer.md?ref=main","html_url":"https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/reviewer.md","git_url":"https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/2222222222222222222222222222222222222222","download_url":"https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/agents/reviewer.md","type":"file","_links":{"self":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/reviewer.md?ref=main","git":"https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/2222222222222222222222222222222222222222"}},{"name":"newagent.md","path":"Linux/opencode/agents/newagent.md","sha":"3333333333333333333333333333333333333333","size":10,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/newagent.md?ref=main","html_url":"https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/agents/newagent.md","git_url":"https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/3333333333333333333333333333333333333333","download_url":"https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/agents/newagent.md","type":"file","_links":{"self":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/newagent.md?ref=main","git":"https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/3333333333333333333333333333333333333333"}},{"name":"unterordner","path":"Linux/opencode/agents/unterordner","sha":"4444444444444444444444444444444444444444","size":0,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/unterordner?ref=main","html_url":"https://github.com/singleton-factory/dev-tools/tree/main/Linux/opencode/agents/unterordner","git_url":"https://api.github.com/repos/singleton-factory/dev-tools/git/trees/4444444444444444444444444444444444444444","download_url":null,"type":"dir","_links":{"self":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents/unterordner?ref=main","git":"https://api.github.com/repos/singleton-factory/dev-tools/git/trees/4444444444444444444444444444444444444444"}}]
JSON

# Top-Level-Auflistung von Linux/opencode (Reihenfolge wie in der echten API)
cat > "${WORK}/fixture_dir_pretty.json" <<'JSON'
[
  {
    "name": "AGENTS.md",
    "path": "Linux/opencode/AGENTS.md",
    "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/AGENTS.md?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/AGENTS.md",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/AGENTS.md",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/AGENTS.md?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  },
  {
    "name": "agents",
    "path": "Linux/opencode/agents",
    "sha": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "size": 0,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/tree/main/Linux/opencode/agents",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/trees/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "download_url": null,
    "type": "dir",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/trees/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    }
  },
  {
    "name": "extra-template.md",
    "path": "Linux/opencode/extra-template.md",
    "sha": "cccccccccccccccccccccccccccccccccccccccc",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/extra-template.md?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/extra-template.md",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/cccccccccccccccccccccccccccccccccccccccc",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/extra-template.md",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/extra-template.md?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/cccccccccccccccccccccccccccccccccccccccc"
    }
  },
  {
    "name": "global-config.json",
    "path": "Linux/opencode/global-config.json",
    "sha": "dddddddddddddddddddddddddddddddddddddddd",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/global-config.json?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/global-config.json",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/dddddddddddddddddddddddddddddddddddddddd",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/global-config.json",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/global-config.json?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/dddddddddddddddddddddddddddddddddddddddd"
    }
  },
  {
    "name": "repo-config.json",
    "path": "Linux/opencode/repo-config.json",
    "sha": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/repo-config.json?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/repo-config.json",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/repo-config.json",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/repo-config.json?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
    }
  },
  {
    "name": "setup.sh",
    "path": "Linux/opencode/setup.sh",
    "sha": "ffffffffffffffffffffffffffffffffffffffff",
    "size": 10,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/setup.sh?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/blob/main/Linux/opencode/setup.sh",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/ffffffffffffffffffffffffffffffffffffffff",
    "download_url": "https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/setup.sh",
    "type": "file",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/setup.sh?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/blobs/ffffffffffffffffffffffffffffffffffffffff"
    }
  },
  {
    "name": "tests",
    "path": "Linux/opencode/tests",
    "sha": "9999999999999999999999999999999999999999",
    "size": 0,
    "url": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/tests?ref=main",
    "html_url": "https://github.com/singleton-factory/dev-tools/tree/main/Linux/opencode/tests",
    "git_url": "https://api.github.com/repos/singleton-factory/dev-tools/git/trees/9999999999999999999999999999999999999999",
    "download_url": null,
    "type": "dir",
    "_links": {
      "self": "https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/tests?ref=main",
      "git": "https://api.github.com/repos/singleton-factory/dev-tools/git/trees/9999999999999999999999999999999999999999"
    }
  }
]
JSON

# Kompakte Variante (ein Block, wie curl die API-Antwort typisch liefert)
sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "${WORK}/fixture_dir_pretty.json" \
  | tr -d '\n' > "${WORK}/fixture_dir_compact.json"

# Top-Level-Auflistung ohne global-*.json
cat > "${WORK}/fixture_dir_no_global.json" <<'JSON'
[{"name":"AGENTS.md","path":"Linux/opencode/AGENTS.md","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":10,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/AGENTS.md?ref=main","download_url":"https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/AGENTS.md","type":"file"},{"name":"agents","path":"Linux/opencode/agents","sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":0,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents?ref=main","download_url":null,"type":"dir"},{"name":"repo-config.json","path":"Linux/opencode/repo-config.json","sha":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","size":10,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/repo-config.json?ref=main","download_url":"https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/repo-config.json","type":"file"},{"name":"setup.sh","path":"Linux/opencode/setup.sh","sha":"ffffffffffffffffffffffffffffffffffffffff","size":10,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/setup.sh?ref=main","download_url":"https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/setup.sh","type":"file"},{"name":"tests","path":"Linux/opencode/tests","sha":"9999999999999999999999999999999999999999","size":0,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/tests?ref=main","download_url":null,"type":"dir"}]
JSON

# Nur Ordner, keine Dateien
cat > "${WORK}/fixture_only_dirs.json" <<'JSON'
[{"name":"agents","path":"Linux/opencode/agents","sha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":0,"url":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents?ref=main","html_url":"https://github.com/singleton-factory/dev-tools/tree/main/Linux/opencode/agents","git_url":"https://api.github.com/repos/singleton-factory/dev-tools/git/trees/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","download_url":null,"type":"dir","_links":{"self":"https://api.github.com/repos/singleton-factory/dev-tools/contents/Linux/opencode/agents?ref=main","git":"https://api.github.com/repos/singleton-factory/dev-tools/git/trees/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}]
JSON

# Leere Auflistung
cat > "${WORK}/fixture_empty.json" <<'JSON'
[]
JSON

# ---------------------------------------------------------------------------
# Code aus setup.sh extrahieren (nichts wird im Test dupliziert)
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
for fn in log download list_repo_files agent_workspace_entries list_opencode_dir \
          workspace_entries_from_dir install_as deploy_file; do
  extract_fn "${fn}" >> "${EXTRACTED}" || true
done

# Konfiguration (REPO_*, RAW_BASE, API_BASE) aus setup.sh. Der Block muss
# vorhanden sein, sonst würden die nachfolgenden Tests stillschweigend nichts
# prüfen.
config_block="$(sed -n '/^REPO_OWNER=/,/^OPENCODE_INSTALL_URL=/p' "${SETUP_SH}")"
if [[ -z "${config_block}" ]] || ! printf '%s\n' "${config_block}" | grep -q '^API_BASE='; then
  fail "Konfigurationsblock (REPO_OWNER..OPENCODE_INSTALL_URL inkl. API_BASE) in ${SETUP_SH} nicht gefunden"
else
  printf '%s\n' "${config_block}" >> "${EXTRACTED}"
fi

# Cache-Variablen (list_opencode_dir) aus setup.sh übernehmen
cache_vars="$(grep -nE '^OPENCODE_DIR_(NAMES|LISTED)=' "${SETUP_SH}" || true)"
if [[ -z "${cache_vars}" ]]; then
  fail "Cache-Variablen OPENCODE_DIR_NAMES/OPENCODE_DIR_LISTED fehlen in ${SETUP_SH}"
else
  sed -nE '/^OPENCODE_DIR_(NAMES|LISTED)=/p' "${SETUP_SH}" >> "${EXTRACTED}"
fi

# Abschnitte 4a und 4b werden über die Abschnittsüberschriften begrenzt, damit
# der Test unabhängig von der Version des Skripts genau die richtigen Zeilen
# erwischt (und nichts aus Abschnitt 5).
block4a="$(sed -n '/^# 4a)/,/^# 4b)/p' "${SETUP_SH}" | sed '$d')"
block4b="$(sed -n '/^# 4b)/,/^# 5)/p' "${SETUP_SH}" | sed '$d')"
if [[ -z "${block4a}" ]]; then
  fail "Abschnitt '# 4a)' in ${SETUP_SH} nicht gefunden"
else
  ok "Abschnitt 4a extrahiert ($(printf '%s\n' "${block4a}" | wc -l) Zeilen)"
fi
if [[ -z "${block4b}" ]]; then
  fail "Abschnitt '# 4b)' in ${SETUP_SH} nicht gefunden"
else
  ok "Abschnitt 4b extrahiert ($(printf '%s\n' "${block4b}" | wc -l) Zeilen)"
fi

# ---------------------------------------------------------------------------
# curl-Stub: keine Netzwerkzugriffe. Die Fixture wird je nach angefragtem
# Ordner ausgewählt; jede Anfrage wird protokolliert, um die Anzahl der
# API-Aufrufe pro Ordner prüfen zu können.
# ---------------------------------------------------------------------------
CURL_URL=""
CURL_FAIL=0
CURL_LOG_FILE=""
FIXTURE=""
FIXTURE_AGENTS=""

curl() {
  local out="" url="" file="" content=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) out="$2"; shift 2 ;;
      --retry|--retry-delay) shift 2 ;;
      -*) shift ;;
      *) url="$1"; shift ;;
    esac
  done
  CURL_URL="${url}"
  if [[ -n "${CURL_LOG_FILE}" ]]; then
    printf '%s\n' "${url}" >> "${CURL_LOG_FILE}"
  fi
  if [[ "${CURL_FAIL}" -eq 1 ]]; then
    return 22
  fi
  case "${url}" in
    *"/contents/Linux/opencode/agents"*) file="${FIXTURE_AGENTS}" ;;
    *"/contents/"*) file="${FIXTURE}" ;;
  esac
  if [[ -n "${file}" && -f "${file}" ]]; then
    content="$(cat "${file}")"
  fi
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

# Fixture-Paar für die gewünschte Formatvariante setzen
use_fixtures() {
  FIXTURE="${WORK}/fixture_dir_${1}.json"
  FIXTURE_AGENTS="${WORK}/fixture_${1}.json"
}

# Listing-Cache vor jedem Block/Lauf zurücksetzen
reset_dir_cache() {
  OPENCODE_DIR_NAMES=""
  OPENCODE_DIR_LISTED=0
}

# Anzahl der Listings eines Ordners im aktuellen Aufrufprotokoll
listing_calls() {
  local n
  n="$(grep -F -c "${1}" "${CURL_LOG_FILE}" 2>/dev/null || true)"
  printf '%s\n' "${n:-0}"
}

if [[ "${MISSING}" -gt 0 ]]; then
  fail "setup.sh enthält die dynamische Ordner-Auflösung nicht (es fehlen ${MISSING} Funktion(en))"
fi

source "${EXTRACTED}"

# Erwartete Einträge im Format "<Repo-Pfad>|<Ziel relativ zum Workspace>"
EXPECTED_WS_ENTRIES='Linux/opencode/AGENTS.md|AGENTS.md
Linux/opencode/extra-template.md|extra-template.md
Linux/opencode/repo-config.json|opencode.json'

EXPECTED_AGENT_ENTRIES='Linux/opencode/agents/implementer.md|.opencode/agents/implementer.md
Linux/opencode/agents/reviewer.md|.opencode/agents/reviewer.md
Linux/opencode/agents/newagent.md|.opencode/agents/newagent.md'

# ---------------------------------------------------------------------------
# 1) Workspace-Einträge aus der Ordnerauflösung (jq-Pfad)
# ---------------------------------------------------------------------------
printf '\nTest 1: Workspace-Einträge aus der Ordnerauflösung (jq)\n'
use_fixtures pretty
NO_JQ=0
reset_dir_cache
out="$(workspace_entries_from_dir 2>/dev/null)"
if [[ "${out}" == "${EXPECTED_WS_ENTRIES}" ]]; then
  ok "AGENTS.md, extra-template.md, repo-config.json -> opencode.json"
else
  fail "erwartet:\n${EXPECTED_WS_ENTRIES}\nerhalten:\n${out}"
fi
# extra-template.md ist in keiner festen Liste hinterlegt: sie kann nur aus
# der Ordnerauflösung stammen.
if printf '%s\n' "${out}" | grep -q 'extra-template\.md'; then
  ok "extra-template.md wird allein aus der Ordnerauflösung installiert"
else
  fail "extra-template.md fehlt in den Workspace-Einträgen"
fi
# Skript-, Test- und Ordnerdateien dürfen nicht in den Workspace gehören
if printf '%s\n' "${out}" | grep -nE 'setup\.sh|tests|global-config'; then
  fail "unzulässige Workspace-Einträge (setup.sh/tests/global-*.json) oben"
else
  ok "setup.sh, tests und global-*.json werden nicht in den Workspace installiert"
fi

# ---------------------------------------------------------------------------
# 2) Workspace-Einträge ohne jq (grep/sed-Fallback, beide Antwortformate)
# ---------------------------------------------------------------------------
printf '\nTest 2: Workspace-Einträge ohne jq\n'
NO_JQ=1
for form in pretty compact; do
  use_fixtures "${form}"
  reset_dir_cache
  out="$(workspace_entries_from_dir 2>/dev/null)"
  if [[ "${out}" == "${EXPECTED_WS_ENTRIES}" ]]; then
    ok "Fallback (${form}): dieselben Einträge"
  else
    fail "Fallback (${form}) erwartet:\n${EXPECTED_WS_ENTRIES}\nerhalten:\n${out}"
  fi
done
NO_JQ=0

# ---------------------------------------------------------------------------
# 3) Agent-Dateien bleiben vollständig dynamisch (Ordner Linux/opencode/agents)
# ---------------------------------------------------------------------------
printf '\nTest 3: Agent-Einträge (jq und ohne jq)\n'
for form in pretty compact; do
  NO_JQ=0
  use_fixtures "${form}"
  reset_dir_cache
  out="$(agent_workspace_entries 2>/dev/null)"
  if [[ "${out}" == "${EXPECTED_AGENT_ENTRIES}" ]]; then
    ok "jq (${form}): drei Einträge, Unterordner übersprungen"
  else
    fail "jq (${form}) erwartet:\n${EXPECTED_AGENT_ENTRIES}\nerhalten:\n${out}"
  fi
  NO_JQ=1
  use_fixtures "${form}"
  reset_dir_cache
  out="$(agent_workspace_entries 2>/dev/null)"
  if [[ "${out}" == "${EXPECTED_AGENT_ENTRIES}" ]]; then
    ok "Fallback (${form}): dieselben drei Einträge"
  else
    fail "Fallback (${form}) erwartet:\n${EXPECTED_AGENT_ENTRIES}\nerhalten:\n${out}"
  fi
done
NO_JQ=0

# ---------------------------------------------------------------------------
# 4) API-URLs werden aus REPO_OWNER/REPO_NAME/REPO_REF gebaut
# ---------------------------------------------------------------------------
printf '\nTest 4: API-URLs\n'
use_fixtures pretty
reset_dir_cache
expected_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/Linux/opencode/agents?ref=${REPO_REF}"
list_repo_files "Linux/opencode/agents" >/dev/null 2>&1
if [[ "${CURL_URL}" == "${expected_url}" ]]; then
  ok "API_BASE genutzt: ${CURL_URL}"
else
  fail "erwartet ${expected_url}, erhalten ${CURL_URL}"
fi
expected_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/Linux/opencode?ref=${REPO_REF}"
reset_dir_cache
list_repo_files "Linux/opencode" >/dev/null 2>&1
if [[ "${CURL_URL}" == "${expected_url}" ]]; then
  ok "API_BASE genutzt: ${CURL_URL}"
else
  fail "erwartet ${expected_url}, erhalten ${CURL_URL}"
fi
if [[ "$(printf '%s\n' "${config_block}" | grep -c 'singleton-factory')" != "1" ]]; then
  fail "REPO_OWNER-Literal im Konfigurationsblock dupliziert"
else
  ok "Owner/Name/Ref nur in den Konfigurationsvariablen"
fi

# ---------------------------------------------------------------------------
# 5) Weicher Fehler unter set -euo pipefail (API nicht erreichbar)
# ---------------------------------------------------------------------------
printf '\nTest 5: weicher Fehler (API-Aufruf schlägt fehl)\n'
CURL_FAIL=1
out="$( ( set -euo pipefail; agent_workspace_entries ) 2>/dev/null )"
status=$?
err="$( ( set -euo pipefail; agent_workspace_entries ) 2>&1 1>/dev/null )"
if [[ "${status}" -eq 0 && -z "${out}" && "${err}" == *WARNUNG* ]]; then
  ok "Agent-Auflösung: leere Liste, Warnung auf Standardfehler, kein harter Abbruch"
else
  fail "exit=${status}, stdout='${out}', stderr='${err}'"
fi
reset_dir_cache
out="$( ( set -euo pipefail; workspace_entries_from_dir ) 2>/dev/null )"
status=$?
err="$( ( set -euo pipefail; workspace_entries_from_dir ) 2>&1 1>/dev/null )"
CURL_FAIL=0
if [[ "${status}" -eq 0 && -z "${out}" && "${err}" == *WARNUNG* ]]; then
  ok "Ordnerauflösung: leere Liste, Warnung auf Standardfehler, kein harter Abbruch"
else
  fail "exit=${status}, stdout='${out}', stderr='${err}'"
fi

# ---------------------------------------------------------------------------
# 6) End-to-End: Abschnitte 4a und 4b in EINEM Lauf
#    - jede Ordnerauflösung trifft die API genau einmal
#    - vorhandene Dateien werden NIEMALS überschrieben
#    - extra-template.md landet nur dank Ordnerauflösung im Workspace
# ---------------------------------------------------------------------------
printf '\nTest 6: End-to-End 4a+4b (ein Listing pro Ordner, nichts wird überschrieben)\n'
WS="${WORK}/workspace"
mkdir -p "${WS}/.opencode/agents"
printf 'BESTEHEND (darf nicht ersetzt werden)\n' > "${WS}/AGENTS.md"
printf 'BESTEHEND (darf nicht ersetzt werden)\n' > "${WS}/.opencode/agents/reviewer.md"
WORKSPACE_DIR="${WS}"
TARGET_HOME="${WORK}/home"
mkdir -p "${TARGET_HOME}"
use_fixtures pretty
reset_dir_cache
CURL_LOG_FILE="${WORK}/calls_4a4b.txt"
: > "${CURL_LOG_FILE}"
out="$( ( set -euo pipefail; eval "${block4a}"; eval "${block4b}" ) 2>&1 )"
status=$?
if [[ "${status}" -ne 0 ]]; then
  fail "4a+4b brechen hart ab (exit=${status}):\n${out}"
fi
if [[ "$(cat "${WS}/AGENTS.md")" == "BESTEHEND (darf nicht ersetzt werden)" ]]; then
  ok "AGENTS.md aus der Ordnerauflösung, aber nicht überschrieben"
else
  fail "AGENTS.md wurde überschrieben"
fi
if [[ "$(cat "${WS}/.opencode/agents/reviewer.md")" == "BESTEHEND (darf nicht ersetzt werden)" ]]; then
  ok "existierende Agent-Datei nicht überschrieben"
else
  fail "existierende Agent-Datei wurde überschrieben"
fi
if [[ -f "${WS}/opencode.json" ]]; then
  ok "repo-config.json -> opencode.json installiert"
else
  fail "opencode.json fehlt (fester Eintrag entfernt, aber nicht dynamisch ersetzt)"
fi
if [[ -f "${WS}/extra-template.md" ]]; then
  ok "extra-template.md installiert (nur aus der Ordnerauflösung bekannt)"
else
  fail "extra-template.md fehlt: Top-Level-Dateien werden nicht aus dem Ordner gelesen"
fi
for name in implementer.md newagent.md; do
  if [[ -f "${WS}/.opencode/agents/${name}" ]]; then
    ok "dynamisch installiert: .opencode/agents/${name}"
  else
    fail ".opencode/agents/${name} fehlt (nur hardcoded Namen würden installiert)"
  fi
done
if [[ -e "${WS}/setup.sh" || -e "${WS}/tests" || -e "${WS}/global-config.json" ]]; then
  fail "Skript-/Test-/Config-Dateien des Ordners in den Workspace installiert"
else
  ok "setup.sh, tests und global-config.json bleiben aus dem Workspace fern"
fi
if [[ -f "${TARGET_HOME}/.config/opencode/opencode.json" ]]; then
  ok "globale Config aus global-*.json der Ordnerauflösung installiert"
else
  fail "globale Config fehlt (Quelldatei wurde nicht aus dem Ordner bestimmt)"
fi
n_top="$(listing_calls "/contents/Linux/opencode?ref=")"
n_agents="$(listing_calls "/contents/Linux/opencode/agents?ref=")"
n_all="$(listing_calls "/contents/")"
CURL_LOG_FILE=""
if [[ "${n_top}" == "1" && "${n_agents}" == "1" && "${n_all}" == "2" ]]; then
  ok "genau ein Contents-API-Listing pro Ordner pro Lauf (top=1, agents=1)"
else
  fail "unerwartete Anzahl Listings: top=${n_top}, agents=${n_agents}, gesamt=${n_all}"
fi

# ---------------------------------------------------------------------------
# 7) Globale Config ohne Workspace (4b unabhängig von 4a, ein Listing)
# ---------------------------------------------------------------------------
printf '\nTest 7: globale Config ohne Workspace\n'
WORKSPACE_DIR=""
TARGET_HOME="${WORK}/home_only"
mkdir -p "${TARGET_HOME}"
use_fixtures pretty
reset_dir_cache
CURL_LOG_FILE="${WORK}/calls_4b.txt"
: > "${CURL_LOG_FILE}"
out="$( ( set -euo pipefail; eval "${block4b}" ) 2>&1 )"
status=$?
if [[ "${status}" -ne 0 ]]; then
  fail "4b bricht hart ab (exit=${status}):\n${out}"
fi
if [[ -f "${TARGET_HOME}/.config/opencode/opencode.json" ]]; then
  ok "globale Config installiert, obwohl kein Workspace existiert"
else
  fail "globale Config fehlt"
fi
n_top="$(listing_calls "/contents/Linux/opencode?ref=")"
n_agents="$(listing_calls "/contents/Linux/opencode/agents?ref=")"
CURL_LOG_FILE=""
if [[ "${n_top}" == "1" && "${n_agents}" == "0" ]]; then
  ok "4b allein: ein Listing, kein zusätzliches Agent-Listing"
else
  fail "unerwartete Anzahl Listings: top=${n_top}, agents=${n_agents}"
fi

# ---------------------------------------------------------------------------
# 8) Globale Config: Ordner enthält keine global-*.json -> weicher Hinweis
# ---------------------------------------------------------------------------
printf '\nTest 8: keine global-*.json in der Ordnerauflösung\n'
TARGET_HOME="${WORK}/home_no_global"
mkdir -p "${TARGET_HOME}"
FIXTURE="${WORK}/fixture_dir_no_global.json"
FIXTURE_AGENTS="${WORK}/fixture_pretty.json"
reset_dir_cache
out="$( ( set -euo pipefail; eval "${block4b}" ) 2>&1 )"
status=$?
if [[ "${status}" -eq 0 && "${out}" == *HINWEIS* && ! -e "${TARGET_HOME}/.config/opencode/opencode.json" ]]; then
  ok "kein harter Abbruch, Hinweis ausgegeben, nichts installiert"
else
  fail "exit=${status}, Ausgabe:\n${out}"
fi

# ---------------------------------------------------------------------------
# 9) Globale Config: Auflistung schlägt fehl -> weicher Hinweis
# ---------------------------------------------------------------------------
printf '\nTest 9: fehlgeschlagene Auflistung der globalen Config\n'
TARGET_HOME="${WORK}/home_list_fail"
mkdir -p "${TARGET_HOME}"
reset_dir_cache
CURL_FAIL=1
out="$( ( set -euo pipefail; eval "${block4b}" ) 2>&1 )"
status=$?
CURL_FAIL=0
if [[ "${status}" -eq 0 && "${out}" == *HINWEIS* && ! -e "${TARGET_HOME}/.config/opencode/opencode.json" ]]; then
  ok "kein harter Abbruch, Hinweis ausgegeben, nichts installiert"
else
  fail "exit=${status}, Ausgabe:\n${out}"
fi

# ---------------------------------------------------------------------------
# 10) Keine einzeln aufgeführten Agent-Namen
# ---------------------------------------------------------------------------
printf '\nTest 10: keine hartcodierten Agent-Namen\n'
hardcoded="$(grep -nE 'agents/[A-Za-z0-9_-]+\.md' "${SETUP_SH}" | head -1)"
if [[ -n "${hardcoded}" ]]; then
  fail "setup.sh enthält einen hartcodierten Agent-Namen: ${hardcoded}"
else
  ok "Agent-Dateien werden nicht einzeln aufgeführt"
fi

# ---------------------------------------------------------------------------
# 11) Keine festen Dateipfade mehr (auch nicht für die globale Config)
# ---------------------------------------------------------------------------
printf '\nTest 11: keine festen Dateipfade in setup.sh\n'
hardcoded_paths="$(grep -vE '^[[:space:]]*#' "${SETUP_SH}" \
  | grep -nE 'Linux/opencode/[A-Za-z0-9_.-]+\.(md|json)' || true)"
if [[ -n "${hardcoded_paths}" ]]; then
  fail "setup.sh enthält feste Dateipfade (Kommentare ausgenommen):
${hardcoded_paths}"
else
  ok "keine einzelne Datei aus Linux/opencode wird über einen festen Pfad angesprochen"
fi
n_wsf="$(grep -c 'WORKSPACE_FILES' "${SETUP_SH}" || true)"
if [[ "${n_wsf}" != "0" ]]; then
  fail "feste Dateiliste WORKSPACE_FILES existiert noch (${n_wsf} Treffer)"
else
  ok "WORKSPACE_FILES ist ersatzlos entfernt"
fi

# ---------------------------------------------------------------------------
# 12) Fallback-Pipeline unter set -euo pipefail, wenn nichts passt
#     (grep exit 1; ohne "|| true" bricht das Skript hart ab)
# ---------------------------------------------------------------------------
printf '\nTest 12: Fallback ohne Treffer unter set -euo pipefail\n'
NO_JQ=1
for fixture in fixture_only_dirs.json fixture_empty.json; do
  FIXTURE="${WORK}/${fixture}"
  FIXTURE_AGENTS="${WORK}/${fixture}"
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
