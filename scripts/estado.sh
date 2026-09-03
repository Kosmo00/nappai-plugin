#!/usr/bin/env bash
# ¿Está esto en marcha? Contesta lo que hace falta para saberlo, sin enseñar la credencial.
set -uo pipefail
NOMBRE="${NAPPAI_MCP_NAME:-nappai}"

echo "== plugin =="
claude plugin list 2>/dev/null | grep -A3 -iE "nappai" || echo "  el plugin no aparece instalado"

echo
echo "== servidor MCP «${NOMBRE}» =="
# `claude mcp get` IMPRIME LA CABECERA EN CLARO (`mcp add` la redacta, éste no), así que su
# salida se tapa antes de mostrarla. Sin esto la credencial acabaría en la transcripción de la
# conversación y viajaría al modelo en cada turno — precisamente lo que evita que la key no se
# teclee en el chat. El patrón cubre cualquier cabecera con pinta de secreto, no sólo
# `Authorization`, por si el CLI añade otras más adelante.
if salida="$(claude mcp get "${NOMBRE}" 2>&1)"; then
  echo "${salida}" \
    | sed -E 's/(([Aa]uthorization|[Bb]earer|[Aa]pi-?[Kk]ey|[Tt]oken)[^A-Za-z0-9]*)[A-Za-z0-9._+\/=-]{8,}/\1[oculto]/g' \
    | sed 's/^/  /'
else
  echo "  no está registrado. Ejecuta /nappai:conectar"
fi

echo
echo "== ¿contesta? =="
claude mcp list 2>/dev/null | grep -iE "^${NOMBRE}:|${NOMBRE}.*(Connected|Failed)" | sed 's/^/  /' \
  || echo "  sin datos"

echo
echo "== credencial =="
FICHERO_KEY="${NAPPAI_KEY_FILE:-$HOME/.nappai/api-key}"
if [ -r "${FICHERO_KEY}" ]; then
  permisos="$(stat -c '%a' "${FICHERO_KEY}" 2>/dev/null || stat -f '%Lp' "${FICHERO_KEY}" 2>/dev/null)"
  echo "  ${FICHERO_KEY} presente (permisos ${permisos}$([ "${permisos}" = "600" ] || echo ", deberían ser 600"))"
elif [ -n "${NAPPAI_API_KEY:-}" ]; then
  echo "  en la variable NAPPAI_API_KEY (funciona, pero un fichero 600 es mejor)"
else
  echo "  no hay ninguna. Ver /nappai:conectar"
fi
