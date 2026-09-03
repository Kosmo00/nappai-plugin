#!/usr/bin/env bash
# Registra el MCP de NappAI en Claude Code con la API key, SIN variables de entorno.
#
#   scripts/conectar.sh <url-del-mcp>
#
# Deja el servidor en la configuración de usuario (`~/.claude.json`, permisos 600), que es donde
# el CLI guarda sus servidores. La key no pasa por la línea de comandos de nadie más, no se
# imprime y no entra en la conversación.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URL="${1:-}"
if [ -z "${URL}" ]; then
  echo "[nappai] Falta la URL del MCP. Ejemplo:" >&2
  echo "         scripts/conectar.sh https://<host>/flow-editor-mcp/mcp" >&2
  exit 64
fi
case "${URL}" in
  */flow-editor-mcp/mcp) ;;
  *)
    # La otra superficie (`/assistant-mcp/mcp`) publica las mismas tools pero aísla el lienzo
    # del chat y descarta los efectos: se construiría bien y no se vería moverse nada.
    echo "[nappai] Aviso: la URL no acaba en /flow-editor-mcp/mcp, que es la superficie del" >&2
    echo "[nappai] cliente externo. Si es a propósito, adelante." >&2
    ;;
esac

# shellcheck source=./credencial.sh
source "${DIR}/credencial.sh" || exit 78

NOMBRE="${NAPPAI_MCP_NAME:-nappai}"

# Antes de tocar la configuración, se comprueba que la credencial SIRVE contra esa URL. Guardar
# primero y descubrirlo luego deja un servidor que aparece en la lista y falla en cada turno.
codigo="$(curl -s -o /dev/null -w '%{http_code}' -m 20 -X POST "${URL}" \
  -H "Authorization: Bearer ${NAPPAI_KEY}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"nappai-plugin","version":"1"}}}' 2>/dev/null)"

case "${codigo}" in
  200) echo "[nappai] la credencial funciona contra ${URL}" ;;
  401|403)
    echo "[nappai] El MCP rechaza la credencial (HTTP ${codigo}). La key es de PLATAFORMA, la" >&2
    echo "[nappai] misma con la que se llaman los flujos por API; no un token de sesión." >&2
    exit 77 ;;
  000)
    echo "[nappai] No he podido llegar a ${URL}. Si es una dirección interna, hace falta VPN." >&2
    exit 69 ;;
  *)
    echo "[nappai] Respuesta inesperada del MCP (HTTP ${codigo}); no toco la configuración." >&2
    exit 69 ;;
esac

# `remove` primero para que volver a ejecutarlo ACTUALICE en vez de fallar por duplicado: es lo
# que se hace al rotar la key, y es cuando más molesta un error.
claude mcp remove "${NOMBRE}" --scope user >/dev/null 2>&1 || true
if claude mcp add --scope user --transport http "${NOMBRE}" "${URL}" \
     --header "Authorization: Bearer ${NAPPAI_KEY}" >/dev/null 2>&1; then
  echo "[nappai] servidor «${NOMBRE}» registrado en la configuración de usuario."
  echo "[nappai] Reabre Claude Code (o /mcp) para que la sesión lo cargue."
else
  echo "[nappai] No he podido registrar el servidor. Prueba a mano:" >&2
  echo "         claude mcp add --scope user --transport http ${NOMBRE} ${URL} --header \"Authorization: Bearer <key>\"" >&2
  exit 70
fi
