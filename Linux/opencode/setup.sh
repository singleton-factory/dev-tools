#!/usr/bin/env bash
#
# setup-opencode.sh
#
# Wird während dem Docker-Build-Prozess durch
#     curl -fsSL <diese-URL> | bash
#   ausgeführt. Installiert opencode und lädt die opencode-Konfiguration
#   sowie AGENTS.md von GitHub herunter.
#
# Hinweis: Parameterübergabe ist nicht möglich, daher sind die URLs unten
# fest hinterlegt. Bei Änderungen diese Datei im Repository anpassen.
set -euo pipefail

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

# GitHub-Repo (raw.githubusercontent.com/<owner>/<name>/<ref>/<pfad>)
REPO_OWNER="singleton-factory"
REPO_NAME="dev-tools"
REPO_REF="main"
OPENCODE_CONFIG_PATH="Linux/opencode/config.json"
AGENTS_MD_PATH="Linux/opencode/AGENTS.md"

RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_REF}"
CONFIG_URL="${RAW_BASE}/${OPENCODE_CONFIG_PATH}"
AGENTS_URL="${RAW_BASE}/${AGENTS_MD_PATH}"

OPENCODE_INSTALL_URL="https://opencode.ai/install"

# Ziel-User und Pfade (Standard: vscode-User, wie im devcontainer)
if id -u vscode >/dev/null 2>&1; then
  TARGET_USER="vscode"
else
  TARGET_USER="$(id -un)"
fi
TARGET_HOME="${TARGET_USER_HOME:-/home/${TARGET_USER}}"
OPENCODE_CONFIG_DIR="${TARGET_HOME}/.config/opencode"

