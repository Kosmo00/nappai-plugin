#!/usr/bin/env bash
# Removes the MCP server from your user configuration. Does NOT delete the key file: that is
# done by hand and on purpose, because it is the part that takes work to get back.
set -uo pipefail
NAME="${NAPPAI_MCP_NAME:-nappai}"
if claude mcp remove "${NAME}" --scope user 2>/dev/null; then
  echo "[nappai] server \"${NAME}\" removed from your user configuration."
else
  echo "[nappai] \"${NAME}\" wasn't registered; nothing to remove."
fi
KEY_FILE="${NAPPAI_KEY_FILE:-$HOME/.nappai/api-key}"
if [ -e "${KEY_FILE}" ]; then
  echo "[nappai] Your key is still in ${KEY_FILE}. To delete it too:  rm ${KEY_FILE}"
fi
