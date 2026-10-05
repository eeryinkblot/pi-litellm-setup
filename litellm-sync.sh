#!/usr/bin/env bash
# Holt die Modellliste vom LiteLLM-Proxy und trägt sie als Provider "litellm"
# in <agent-dir>/models.json ein. Andere Provider in der Datei bleiben erhalten.
# Der Key bleibt in litellm.env und wird von pi bei jedem Request daraus gelesen.
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

EXISTING='{}'
if [[ -f "$AGENT_DIR/models.json" ]]; then
  cp "$AGENT_DIR/models.json" "$AGENT_DIR/models.json.bak"
  EXISTING=$(cat "$AGENT_DIR/models.json")
fi
# pi führt den apiKey-Befehl in Bash aus (unter Windows: Git Bash), daher absoluter Unix-Pfad
API_KEY_CMD="!eval \"\$(tr -d '\\r' < '$ENV_FILE')\" && printf %s \"\$LITELLM_API_KEY\""
jq --arg url "$BASE/v1" --arg key "$API_KEY_CMD" --argjson models "$MODELS" '.providers.litellm = {
    baseUrl: $url,
    api: "openai-completions",
    apiKey: $key,
    models: $models
  }' <<<"$EXISTING" > "$AGENT_DIR/models.json.tmp"
mv "$AGENT_DIR/models.json.tmp" "$AGENT_DIR/models.json"

echo "models.json aktualisiert mit $(jq length <<<"$MODELS" | tr -d '\r') Modellen:"
jq -r '.[].id' <<<"$MODELS" | tr -d '\r' | sed 's/^/  - litellm\//'
