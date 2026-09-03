---
name: nappai-estado
description: Comprueba si el plugin de NappAI está conectado, si el MCP responde y de dónde sale la credencial. Úsalo cuando la persona pregunte si NappAI está configurado, cuando las tools de nappai no aparezcan, o antes de dar por perdido un fallo de flujos.
allowed-tools: Bash(bash:*)
---

# Estado de la instalación de NappAI

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/estado.sh"
```

Resume el resultado en dos o tres líneas: si el plugin está cargado, si el servidor MCP está
registrado y si contesta. Cuando falte algo, di el paso concreto que lo arregla en vez de
describir el problema.

* **No está registrado** → `/nappai:conectar`.
* **Registrado pero no conecta** → casi siempre la URL es interna y falta VPN, o la key se ha
  rotado en la plataforma. En los dos casos el siguiente paso es `/nappai:conectar`, que
  actualiza la credencial sin duplicar el servidor.
* **Conecta pero el agente no ve tools** → la sesión se abrió antes de registrarlo; hay que
  reabrir Claude Code.

La salida ya tapa las cabeceras. Si aun así vieras algo con pinta de credencial, **no lo
repitas** en tu respuesta.
