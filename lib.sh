# Gemeinsame Helfer für install.sh und litellm-sync.sh (wird per "source" geladen).
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  Darwin) OS=mac ;;
  *) OS=linux ;;
esac

# Windows-Pfade (C:\...) in Git-Bash-Pfade (/c/...) umwandeln
to_unix() { if [[ $OS == windows ]]; then cygpath -u "$1"; else printf '%s' "$1"; fi; }

# pi nutzt unter Windows %USERPROFILE%, nicht $HOME (das kann z. B. auf ein Netzlaufwerk zeigen)
if [[ -n "${PI_CODING_AGENT_DIR:-}" ]]; then
  AGENT_DIR="$(to_unix "$PI_CODING_AGENT_DIR")"
elif [[ $OS == windows ]]; then
  AGENT_DIR="$(cygpath -u "$USERPROFILE")/.pi/agent"
else
  AGENT_DIR="$HOME/.pi/agent"
fi
ENV_FILE="$AGENT_DIR/litellm.env"

# litellm.env laden; \r entfernen, falls die Datei mit einem Windows-Editor bearbeitet wurde
load_env() { eval "$(tr -d '\r' < "$ENV_FILE")"; }
