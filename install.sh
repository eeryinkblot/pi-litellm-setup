#!/usr/bin/env bash
# Einrichtung von pi mit dem LiteLLM-Gateway – Windows (Git Bash + Scoop), macOS (Homebrew), Linux (npm).
# Kann gefahrlos mehrfach ausgeführt werden.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO/lib.sh"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

step "Voraussetzungen prüfen ($OS)"
case $OS in
  windows)
    SCOOP_DIR="$(cygpath -u "${SCOOP:-$USERPROFILE\\scoop}")"
    export PATH="$SCOOP_DIR/shims:$PATH"
    scoop() { powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "scoop $*"; }
    if [[ ! -d "$SCOOP_DIR/shims" ]]; then
      echo "Scoop wird installiert …"
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
        "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Invoke-RestMethod get.scoop.sh | Invoke-Expression"
    fi
    command -v jq >/dev/null || scoop install jq
    command -v pi >/dev/null || scoop install pi-coding-agent
    ;;
  mac)
    command -v brew >/dev/null || { echo "Bitte Homebrew installieren: https://brew.sh" >&2; exit 1; }
    command -v jq >/dev/null || brew install jq
    command -v pi >/dev/null || brew install pi-coding-agent
    ;;
  linux)
    command -v jq >/dev/null || { echo "Bitte jq installieren (z. B. apt install jq)." >&2; exit 1; }
    command -v pi >/dev/null || npm install -g --ignore-scripts @earendil-works/pi-coding-agent
    ;;
esac
echo "pi $(pi --version | tr -d '\r')"
mkdir -p "$AGENT_DIR"

if [[ $OS == windows ]]; then
  step "Git Bash für pi festlegen"
  # pi sucht Git Bash nur unter Program Files; bei Git aus Scoop würde es sonst ggf. WSL-bash nehmen
  GIT_ROOT="$(cygpath -w /)"; BASH_EXE="${GIT_ROOT%\\}\\bin\\bash.exe"
  SETTINGS="$AGENT_DIR/settings.json"
  [[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
  if [[ -n "$(jq -r '.shellPath // empty' "$SETTINGS" | tr -d '\r')" ]]; then
    echo "shellPath ist bereits gesetzt – wird nicht verändert."
  elif [[ -f "$(cygpath -u "$BASH_EXE")" ]]; then
    jq --arg p "$BASH_EXE" '.shellPath = $p' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "shellPath = $BASH_EXE"
  else
    echo "Warnung: $BASH_EXE nicht gefunden – pi nutzt seine Standardsuche." >&2
  fi
fi

step "Sync-Befehl einrichten"
# Wrapper statt Symlink (Symlinks sind unter Git Bash unzuverlässig); rm zuerst, falls dort noch ein Symlink liegt
rm -f "$AGENT_DIR/litellm-sync.sh"
printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$REPO/litellm-sync.sh" > "$AGENT_DIR/litellm-sync.sh"
chmod 755 "$AGENT_DIR/litellm-sync.sh"
echo "$AGENT_DIR/litellm-sync.sh -> $REPO/litellm-sync.sh"

step "Zugangsdaten"
if [[ -f "$ENV_FILE" ]] && ! grep -q 'HIER-' "$ENV_FILE"; then
  echo "$ENV_FILE existiert bereits – wird nicht verändert."
else
  url=""
  while [[ -z "$url" ]]; do read -r -p "Gateway-URL (z. B. https://ai-gateway.example.com): " url; done
  read -r -s -p "LiteLLM API-Key (Eingabe unsichtbar): " key; echo
  [[ -n "$key" ]] || { echo "Kein Key eingegeben – abgebrochen." >&2; exit 1; }
  umask 077
  printf '# LiteLLM-Zugang für pi – erzeugt von install.sh\nLITELLM_BASE_URL=%q\nLITELLM_API_KEY=%q\n' \
    "$url" "$key" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Gespeichert in $ENV_FILE (nur für dich lesbar)."
fi

step "Modelle vom Gateway holen"
"$REPO/litellm-sync.sh"

step "Fertig"
cat <<'MSG'
pi starten, mit /model ein litellm/...-Modell wählen und mit Ctrl+S als Standard speichern.
Neue Modelle auf dem Gateway später übernehmen: ~/.pi/agent/litellm-sync.sh
Windows: Nach einer frischen Scoop-Installation ein neues Git-Bash-Fenster öffnen, damit "pi" im PATH ist.
MSG
