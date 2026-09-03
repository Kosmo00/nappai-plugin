#!/usr/bin/env bash
# Is this thing working? Answers what you need to know, without showing the credential.
set -uo pipefail
NAME="${NAPPAI_MCP_NAME:-nappai}"

echo "== plugin =="
claude plugin list 2>/dev/null | grep -A3 -iE "nappai" || echo "  the plugin doesn't show as installed"

echo
echo "== MCP server \"${NAME}\" =="
# `claude mcp get` IMPRIME LA CABECERA EN CLARO (`mcp add` la redacta, éste no), así que su
# salida se tapa antes de mostrarla. Sin esto la credencial acabaría en la transcripción de la
# conversación y viajaría al modelo en cada turno. El patrón cubre cualquier cabecera con pinta
# de secreto, no sólo `Authorization`, por si el CLI añade otras más adelante.
if out="$(claude mcp get "${NAME}" 2>&1)"; then
  echo "${out}" \
    | sed -E 's/(([Aa]uthorization|[Bb]earer|[Aa]pi-?[Kk]ey|[Tt]oken)[^A-Za-z0-9]*)[A-Za-z0-9._+\/=-]{8,}/\1[hidden]/g' \
    | sed 's/^/  /'
else
  echo "  not registered. See /nappai:connect"
fi

echo
echo "== does it answer? =="
claude mcp list 2>/dev/null | grep -iE "^${NAME}:|${NAME}.*(Connected|Failed)" | sed 's/^/  /' \
  || echo "  no data"

echo
echo "== credential =="
KEY_FILE="${NAPPAI_KEY_FILE:-$HOME/.nappai/api-key}"
if claude mcp get "${NAME}" >/dev/null 2>&1; then
  echo "  stored in the server registration (user config, mode 600)"
fi
if [ -r "${KEY_FILE}" ]; then
  mode="$(stat -c '%a' "${KEY_FILE}" 2>/dev/null || stat -f '%Lp' "${KEY_FILE}" 2>/dev/null)"
  echo "  ${KEY_FILE} present (mode ${mode}$([ "${mode}" = "600" ] || echo ", should be 600"))"
elif [ -n "${NAPPAI_API_KEY:-}" ]; then
  echo "  in the NAPPAI_API_KEY variable"
fi
