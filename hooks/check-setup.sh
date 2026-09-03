#!/usr/bin/env bash
# ¿Está el MCP de NappAI registrado en esta instalación?
#
# POR QUÉ EXISTE ESTO. El plugin se instala sin pedir credencial, así que es fácil darlo por
# terminado y quedarse con las cuatro skills cargadas y NINGUNA tool: un asistente que habla de
# flujos con toda naturalidad y no puede tocar ninguno. No hay error ni aviso, sólo prosa.
#
# Si está registrado, CALLA. Sólo habla cuando hay algo que hacer.
set -u

NAME="${NAPPAI_MCP_NAME:-nappai}"
CONFIG="${CLAUDE_CONFIG_FILE:-$HOME/.claude.json}"

[ -r "${CONFIG}" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0   # sin python3 no se mira: mejor callar que adivinar

# Se lee el JSON de verdad y no con `grep`: el nombre «nappai» aparece en ese fichero por otras
# razones (rutas de proyectos, por ejemplo), y un aviso falso se aprende a ignorar en dos días.
python3 - "${CONFIG}" "${NAME}" <<'PY'
import json, sys

path, name = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        config = json.load(f)
except Exception:
    sys.exit(0)

if name in (config.get("mcpServers") or {}):
    sys.exit(0)

# La salida de un `SessionStart` entra en el contexto de la sesión: va escrita para que el
# asistente sepa qué falta y lo diga en el momento en que se le pida algo de NappAI, en vez de
# intentarlo y fracasar sin explicación.
print(f"""[nappai plugin] NappAI tools are NOT available: the MCP server "{name}" is not
registered in this installation.

If the user asks to build, change or run a NappAI flow, tell them to run this in their terminal,
pasting their platform API key into it:

    claude mcp add --scope user --transport http {name} \\
      https://<host>/flow-editor-mcp/mcp \\
      --header "Authorization: Bearer YOUR_API_KEY"

Then reopen Claude Code. `/nappai:connect` does the same thing and checks the key first, and
`/nappai:status` confirms it. Never ask them to paste the key into the chat: what they type here
stays in the transcript and is sent to the model on every turn. The nappai skills describe work
that is done with those tools — without them it cannot be done by hand, so don't try.""")
PY
