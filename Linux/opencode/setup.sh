#!/usr/bin/env bash
#
# setup-opencode.sh
#
# Wird während dem Docker-Build-Prozess und als devcontainer-postCreateCommand
# durch
#     curl -fsSL <diese-URL> | bash
#   ausgeführt. Installiert opencode v2, entfernt alle anderen vorhandenen
#   opencode-Versionen (z. B. v1) und legt im Projekt-Workspace die
#   Template-Dateien aus dem Ordner Linux/opencode an (AGENTS.md,
#   config.json -> opencode.json, agents/*.md -> .opencode/agents/*.md;
#   vorhandene Dateien werden NIEMALS überschrieben). Wird das Skript als
#   postCreateCommand ausgeführt (erkannt an VSCODE_*-Umgebungsvariablen),
#   startet es am Ende zusätzlich das opencode service.
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

RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_REF}"
# v2-Installer (installiert die Version aus dem v2-Channel, z. B. 2.0.x;
# der v1-Installer würde weiterhin nur die letzten v1-Releases liefern)
OPENCODE_INSTALL_URL="https://opencode.ai/v2/install"

# Template-Dateien, die aus Linux/opencode in den Projekt-Workspace kopiert
# werden (Format: "<Quellpfad im Repo>|<Zielpfad relativ zum Workspace>"):
WORKSPACE_FILES=(
  "Linux/opencode/AGENTS.md|AGENTS.md"
  "Linux/opencode/config.json|opencode.json"
  "Linux/opencode/agents/explorer.md|.opencode/agents/explorer.md"
  "Linux/opencode/agents/verifier.md|.opencode/agents/verifier.md"
  "Linux/opencode/agents/reviewer.md|.opencode/agents/reviewer.md"
)

# Ziel-User und Pfade (Standard: vscode-User, wie im devcontainer)
if id -u vscode >/dev/null 2>&1; then
  TARGET_USER="vscode"
else
  TARGET_USER="$(id -un)"
fi
TARGET_HOME="${TARGET_USER_HOME:-/home/${TARGET_USER}}"

