# pi + LiteLLM

Bindet den [pi Coding Agent](https://pi.dev) an unser LiteLLM-Gateway an, damit alle Gateway-Modelle direkt in pi auswählbar sind.

## Schnellstart

```bash
git clone <dieses-repo> && cd pi-litellm-setup
./install.sh
```

`install.sh` erledigt Folgendes:

1. Es installiert `pi` und `jq` über Homebrew, falls sie fehlen.
2. Es fragt nach der Gateway-URL und deinem LiteLLM-API-Key (die Eingabe ist unsichtbar) und speichert beides in `~/.pi/agent/litellm.env` (`chmod 600`).
3. Es holt die Modellliste vom Gateway und trägt sie in `~/.pi/agent/models.json` ein.

Danach `pi` starten, mit `/model` ein `litellm/...`-Modell wählen und mit `Ctrl+S` als Standard speichern.

## Neue Modelle übernehmen

Wenn auf dem Gateway Modelle dazukommen oder wegfallen:

```bash
~/.pi/agent/litellm-sync.sh
```

Andere Provider in deiner `models.json` bleiben dabei erhalten. Vor jeder Änderung wird `models.json.bak` angelegt.

## Wie es funktioniert

- Der Key steht ausschließlich in `~/.pi/agent/litellm.env`. In `models.json` steht nur ein Befehl, mit dem pi den Key bei jedem Request aus dieser Datei liest. Du musst also nichts in `~/.zshrc` eintragen.
- Das Gateway wird als OpenAI-kompatibler Endpunkt (`/v1`) angesprochen.
- Liefert das Gateway unter `/model/info` Metadaten (Kontextgröße, Vision, Reasoning), werden sie übernommen. Sonst nutzt pi seine Standardwerte (128K Kontext, 16K Ausgabe, keine Bilder, kein Thinking).

## Troubleshooting

| Problem | Lösung |
|---|---|
| `Could not resolve host` | URL in `~/.pi/agent/litellm.env` prüfen |
| `401` / `403` | Key in `~/.pi/agent/litellm.env` prüfen |
| Modelle fehlen in `/model` | `~/.pi/agent/litellm-sync.sh` ausführen, danach `/model` neu öffnen |
| Key ändern | `~/.pi/agent/litellm.env` bearbeiten. Ein Neustart von pi reicht. |

Prüfen ohne TUI:

```bash
pi --list-models litellm
pi -p --no-session --model 'litellm/<modell-id>' "Antworte nur mit: OK"
```

## Sicherheit

`litellm.env` und `models.json` stehen in `.gitignore`. Bitte niemals einen Key committen.
