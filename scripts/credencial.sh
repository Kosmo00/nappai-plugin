#!/usr/bin/env bash
# De dónde sale la API key, sin que pase por el contexto del modelo ni por el entorno.
#
# Este fichero se incluye (`source`) desde los demás scripts del plugin. No imprime la key
# NUNCA: la deja en la variable `NAPPAI_KEY` para quien lo llame y sólo informa por stderr de
# dónde la ha sacado.
#
# EL ORDEN IMPORTA, y el primero es el recomendado:
#
#   1. ~/.nappai/api-key — un fichero con permisos 600 que sólo lee tu usuario.
#   2. $NAPPAI_API_KEY   — si ya la tienes exportada, se respeta; pero no hace falta.
#
# POR QUÉ NO SE PASA COMO ARGUMENTO DE UN COMANDO: lo que se escribe en el chat entra en la
# transcripción de la conversación y viaja al modelo en cada turno. Un fichero 600 leído por un
# script no entra en ninguna de las dos cosas.
FICHERO_KEY="${NAPPAI_KEY_FILE:-$HOME/.nappai/api-key}"
NAPPAI_KEY=""

if [ -r "${FICHERO_KEY}" ]; then
  # `tr -d` por el salto de línea final que deja cualquier editor: una cabecera con `\n` da un
  # 401 que no se parece en nada a «tu fichero tiene un retorno de carro de más».
  NAPPAI_KEY="$(tr -d '\r\n' < "${FICHERO_KEY}")"
  origen="${FICHERO_KEY}"
  permisos="$(stat -c '%a' "${FICHERO_KEY}" 2>/dev/null || stat -f '%Lp' "${FICHERO_KEY}" 2>/dev/null)"
  if [ "${permisos}" != "600" ]; then
    echo "[nappai] Aviso: ${FICHERO_KEY} tiene permisos ${permisos}; debería ser 600." >&2
    echo "[nappai]   chmod 600 ${FICHERO_KEY}" >&2
  fi
elif [ -n "${NAPPAI_API_KEY:-}" ]; then
  NAPPAI_KEY="${NAPPAI_API_KEY}"
  origen="la variable NAPPAI_API_KEY"
fi

if [ -z "${NAPPAI_KEY}" ]; then
  cat >&2 <<TXT
[nappai] No encuentro tu API key de plataforma. Guárdala en un fichero que sólo puedas leer tú:

    mkdir -p ~/.nappai
    printf '%s' 'TU_API_KEY' > ~/.nappai/api-key
    chmod 600 ~/.nappai/api-key

Y vuelve a lanzarlo. No la escribas en el chat: lo que se teclea ahí queda en la transcripción
de la conversación y se manda al modelo en cada turno.
TXT
  return 1 2>/dev/null || exit 78
fi

echo "[nappai] credencial tomada de ${origen}" >&2
