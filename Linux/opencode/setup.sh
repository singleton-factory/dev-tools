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
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"

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
# 1) opencode installieren
# ---------------------------------------------------------------------------
log "Installiere opencode für '${TARGET_USER}' ..."
if [[ "$(id -un)" == "${TARGET_USER}" ]]; then
  curl -fsSL "${OPENCODE_INSTALL_URL}" | bash
else
  su -s /bin/bash "${TARGET_USER}" -c "curl -fsSL ${OPENCODE_INSTALL_URL} | bash"
fi

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
# 3) AGENTS.md herunterladen
# ---------------------------------------------------------------------------
if [[ -d "${WORKSPACE_DIR}" ]]; then
  tmp_agents="$(mktemp)"
  trap 'rm -f "${tmp_config}" "${tmp_agents}"' EXIT
  download "${AGENTS_URL}" "${tmp_agents}"
  install_as "${tmp_agents}" "${WORKSPACE_DIR}/AGENTS.md"
  log "AGENTS.md nach ${WORKSPACE_DIR}/AGENTS.md installiert"
else
  log "HINWEIS: ${WORKSPACE_DIR} existiert nicht, AGENTS.md-Download übersprungen"
fi

log "Fertig."