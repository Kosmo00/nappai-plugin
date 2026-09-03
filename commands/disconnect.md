---
name: nappai-disconnect
description: Remove the NappAI MCP server from this Claude Code installation. Use it when the user wants to disconnect, remove or stop using NappAI, or to point it at a different deployment.
allowed-tools: Bash(bash:*)
---

# Disconnect NappAI

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/disconnect.sh"
```

That is the same as `claude mcp remove nappai --scope user`.

Afterwards tell them two things, because neither is obvious:

1. **The key file is not deleted.** Give them `rm ~/.nappai/api-key` in case they want it gone.
2. **The skills stay installed.** To remove those too: `claude plugin uninstall nappai@napptilus`
   if it came from a marketplace, or `rm -rf ~/.claude/skills/nappai` if it came from the
   tarball. `/nappai:status` says which one it was.

If what they actually want is a **different deployment**, there is nothing to disconnect: run
`claude mcp add` with the new URL and it replaces the registration.