# Workspace-Verzeichnis ermitteln:
#   1. WORKSPACE_DIR-Umgebungsvariable (wenn gesetzt)
#   2. VSCODE_FOLDER_URI (steht in postCreateCommand zur Verfügung)
#   3. /workspace (Standard-Mount)
#   4. erstes Subverzeichnis von /workspaces (Muster /workspaces/<Projektname>)
#   5. sonst leere Variable -> AGENTS.md-Download wird übersprungen
resolve_workspace_dir() {
  if [[ -n "${WORKSPACE_DIR:-}" && -d "${WORKSPACE_DIR}" ]]; then
    printf '%s' "${WORKSPACE_DIR}"
    return
  fi
  if [[ -n "${VSCODE_FOLDER_URI:-}" ]]; then
    local path="${VSCODE_FOLDER_URI#file://}"
    path="${path%%\?*}"
    if [[ -d "${path}" ]]; then
      printf '%s' "${path}"
      return
    fi
  fi
  if [[ -d /workspace ]]; then
    printf '%s' /workspace
    return
  fi
  local dir
  for dir in /workspaces/*/; do
    [[ -d "${dir}" ]] || continue
    printf '%s' "$(dirname "${dir}")"
    return
  done
  printf ''
}
WORKSPACE_DIR="$(resolve_workspace_dir)"

# ---------------------------------------------------------------------------
# Helfer
# ---------------------------------------------------------------------------

log() { printf '[setup-opencode] %s\n' "$*"; }

download() {
  local url="$1"
  local dest="$2"
  log "GET ${url}"
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "${dest}" "${url}"; then
    log "FEHLER: Download von ${url} fehlgeschlagen"
    exit 1
  fi
  if [[ ! -s "${dest}" ]]; then
    log "FEHLER: Download von ${url} ist leer"
    exit 1
  fi
}

# Datei installieren und owner auf TARGET_USER setzen (je nach aktuellem User)
install_as() {
  local src="$1"
  local dest="$2"
  if [[ "$(id -un)" == "root" ]]; then
    install -m 0644 -o "${TARGET_USER}" -g "${TARGET_USER}" "${src}" "${dest}"
  else
    install -m 0644 "${src}" "${dest}"
  fi
}

# ---------------------------------------------------------------------------
# 1) opencode installieren (überspringen, falls bereits vorhanden)
# ---------------------------------------------------------------------------
OPENCODE_BIN="${TARGET_HOME}/.opencode/bin/opencode"
if [[ "$(id -un)" == "root" && "$(id -un)" != "${TARGET_USER}" ]]; then
  HAVE_OPENCODE="$(su -s /bin/bash "${TARGET_USER}" -c "test -x '${OPENCODE_BIN}' && echo yes" || true)"
else
  HAVE_OPENCODE="$(test -x "${OPENCODE_BIN}" && echo yes || true)"
fi
if [[ "${HAVE_OPENCODE}" == "yes" ]]; then
  log "opencode ist bereits installiert (${OPENCODE_BIN}), Installation übersprungen"
else
  log "Installiere opencode für '${TARGET_USER}' ..."
  if [[ "$(id -un)" == "${TARGET_USER}" ]]; then
    curl -fsSL "${OPENCODE_INSTALL_URL}" | bash
  else
    su -s /bin/bash "${TARGET_USER}" -c "curl -fsSL ${OPENCODE_INSTALL_URL} | bash"
  fi
fi

# PATH sicherstellen (opencode-Installer erkennt Shell-Config bei curl|bash
# manchmal nicht – wir ergänzen den Eintrag daher explizit)
OPENCODE_BIN_DIR="${TARGET_HOME}/.opencode/bin"
for rc_file in "${TARGET_HOME}/.bashrc" "${TARGET_HOME}/.profile"; do
  if [[ -f "${rc_file}" ]] && ! grep -qF "${OPENCODE_BIN_DIR}" "${rc_file}"; then
    {
      echo ""
      echo "opencode"
      echo "export PATH=\"${OPENCODE_BIN_DIR}:\$PATH\""
    } >> "${rc_file}"
    log "PATH-Eintrag für ${OPENCODE_BIN_DIR} in ${rc_file} ergänzt"
    break
  fi
done

# ---------------------------------------------------------------------------
# 2) opencode-Konfiguration herunterladen
# ---------------------------------------------------------------------------
mkdir -p "${OPENCODE_CONFIG_DIR}"
if [[ "$(id -un)" == "root" ]]; then
  chown "${TARGET_USER}:${TARGET_USER}" "${OPENCODE_CONFIG_DIR}"
fi
tmp_config="$(mktemp)"
trap 'rm -f "${tmp_config}"' EXIT
download "${CONFIG_URL}" "${tmp_config}"
install_as "${tmp_config}" "${OPENCODE_CONFIG_DIR}/opencode.json"
log "Konfiguration nach ${OPENCODE_CONFIG_DIR}/opencode.json installiert"

# ---------------------------------------------------------------------------
# 3) AGENTS.md herunterladen (optional – schlägt nicht hart fehl,
#    wird NIEMALS überschrieben)
# ---------------------------------------------------------------------------
AGENTS_DEST="${WORKSPACE_DIR}/AGENTS.md"
if [[ ! -d "${WORKSPACE_DIR}" ]]; then
  log "HINWEIS: ${WORKSPACE_DIR} existiert nicht, AGENTS.md-Download übersprungen"
elif [[ -e "${AGENTS_DEST}" ]]; then
  log "AGENTS.md existiert bereits (${AGENTS_DEST}), Download übersprungen"
else
  tmp_agents="$(mktemp)"
  trap 'rm -f "${tmp_config}" "${tmp_agents}"' EXIT
  if ! download "${AGENTS_URL}" "${tmp_agents}"; then
    log "WARNUNG: AGENTS.md-Download fehlgeschlagen (weiterhin ohne Fehler)"
  elif [[ -w "${WORKSPACE_DIR}" ]]; then
    install_as "${tmp_agents}" "${WORKSPACE_DIR}/AGENTS.md" \
      && log "AGENTS.md nach ${WORKSPACE_DIR}/AGENTS.md installiert" \
      || log "WARNUNG: AGENTS.md konnte nicht installiert werden (weiterhin ohne Fehler)"
  elif command -v sudo >/dev/null 2>&1; then
    log "${WORKSPACE_DIR} nicht schreibbar, versuche mit sudo ..."
    SUDO="$(command -v sudo)"
    if "$SUDO" install -m 0644 -o "${TARGET_USER}" -g "${TARGET_USER}" \
       "${tmp_agents}" "${WORKSPACE_DIR}/AGENTS.md" 2>/dev/null; then
      log "AGENTS.md (via sudo) nach ${WORKSPACE_DIR}/AGENTS.md installiert"
    else
      log "WARNUNG: AGENTS.md konnte nicht installiert werden, auch nicht mit sudo"
    fi
  else
    log "HINWEIS: ${WORKSPACE_DIR} nicht schreibbar und sudo nicht verfügbar, AGENTS.md übersprungen"
  fi
fi

log "Fertig."
