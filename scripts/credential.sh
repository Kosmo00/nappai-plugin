#!/usr/bin/env bash
# De dónde sale la API key. Se incluye (`source`) desde los demás scripts.
#
# NUNCA la imprime: la deja en `NAPPAI_KEY` y sólo informa por stderr de dónde la ha sacado.
# El orden es: fichero 600 primero, variable de entorno después (se respeta si ya la tienes
# exportada, pero no hace falta).
#
# POR QUÉ NO SE PASA COMO ARGUMENTO DE UN COMANDO DEL CHAT: lo que se teclea en la conversación
# entra en la transcripción y viaja al modelo en cada turno. Un fichero 600 leído por un script
# no pasa por ninguna de las dos cosas.
KEY_FILE="${NAPPAI_KEY_FILE:-$HOME/.nappai/api-key}"
NAPPAI_KEY=""

if [ -r "${KEY_FILE}" ]; then
  # `tr -d` por el salto de línea que deja cualquier editor: una cabecera con `\n` da un 401
  # que no se parece en nada a «tu fichero tiene un retorno de carro de más».
  NAPPAI_KEY="$(tr -d '\r\n' < "${KEY_FILE}")"
  source_desc="${KEY_FILE}"
  mode="$(stat -c '%a' "${KEY_FILE}" 2>/dev/null || stat -f '%Lp' "${KEY_FILE}" 2>/dev/null)"
  if [ "${mode}" != "600" ]; then
    echo "[nappai] Warning: ${KEY_FILE} has mode ${mode}; it should be 600." >&2
    echo "[nappai]   chmod 600 ${KEY_FILE}" >&2
  fi
elif [ -n "${NAPPAI_API_KEY:-}" ]; then
  NAPPAI_KEY="${NAPPAI_API_KEY}"
  source_desc="the NAPPAI_API_KEY variable"
fi

if [ -z "${NAPPAI_KEY}" ]; then
  cat >&2 <<TXT
[nappai] I can't find your platform API key.

The direct way — paste the key straight into this one command:

    claude mcp add --scope user --transport http nappai \\
      https://<host>/flow-editor-mcp/mcp \\
      --header "Authorization: Bearer YOUR_API_KEY"

Or, to let this plugin manage it, leave the key in a file only you can read:

    mkdir -p ~/.nappai
    printf '%s' 'YOUR_API_KEY' > ~/.nappai/api-key
    chmod 600 ~/.nappai/api-key

Either way, don't type the key into the chat: what you type there stays in the
conversation transcript and is sent to the model on every turn.
TXT
  return 1 2>/dev/null || exit 78
fi

echo "[nappai] credential taken from ${source_desc}" >&2
