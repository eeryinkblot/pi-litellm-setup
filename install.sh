#!/usr/bin/env bash
# Einrichtung von pi mit dem LiteLLM-Gateway. Kann gefahrlos mehrfach ausgeführt werden.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$HOME/.pi/agent"
ENV_FILE="$DIR/litellm.env"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

step "Voraussetzungen prüfen"
if command -v brew >/dev/null; then
  for pkg in jq; do command -v "$pkg" >/dev/null || brew install "$pkg"; done
  command -v pi >/dev/null || brew install pi-coding-agent
else
  command -v jq >/dev/null || { echo "Bitte jq installieren." >&2; exit 1; }
  command -v pi >/dev/null || { echo "Bitte pi installieren: npm install -g @earendil-works/pi-coding-agent" >&2; exit 1; }
fi
echo "pi $(pi --version)"

step "Sync-Skript verlinken"
mkdir -p "$DIR"
ln -sf "$REPO/litellm-sync.sh" "$DIR/litellm-sync.sh"
echo "$DIR/litellm-sync.sh -> $REPO/litellm-sync.sh"

step "Zugangsdaten"
if [[ -f "$ENV_FILE" ]] && ! grep -q 'HIER-KEY-EINTRAGEN' "$ENV_FILE"; then
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
MSG