# Workspace-Verzeichnis ermitteln:
#   1. WORKSPACE_DIR-Umgebungsvariable (wenn gesetzt)
#   2. erstes Subverzeichnis von /workspaces (Muster /workspaces/<Projektname>)
#   3. VSCODE_FOLDER_URI (steht in postCreateCommand zur Verfügung,
#      /workspace wird explizit ausgeschlossen)
#   4. sonst leere Variable -> Workspace-Installation wird übersprungen
resolve_workspace_dir() {
  if [[ -n "${WORKSPACE_DIR:-}" && -d "${WORKSPACE_DIR}" ]]; then
    printf '%s' "${WORKSPACE_DIR}"
    return
  fi
  local dir
  for dir in /workspaces/*/; do
    [[ -d "${dir}" ]] || continue
    printf '%s' "${dir%/}"
    return
  done
  if [[ -n "${VSCODE_FOLDER_URI:-}" ]]; then
    local path="${VSCODE_FOLDER_URI#file://}"
    path="${path%%\?*}"
    if [[ -d "${path}" && "${path}" != /workspace ]]; then
      printf '%s' "${path}"
      return
    fi
  fi
  printf ''
}
WORKSPACE_DIR="$(resolve_workspace_dir)"

# ---------------------------------------------------------------------------
# Helfer
# ---------------------------------------------------------------------------

log() { printf '[setup-opencode] %s\n' "$*"; }

# Datei herunterladen; schlägt weich fehl (return 1), da alle
# Workspace-Downloads optional sind
download() {
  local url="$1"
  local dest="$2"
  log "GET ${url}"
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "${dest}" "${url}"; then
    log "WARNUNG: Download von ${url} fehlgeschlagen"
    rm -f "${dest}"
    return 1
  fi
  if [[ ! -s "${dest}" ]]; then
    log "WARNUNG: Download von ${url} ist leer"
    rm -f "${dest}"
    return 1
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

# Eine Template-Datei aus Linux/opencode in den Workspace legen; schlägt
# nicht hart fehl und wird NIEMALS überschrieben
deploy_workspace_file() {
  local src="$1"
  local rel="$2"
  local dest="${WORKSPACE_DIR}/${rel}"
  local destdir tmp writable
  destdir="$(dirname "${dest}")"

  if [[ -e "${dest}" ]]; then
    log "${rel} existiert bereits (${dest}), Download übersprungen"
    return 0
  fi

  if ! tmp="$(mktemp)"; then
    log "WARNUNG: mktemp fehlgeschlagen, ${rel} übersprungen"
    return 0
  fi
  if ! download "${RAW_BASE}/${src}" "${tmp}"; then
    rm -f "${tmp}"
    return 0
  fi

  writable=0
  if [[ -d "${destdir}" ]]; then
    if [[ -w "${destdir}" ]]; then
      writable=1
    fi
  else
    if mkdir -p "${destdir}" 2>/dev/null; then
      writable=1
    fi
  fi

  if [[ "${writable}" -eq 1 ]]; then
    if install_as "${tmp}" "${dest}"; then
      log "${rel} nach ${dest} installiert"
    else
      log "WARNUNG: ${rel} konnte nicht installiert werden (weiterhin ohne Fehler)"
    fi
  elif command -v sudo >/dev/null 2>&1; then
    log "${destdir} nicht schreibbar, versuche mit sudo ..."
    local sudo_bin
    sudo_bin="$(command -v sudo)"
    if { [[ -d "${destdir}" ]] || \
         "${sudo_bin}" install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_USER}" \
           "${destdir}" 2>/dev/null; } && \
       "${sudo_bin}" install -m 0644 -o "${TARGET_USER}" -g "${TARGET_USER}" \
         "${tmp}" "${dest}" 2>/dev/null; then
      log "${rel} (via sudo) nach ${dest} installiert"
    else
      log "WARNUNG: ${rel} konnte nicht installiert werden, auch nicht mit sudo"
    fi
  else
    log "HINWEIS: ${destdir} nicht schreibbar und sudo nicht verfügbar, ${rel} übersprungen"
  fi
  rm -f "${tmp}"
  return 0
}

# ---------------------------------------------------------------------------
# 1) opencode v2 installieren (überspringen, falls v2 bereits vorhanden;
#    ältere Versionen, z. B. v1, werden durch den v2-Installer ersetzt,
#    da dieser das Binär in $HOME/.opencode/bin überschreibt)
# ---------------------------------------------------------------------------
OPENCODE_BIN="${TARGET_HOME}/.opencode/bin/opencode"
if [[ "$(id -un)" == "root" && "$(id -un)" != "${TARGET_USER}" ]]; then
  OPENCODE_VERSION="$(su -s /bin/bash "${TARGET_USER}" -c "'${OPENCODE_BIN}' --version" 2>/dev/null || true)"
else
  OPENCODE_VERSION="$("${OPENCODE_BIN}" --version 2>/dev/null || true)"
fi
# Letztes Wort (Versionsnummer) herausnehmen und evtl. führendes 'v' entfernen,
# z. B. "opencode v2.0.23" -> "2.0.23"
OPENCODE_VERSION="${OPENCODE_VERSION##* }"
OPENCODE_VERSION="${OPENCODE_VERSION#v}"
if [[ "${OPENCODE_VERSION}" == 2.* ]]; then
  log "opencode v${OPENCODE_VERSION} ist bereits installiert (${OPENCODE_BIN}), Installation übersprungen"
else
  if [[ -n "${OPENCODE_VERSION}" ]]; then
    log "opencode v${OPENCODE_VERSION} vorhanden, installiere v2 für '${TARGET_USER}' ..."
  else
    log "Installiere opencode v2 für '${TARGET_USER}' ..."
  fi
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
      echo "# opencode"
      echo "export PATH=\"${OPENCODE_BIN_DIR}:\$PATH\""
    } >> "${rc_file}"
    log "PATH-Eintrag für ${OPENCODE_BIN_DIR} in ${rc_file} ergänzt"
    break
  fi
done

# ---------------------------------------------------------------------------
# 2) Alle vorhandenen opencode-Versionen außer der aktuellen v2 (in
#    ${OPENCODE_BIN}) deinstallieren (z. B. v1 oder ältere Instanzen, die
#    über npm global, /usr/local/bin, ~/.local/bin, ... installiert wurden)
# ---------------------------------------------------------------------------

# Prüfen, ob ein Pfad ein ausführbares opencode-Binary ist (gleiches Muster
# wie der v2-Installer: '--version' ausführen und die Ausgabe auswerten)
is_opencode_binary() {
  local bin="$1" out
  [[ -f "${bin}" && -x "${bin}" ]] || return 1
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 10 "${bin}" --version 2>/dev/null || true)"
  else
    out="$("${bin}" --version 2>/dev/null || true)"
  fi
  [[ "${out}" == *opencode* ]] && return 0
  [[ "${out}" =~ ^v?[0-9]+\.[0-9]+ ]] && return 0
  return 1
}

# Alle opencode-Installationen finden, die NICHT die aktuelle v2
# (${OPENCODE_BIN}) sind; gibt deren echte Pfade aus, je einer pro Zeile
find_stale_opencode() {
  local canonical
  canonical="$(readlink -f "${OPENCODE_BIN}" 2>/dev/null || printf '%s' "${OPENCODE_BIN}")"

  local candidates=()
  local line found
  # alle 'opencode' auf dem PATH des Ziel-Users (Login-Shell)
  if [[ "$(id -un)" == "root" && "$(id -un)" != "${TARGET_USER}" ]]; then
    found="$(su - -s /bin/bash "${TARGET_USER}" -c 'type -a opencode 2>/dev/null' || true)"
  else
    found="$(type -a opencode 2>/dev/null || true)"
  fi
  while IFS= read -r line; do
    line="${line#*is }"
    [[ "${line}" == /* && -e "${line}" ]] || continue
    candidates+=("${line}")
  done <<< "${found}"

  # übliche feste Installationsorte
  candidates+=(
    "${OPENCODE_BIN}"
    "${TARGET_HOME}/.local/bin/opencode"
    "${TARGET_HOME}/.bun/bin/opencode"
    "/usr/local/bin/opencode"
    "/usr/bin/opencode"
  )
  # npm-Globalinstallation (z. B. v1 via 'npm install -g opencode-ai')
  local npm_prefix
  npm_prefix="$(npm prefix -g 2>/dev/null || true)"
  if [[ -n "${npm_prefix}" ]]; then
    candidates+=("${npm_prefix}/bin/opencode")
  fi

  local path real_path seen=" "
  for path in "${candidates[@]}"; do
    [[ -e "${path}" ]] || continue
    real_path="$(readlink -f "${path}" 2>/dev/null || printf '%s' "${path}")"
    [[ -f "${real_path}" ]] || continue
    # die aktuelle v2-Installation behalten
    [[ "${real_path}" == "${canonical}" ]] && continue
    [[ "${seen}" == *" ${real_path} "* ]] && continue
    is_opencode_binary "${real_path}" || continue
    seen+=" ${real_path} "
    printf '%s\n' "${real_path}"
  done
  return 0
}

# Eine erkannte Installation entfernen (bei npm-Globalinstallationen das
# gesamte Paket-Verzeichnis); schlägt weich fehl (Warnung)
remove_stale_opencode() {
  local path="$1"
  local targets=("${path}")
  local npm_prefix pkg target ok binlink binlink_target
  npm_prefix="$(npm prefix -g 2>/dev/null || true)"
  if [[ -n "${npm_prefix}" && "${path}" == "${npm_prefix}"/lib/node_modules/* ]]; then
    # .../lib/node_modules/<paket>/<rest> -> .../lib/node_modules/<paket>
    pkg="${path#"${npm_prefix}"/lib/node_modules/}"
    pkg="${npm_prefix}/lib/node_modules/${pkg%%/*}"
    [[ "${pkg}" == "${path}" ]] || targets+=("${pkg}")
    # zugehörige Bin-Link im npm-Prefix entfernen
    binlink="${npm_prefix}/bin/opencode"
    if [[ "${binlink}" != "${path}" && -e "${binlink}" ]]; then
      binlink_target="$(readlink -f "${binlink}" 2>/dev/null || true)"
      [[ "${binlink_target}" == "${pkg}"/* ]] && targets+=("${binlink}")
    fi
  fi

  ok=1
  for target in "${targets[@]}"; do
    if [[ "$(id -un)" == "root" || -w "$(dirname "${target}")" ]]; then
      rm -rf -- "${target}" || ok=0
    elif command -v sudo >/dev/null 2>&1; then
      local sudo_bin
      sudo_bin="$(command -v sudo)"
      "${sudo_bin}" rm -rf -- "${target}" 2>/dev/null || ok=0
    else
      ok=0
    fi
  done
  if [[ "${ok}" -eq 1 ]]; then
    log "veraltete opencode-Installation entfernt: ${path}"
  else
    log "WARNUNG: ${path} konnte nicht entfernt werden"
  fi
  return 0
}

STALE_OPENCODES="$(find_stale_opencode)"
if [[ -n "${STALE_OPENCODES}" ]]; then
  while IFS= read -r STALE_PATH; do
    [[ -n "${STALE_PATH}" ]] || continue
    remove_stale_opencode "${STALE_PATH}"
  done <<< "${STALE_OPENCODES}"
else
  log "keine weiteren opencode-Installationen gefunden"
fi

# ---------------------------------------------------------------------------
# 3) Projekt-Dateien in den Workspace legen (optional – schlägt nicht hart
#    fehl, wird NIEMALS überschrieben)
# ---------------------------------------------------------------------------
if [[ -z "${WORKSPACE_DIR}" || ! -d "${WORKSPACE_DIR}" ]]; then
  log "HINWEIS: kein Workspace-Verzeichnis gefunden, Workspace-Installation übersprungen"
else
  log "Workspace: ${WORKSPACE_DIR}"
  for entry in "${WORKSPACE_FILES[@]}"; do
    deploy_workspace_file "${entry%%|*}" "${entry#*|}"
  done
fi

# ---------------------------------------------------------------------------
# 4) opencode service starten (nur im postCreate-Fall; devcontainer setzt in
#    der postCreateCommand VSCODE_*-Umgebungsvariablen, während dem
#    Docker-Build fehlen diese)
# ---------------------------------------------------------------------------
if env | grep -q '^VSCODE_'; then
  log "postCreate erkannt, starte opencode service ..."
  if [[ "$(id -un)" == "root" && "$(id -un)" != "${TARGET_USER}" ]]; then
    su -s /bin/bash "${TARGET_USER}" -c "nohup '${OPENCODE_BIN}' service start >/dev/null 2>&1 &" || \
      log "WARNUNG: opencode service konnte nicht gestartet werden"
  else
    nohup "${OPENCODE_BIN}" service start >/dev/null 2>&1 &
  fi
else
  log "kein postCreate erkannt, opencode service wird nicht gestartet"
fi

log "Fertig."
