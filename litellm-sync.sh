#!/usr/bin/env bash
# Holt die Modellliste vom LiteLLM-Proxy und trägt sie als Provider "litellm"
# in <agent-dir>/models.json ein. Andere Provider in der Datei bleiben erhalten.
# Den Key aus litellm.env trägt es in <agent-dir>/auth.json ein, wo pi ihn direkt liest.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "Fehlt: $cmd – zuerst ./install.sh ausführen." >&2; exit 1; }
done
[[ -f "$ENV_FILE" ]] || { echo "Fehlt: $ENV_FILE – zuerst ./install.sh ausführen." >&2; exit 1; }
load_env
BASE="${LITELLM_BASE_URL%/}"; BASE="${BASE%/v1}"
# Ohne Schema würde curl http:// annehmen und das Gateway nicht antworten
[[ "$BASE" == http://* || "$BASE" == https://* ]] || BASE="https://$BASE"
[[ "$LITELLM_API_KEY" == HIER-* || "$BASE" == *HIER-* ]] && { echo "Bitte zuerst $ENV_FILE ausfüllen." >&2; exit 1; }

AUTH="Authorization: Bearer $LITELLM_API_KEY"
# Timeouts, damit ein nicht erreichbares oder träges Gateway nicht endlos hängt
CURL=(curl -fsS --connect-timeout 10 --max-time 30 -H "$AUTH")
echo "Hole Modelle von $BASE ..."
# /model/info liefert (falls gepflegt) Kontextgröße, Vision, Reasoning; Fallback auf /v1/models
if INFO=$("${CURL[@]}" "$BASE/model/info" 2>/dev/null </dev/null) \
   && [[ $(jq '.data | length' <<<"$INFO" | tr -d '\r') -gt 0 ]]; then
  MODELS=$(jq '[.data | unique_by(.model_name)[] | {
      id: .model_name,
      name: (.model_name + " (LiteLLM)"),
      reasoning: (.model_info.supports_reasoning // false),
      input: (if .model_info.supports_vision then ["text","image"] else ["text"] end)
    }
    + (if .model_info.max_input_tokens then {contextWindow: .model_info.max_input_tokens} else {} end)
    + (if .model_info.max_output_tokens then {maxTokens: .model_info.max_output_tokens} else {} end)
  ]' <<<"$INFO")
else
  echo "/model/info nicht verfügbar, nutze /v1/models ..."
  MODELS=$("${CURL[@]}" "$BASE/v1/models" </dev/null | jq '[.data[] | {id: .id, name: (.id + " (LiteLLM)")}]')
fi

# JSON-Datei per jq-Filter ändern; andere Einträge bleiben erhalten, vorher wird ein .bak angelegt
update_json() {
  local file="$1"; shift
  local current='{}'
  if [[ -f "$file" ]]; then cp "$file" "$file.bak"; current=$(cat "$file"); fi
  ( umask 077; jq "$@" <<<"$current" > "$file.tmp" )
  mv "$file.tmp" "$file"
}

update_json "$AGENT_DIR/models.json" --arg url "$BASE/v1" --argjson models "$MODELS" '.providers.litellm = {
    baseUrl: $url,
    api: "openai-completions",
    models: $models
  }'

# Key direkt in pis Credential-Speicher: braucht keine Shell. Ein Shell-Befehl als apiKey
# scheitert unter Windows, wenn Git nicht unter Program Files liegt (pi ignoriert dafür shellPath).
# In auth.json steht "$" für Umgebungsvariablen, daher $ -> $$ und führendes ! -> $!
update_json "$AGENT_DIR/auth.json" --arg key "$LITELLM_API_KEY" '.litellm = {
    type: "api_key",
    key: ($key | gsub("\\$"; "$$") | if startswith("!") then "$" + . else . end)
  }'
chmod 600 "$AGENT_DIR/auth.json"

echo "models.json aktualisiert mit $(jq length <<<"$MODELS" | tr -d '\r') Modellen:"
jq -r '.[].id' <<<"$MODELS" | tr -d '\r' | sed 's/^/  - litellm\//'
