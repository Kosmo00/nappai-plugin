# Plugin de NappAI para Claude Code

Trae las cuatro skills con las que el asistente de NappAI construye flujos —planificar,
investigar el catálogo, construir y arreglar— y los comandos para conectar el MCP de la
plataforma, que es lo que convierte esas instrucciones en cambios reales sobre un lienzo.

Sólo para **Claude Code**: los comandos usan `claude mcp add` para registrar el servidor, que no
es portable a otros clientes.

## Instalar

Dos vías. La primera, desde el repositorio del plugin en GitHub:

```sh
claude plugin marketplace add Kosmo00/nappai-plugin
claude plugin install nappai@napptilus
```

La segunda, desde el propio despliegue, con tu API key de plataforma:

```sh
curl -fsSL -H "x-api-key: $NAPPAI_API_KEY" \
  https://<host>/api/v2/claude-plugin/nappai.tar.gz | tar xz -C ~/.claude/skills/
```

Traen lo mismo. La diferencia es que la primera se actualiza con `claude plugin update` y la
segunda repitiendo el `curl`.

## Poner en marcha

**Un comando, con la API key pegada dentro.** Es la forma principal y no necesita nada más:

```sh
claude mcp add --scope user --transport http nappai \
  https://<host>/flow-editor-mcp/mcp \
  --header "Authorization: Bearer PEGA_TU_API_KEY"
```

Sustituye `<host>` por el de tu despliegue (en desarrollo, `http://localhost:5163`) y
`PEGA_TU_API_KEY` por tu API key **de plataforma** — la misma con la que se llaman los flujos
por API, no un token de sesión. Después **reabre Claude Code** y comprueba con `/nappai:status`.

La credencial queda en tu configuración de usuario (`~/.claude.json`, permisos 600). No hay
variables de entorno de por medio, y volver a ejecutar el comando **reemplaza** el registro: es
también la forma de actualizar una key rotada.

> Al pegar la key en la consola queda en el historial del shell. Para evitarlo, escribe la línea
> empezando con un espacio (con `HISTCONTROL=ignorespace` en bash o `setopt HIST_IGNORE_SPACE`
> en zsh), o bórrala después con `history -d <número>`.

### Si prefieres que el plugin lo haga

Hace el mismo `claude mcp add`, y además comprueba la key contra el servidor **antes** de
guardarla, así que una key equivocada da un mensaje claro en vez de un servidor que falla en
cada turno:

```sh
mkdir -p ~/.nappai
printf '%s' 'PEGA_TU_API_KEY' > ~/.nappai/api-key
chmod 600 ~/.nappai/api-key
```

y dentro de Claude Code:

```
/nappai:connect https://<host>/flow-editor-mcp/mcp
```

El `printf` en vez de `echo` es a propósito: con `echo` el fichero se queda con un salto de
línea al final, y la cabecera saldría con ese salto dentro, lo que da un 401 que no se parece en nada a la
causa.

**No escribas la key en el chat**: lo que se teclea ahí queda en la transcripción de la
conversación y viaja al modelo en cada turno.

## Los comandos

| Comando | Qué hace |
|---|---|
| `/nappai:connect [url]` | Registra el MCP con tu API key, validándola antes. Repetirlo **actualiza** la credencial, no duplica el servidor |
| `/nappai:status` | Si el plugin está cargado, si el servidor está registrado, si contesta y de dónde sale la credencial. Las cabeceras salen tapadas |
| `/nappai:disconnect` | Retira el servidor (`claude mcp remove nappai --scope user`). No borra el fichero de la key |

## Qué hace cada skill

| Skill | Cuándo entra |
|---|---|
| `nappai-plan` | Siempre primero: convierte el encargo en un plan y pide conformidad antes de tocar el lienzo |
| `nappai-researcher` | Cuando hay que averiguar qué componente existe o qué espera de verdad una API |
| `nappai-flow-builder` | Montar y configurar: topología, campos, `operation`, código y prompts |
| `nappai-fixer` | Cuando el flujo ya está montado y falla: ejecutar, leer la traza y corregir |

Se cargan solas cuando hacen falta; no hay que invocarlas.

## Desinstalar

```sh
claude mcp remove nappai --scope user      # el servidor
claude plugin uninstall nappai@napptilus   # el plugin, si vino del marketplace
rm -rf ~/.claude/skills/nappai             # el plugin, si vino del tar
rm ~/.nappai/api-key                       # la key, si la dejaste en el fichero
```

---

## Para quien mantiene esto

Este directorio es la FUENTE. Lo que hay aquí:

| | |
|---|---|
| `plugin.json` | La ficha del plugin: nombre, versión, descripción, autor. **El único sitio** donde se toca la versión |
| `commands/` | Los `/nappai:*` que ve la persona |
| `scripts/` | Lo que ejecutan. La lógica vive aquí, para que se pueda probar sin un modelo delante |
| `hooks/` | El aviso de arranque cuando el MCP no está registrado |
| | *La superficie de cara al usuario —comandos, mensajes de los scripts— está en inglés; los comentarios de mantenimiento, en español, como el resto del repositorio* |
| `mcp.ejemplo.json` | **Plantilla, no se empaqueta.** Para Claude Desktop/Cowork, donde el MCP no se registra con `claude mcp add` sino por configuración gestionada (headers, headersHelper u OAuth) |
| `README.md` | Esto, que viaja dentro del paquete |
| `sincroniza.py` | Publica el plugin en su repositorio de distribución |

Las skills **no están aquí**: viven en `.claude/skills/` del repositorio, que son las mismas que
el Dockerfile del runner copia a `/workspace/.claude/skills/`. Un solo sitio donde mantenerlas.

Para publicar una versión nueva: subir `version` en `plugin.json`, y

```sh
python nappai-plugin/sincroniza.py ../nappai-plugin   # el repositorio de distribución
cd ../nappai-plugin && git add -A && git commit && git push
```

El script no copia nada a mano: le pide el paquete al mismo código que sirve
`GET /api/v2/claude-plugin` y lo desempaqueta, así que lo publicado es byte a byte lo que
descarga quien usa el endpoint. No hay dos generadores que puedan discrepar, y por eso tampoco
hay que acordarse de sincronizar dos formatos cuando cambie la estructura del plugin.
