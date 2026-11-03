# Plugin de NappAI para Claude Code — se ha mudado

El plugin vive ahora en **[nappai-dev/nappai-plugin](https://github.com/nappai-dev/nappai-plugin)**.
Este repositorio ya no tiene el plugin: sólo un marketplace que lo descarga de allí.

## Si lo instalaste desde aquí

Sigue funcionando: al actualizar, el plugin llega ya desde el repositorio nuevo.

```sh
claude plugin marketplace update napptilus
claude plugin update nappai@napptilus
```

Pero este repositorio dejará de mantenerse, así que conviene apuntar al nuevo. Quitar el
marketplace desinstala el plugin; tu conexión con el MCP (`claude mcp add … nappai`) no se toca.

```sh
claude plugin marketplace remove napptilus
claude plugin marketplace add nappai-dev/nappai-plugin
claude plugin install nappai@napptilus
```

Después, para que se actualice solo: `/plugin` → **Marketplaces** → `napptilus` →
**Enable auto-update**. Las instrucciones completas están en el
[README del repositorio nuevo](https://github.com/nappai-dev/nappai-plugin#readme).
