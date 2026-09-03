---
name: nappai-conectar
description: Conecta este Claude Code con el MCP de NappAI usando la API key de plataforma. Úsalo cuando la persona pida conectar, configurar o dar de alta NappAI, cuando pregunte dónde se pone su API key, o cuando /nappai:estado diga que el servidor no está registrado.
argument-hint: [url-del-mcp]
allowed-tools: Bash(bash:*)
---

# Conectar con el MCP de NappAI

Necesitas **la URL del MCP** del despliegue de la persona; acaba en `/flow-editor-mcp/mcp`. Si
no la ha dicho, pregúntasela: no la adivines ni uses una de ejemplo.

Con la URL, ejecuta el script del plugin pasándosela como primer argumento:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/conectar.sh" <URL>
```

El script lee la credencial de `~/.nappai/api-key`, comprueba contra el servidor que sirve, y
sólo entonces la registra en la configuración de usuario de Claude Code.

## La API key no se pide por el chat

**Nunca le pidas la API key, y si la escribe, no la repitas ni la pongas en ningún comando.** Lo
que se teclea aquí queda en la transcripción de la conversación y viaja al modelo en cada turno.
Si el script dice que no la encuentra, imprime él mismo las tres líneas para dejarla en un
fichero con permisos 600: enséñaselas y pídele que vuelva a lanzarlo.

## Cómo interpretar lo que devuelve

| Lo que dice | Qué significa y qué decirle |
|---|---|
| `servidor «nappai» registrado` | Listo. Que **reabra Claude Code** para que la sesión lo cargue, y que lo compruebe con `/nappai:estado` |
| `El MCP rechaza la credencial` | La key no vale para ese despliegue. Es la de **plataforma** (la de llamar flujos por API), no un token de sesión |
| `No he podido llegar a …` | La URL no responde: si es una dirección interna, hace falta VPN |
| `No encuentro tu API key` | Falta el fichero: las tres líneas que imprime el script |

Volver a ejecutarlo actualiza la credencial en vez de duplicar el servidor, así que es también
lo que hay que hacer cuando la key se rota.
