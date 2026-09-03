#!/usr/bin/env bash
# Quita el servidor MCP de la configuración de usuario. NO borra el fichero de la key: eso se
# hace a mano y a propósito, porque es lo que cuesta recuperar.
set -uo pipefail
NOMBRE="${NAPPAI_MCP_NAME:-nappai}"
if claude mcp remove "${NOMBRE}" --scope user 2>/dev/null; then
  echo "[nappai] servidor «${NOMBRE}» retirado de la configuración de usuario."
else
  echo "[nappai] «${NOMBRE}» no estaba registrado; no hay nada que quitar."
fi
echo "[nappai] La key sigue en ${NAPPAI_KEY_FILE:-$HOME/.nappai/api-key} (si la había)."
echo "[nappai] Para borrarla:  rm ~/.nappai/api-key"
