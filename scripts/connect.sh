#!/usr/bin/env bash
# Registers the NappAI MCP server in Claude Code, with no environment variables involved.
#
#   scripts/connect.sh <mcp-url>
#
# Este script es la comodidad, no el mecanismo: hace lo mismo que un `claude mcp add` a mano,
# más comprobar la credencial ANTES de guardarla. Ver el README.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URL="${1:-}"
if [ -z "${URL}" ]; then
  echo "[nappai] Missing the MCP URL. For example:" >&2
  echo "         scripts/connect.sh https://<host>/flow-editor-mcp/mcp" >&2
  exit 64
fi
case "${URL}" in
  */flow-editor-mcp/mcp) ;;
  *)
    # La otra superficie (`/assistant-mcp/mcp`) publica las mismas tools pero aísla el lienzo
    # del chat y descarta los efectos: se construiría bien y no se vería moverse nada.
    echo "[nappai] Warning: the URL doesn't end in /flow-editor-mcp/mcp, which is the external" >&2
    echo "[nappai] client surface. Carry on if that's deliberate." >&2
    ;;
esac

# shellcheck source=./credential.sh
source "${DIR}/credential.sh" || exit 78

NAME="${NAPPAI_MCP_NAME:-nappai}"

# La credencial se comprueba ANTES de tocar la configuración. Guardar primero y descubrirlo
# luego deja un servidor que aparece en la lista y falla en cada turno.
code="$(curl -s -o /dev/null -w '%{http_code}' -m 20 -X POST "${URL}" \
  -H "Authorization: Bearer ${NAPPAI_KEY}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"nappai-plugin","version":"1"}}}' 2>/dev/null)"

case "${code}" in
  200) echo "[nappai] the credential works against ${URL}" ;;
  401|403)
    echo "[nappai] The MCP rejected the credential (HTTP ${code}). It must be a PLATFORM API" >&2
    echo "[nappai] key — the one you call flows with — not a session token." >&2
    exit 77 ;;
  000)
    echo "[nappai] Couldn't reach ${URL}. If that's an internal address, you need the VPN." >&2
    exit 69 ;;
  *)
    echo "[nappai] Unexpected reply from the MCP (HTTP ${code}); leaving your config alone." >&2
    exit 69 ;;
esac

# `remove` primero para que volver a ejecutarlo ACTUALICE en vez de fallar por duplicado: es lo
# que se hace al rotar la key, y es cuando más molesta un error.
claude mcp remove "${NAME}" --scope user >/dev/null 2>&1 || true
if claude mcp add --scope user --transport http "${NAME}" "${URL}" \
     --header "Authorization: Bearer ${NAPPAI_KEY}" >/dev/null 2>&1; then
  echo "[nappai] server \"${NAME}\" registered in your user configuration."
  echo "[nappai] Reopen Claude Code so the session picks it up."
else
  echo "[nappai] Couldn't register the server. Try it directly:" >&2
  echo "         claude mcp add --scope user --transport http ${NAME} ${URL} --header \"Authorization: Bearer YOUR_API_KEY\"" >&2
  exit 70
fi
