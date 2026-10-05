# pi + LiteLLM

Bindet den [pi Coding Agent](https://pi.dev) an unser LiteLLM-Gateway an, damit alle Gateway-Modelle direkt in pi auswählbar sind.

## Schnellstart

Unter Windows in **Git Bash** (auch für macOS und Linux geeignet):

```bash
git clone https://github.com/eeryinkblot/pi-litellm-setup.git
cd pi-litellm-setup
./install.sh
```

`install.sh` erledigt Folgendes:

1. Es installiert fehlende Werkzeuge:
   - **Windows:** [Scoop](https://scoop.sh) (falls noch nicht vorhanden), danach `pi-coding-agent` und `jq` über Scoop. Außerdem trägt es Git Bash als `shellPath` in die pi-Einstellungen ein.
   - **macOS:** `pi-coding-agent` und `jq` über Homebrew.
   - **Linux:** `pi` über npm (`jq` musst du selbst installieren).
2. Es fragt nach der Gateway-URL und deinem LiteLLM-API-Key (die Eingabe ist unsichtbar) und speichert beides in `~/.pi/agent/litellm.env` (`chmod 600`).
3. Es holt die Modellliste vom Gateway und trägt sie in `~/.pi/agent/models.json` ein.

Danach `pi` starten (unter Windows nach einer frischen Scoop-Installation in einem **neuen** Git-Bash-Fenster), mit `/model` ein `litellm/...`-Modell wählen und mit `Ctrl+S` als Standard speichern.

## Neue Modelle übernehmen

Wenn auf dem Gateway Modelle dazukommen oder wegfallen:

```bash
~/.pi/agent/litellm-sync.sh
```

Andere Provider in deiner `models.json` bleiben dabei erhalten. Vor jeder Änderung wird `models.json.bak` angelegt.

## Wie es funktioniert

- `~/.pi/agent` meint unter Windows `%USERPROFILE%\.pi\agent`, also den Ordner, den pi selbst nutzt. Das gilt auch dann, wenn `$HOME` in Git Bash woandershin zeigt.
- Der Key steht ausschließlich in `~/.pi/agent/litellm.env`. In `models.json` steht nur ein Befehl, mit dem pi den Key bei jedem Request aus dieser Datei liest. pi führt diesen Befehl in Bash aus, unter Windows in Git Bash. Du musst also nichts in `~/.zshrc` oder `~/.bashrc` eintragen.
- Das Gateway wird als OpenAI-kompatibler Endpunkt (`/v1`) angesprochen.
- Liefert das Gateway unter `/model/info` Metadaten (Kontextgröße, Vision, Reasoning), werden sie übernommen. Sonst nutzt pi seine Standardwerte (128K Kontext, 16K Ausgabe, keine Bilder, kein Thinking).

## Troubleshooting

| Problem | Lösung |
|---|---|
| `Could not resolve host` | URL in `~/.pi/agent/litellm.env` prüfen |
| `401` / `403` | Key in `~/.pi/agent/litellm.env` prüfen |
| Modelle fehlen in `/model` | `~/.pi/agent/litellm-sync.sh` ausführen, danach `/model` neu öffnen |
| `SSL certificate problem` | Firmen-Proxy mit eigener CA: CA-Zertifikat als PEM per `export CURL_CA_BUNDLE=...` angeben |
| Windows: `pi: command not found` | Neues Git-Bash-Fenster öffnen (Scoop hat den PATH erweitert) |
| Windows: pi nutzt die falsche Bash | In `%USERPROFILE%\.pi\agent\settings.json` `shellPath` auf `...\Git\bin\bash.exe` setzen |
| Key ändern | `~/.pi/agent/litellm.env` bearbeiten. Ein Neustart von pi reicht. |

Prüfen ohne TUI:

```bash
pi --list-models litellm
pi -p --no-session --model 'litellm/<modell-id>' "Antworte nur mit: OK"
```

## Tests

Der GitHub-Actions-Workflow `Smoke-Test` führt `install.sh` unter Windows (Git Bash und Scoop) und macOS gegen einen LiteLLM-Mock aus (`tests/mock_litellm.py`). Dabei schickt er eine echte Anfrage über pi, um zu prüfen, dass der Key korrekt ankommt.

## Sicherheit

`litellm.env` und `models.json` stehen in `.gitignore`. Bitte niemals einen Key committen.
