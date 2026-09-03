---
name: nappai-desconectar
description: Retira el MCP de NappAI de esta instalación de Claude Code. Úsalo cuando la persona quiera desconectar, quitar o dejar de usar NappAI, o cambiar de despliegue.
allowed-tools: Bash(bash:*)
---

# Desconectar NappAI

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/desconectar.sh"
```

Después dile dos cosas, porque ninguna es evidente:

1. **El fichero con la API key no se borra.** Dale el `rm ~/.nappai/api-key` por si lo quiere.
2. **Las skills siguen instaladas.** Para quitarlas también, `claude plugin uninstall
   nappai@napptilus` si vino del marketplace, o `rm -rf ~/.claude/skills/nappai` si vino del
   paquete. `/nappai:estado` dice cuál de las dos fue.

Si lo que quiere es **cambiar de despliegue** (otra URL), no hace falta desconectar: basta
`/nappai:conectar` con la URL nueva, que reemplaza el registro.
