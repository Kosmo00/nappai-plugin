# Plugin de NappAI para Claude Code

Trae las cuatro skills con las que el asistente de NappAI construye flujos —planificar,
investigar el catálogo, construir y arreglar— y declara el MCP de la plataforma, que es lo que
convierte esas instrucciones en cambios reales sobre un lienzo.

Sólo para **Claude Code**. Ni el manifest ni el `.mcp.json` son portables a otros clientes.

## Instalar

Dos vías. La primera, desde el repositorio del plugin:

```sh
claude plugin marketplace add <owner>/<repo del plugin>
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

Un comando, y la API key no se escribe en el chat.

**1. Deja la key en un fichero que sólo puedas leer tú:**

```sh
mkdir -p ~/.nappai
printf '%s' 'TU_API_KEY' > ~/.nappai/api-key
chmod 600 ~/.nappai/api-key
```

Es tu API key de **plataforma**: la misma con la que se llaman los flujos por API, no un token
de sesión.

**2. Conecta:**

```
/nappai:conectar https://<host>/flow-editor-mcp/mcp
```

El comando comprueba que la credencial funciona contra ese servidor y sólo entonces la registra
en la configuración de usuario de Claude Code (`~/.claude.json`, permisos 600). No hay que
exportar ninguna variable de entorno, y la key no pasa por la conversación: lo que se teclea en
el chat queda en la transcripción y viaja al modelo en cada turno.

**3. Reabre Claude Code** y comprueba:

```
/nappai:estado
```

## Los comandos

| Comando | Qué hace |
|---|---|
| `/nappai:conectar [url]` | Registra el MCP con tu API key. Volver a ejecutarlo **actualiza** la credencial (es lo que se hace al rotarla), no duplica el servidor |
| `/nappai:estado` | Si el plugin está cargado, si el servidor está registrado, si contesta y de dónde sale la credencial. Las cabeceras salen tapadas |
| `/nappai:desconectar` | Retira el servidor. No borra el fichero de la key |

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
claude plugin uninstall nappai@napptilus   # si vino del marketplace
rm -rf ~/.claude/skills/nappai             # si vino del tar
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
