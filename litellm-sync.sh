#!/usr/bin/env bash
# Holt die Modellliste vom LiteLLM-Proxy und trägt sie als Provider "litellm"
# in ~/.pi/agent/models.json ein. Andere Provider in der Datei bleiben erhalten.
# Der Key bleibt in litellm.env und wird von pi bei jedem Request daraus gelesen.
set -euo pipefail
DIR="$HOME/.pi/agent"
ENV_FILE="$DIR/litellm.env"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "Fehlt: $cmd (brew install $cmd)" >&2; exit 1; }
done
[[ -f "$ENV_FILE" ]] || { echo "Fehlt: $ENV_FILE – zuerst ./install.sh ausführen." >&2; exit 1; }
. "$ENV_FILE"
BASE="${LITELLM_BASE_URL%/}"; BASE="${BASE%/v1}"
[[ "$LITELLM_API_KEY" == HIER-* || "$BASE" == *HIER-* ]] && { echo "Bitte zuerst $ENV_FILE ausfüllen." >&2; exit 1; }

AUTH="Authorization: Bearer $LITELLM_API_KEY"
# /model/info liefert (falls gepflegt) Kontextgröße, Vision, Reasoning; Fallback auf /v1/models
if INFO=$(curl -fsS -H "$AUTH" "$BASE/model/info" 2>/dev/null) && [[ $(jq '.data | length' <<<"$INFO") -gt 0 ]]; then
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
  MODELS=$(curl -fsS -H "$AUTH" "$BASE/v1/models" | jq '[.data[] | {id: .id, name: (.id + " (LiteLLM)")}]')
fi

EXISTING='{}'
if [[ -f "$DIR/models.json" ]]; then
  cp "$DIR/models.json" "$DIR/models.json.bak"
  EXISTING=$(cat "$DIR/models.json")
fi
jq --arg url "$BASE/v1" --argjson models "$MODELS" '.providers.litellm = {
    baseUrl: $url,
    api: "openai-completions",
    apiKey: "!. \"$HOME/.pi/agent/litellm.env\" && printf %s \"$LITELLM_API_KEY\"",
    models: $models
  }' <<<"$EXISTING" > "$DIR/models.json.tmp"
mv "$DIR/models.json.tmp" "$DIR/models.json"

echo "models.json aktualisiert mit $(jq length <<<"$MODELS") Modellen:"
jq -r '.[].id' <<<"$MODELS" | sed 's/^/  - litellm\//'
