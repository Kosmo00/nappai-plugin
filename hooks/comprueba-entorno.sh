#!/usr/bin/env bash
# ¿Está el MCP de NappAI registrado en esta instalación?
#
# POR QUÉ EXISTE ESTO. El plugin se instala sin pedir credencial, así que es fácil darlo por
# terminado y quedarse con las cuatro skills cargadas y NINGUNA tool: un asistente que habla de
# flujos con toda naturalidad y no puede tocar ninguno. No hay error ni aviso, sólo prosa. Este
# hook convierte ese silencio en una frase al arrancar la sesión.
#
# Si está registrado, CALLA. Sólo habla cuando hay algo que hacer.
set -u

NOMBRE="${NAPPAI_MCP_NAME:-nappai}"
CONFIG="${CLAUDE_CONFIG_FILE:-$HOME/.claude.json}"

[ -r "${CONFIG}" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0   # sin python3 no se mira: mejor callar que adivinar

# Se lee el JSON de verdad y no con `grep`: el nombre «nappai» aparece en ese fichero por otras
# razones (rutas de proyectos, por ejemplo), y un aviso falso se aprende a ignorar en dos días.
python3 - "${CONFIG}" "${NOMBRE}" <<'PY'
import json, sys

ruta, nombre = sys.argv[1], sys.argv[2]
try:
    with open(ruta, encoding="utf-8") as f:
        config = json.load(f)
except Exception:
    sys.exit(0)

servidores = config.get("mcpServers") or {}
if nombre in servidores:
    sys.exit(0)

# La salida de un `SessionStart` entra en el contexto de la sesión: va escrita para que el
# asistente sepa qué falta y lo diga en el momento en que se le pida algo de NappAI, en vez de
# intentarlo y fracasar sin explicación.
print(f"""[plugin nappai] Las tools de NappAI NO están disponibles: el servidor MCP «{nombre}» no
está registrado en esta instalación.

Si la persona pide construir, modificar o ejecutar un flujo de NappAI, dile que ejecute

    /nappai:conectar

que le pedirá la URL de su despliegue y tomará la API key de ~/.nappai/api-key sin que tenga
que escribirla en el chat. Con /nappai:estado se comprueba después. Las skills de nappai
describen un trabajo que se hace con esas tools: sin ellas no se puede hacer a mano, así que no
lo intentes.""")
PY
