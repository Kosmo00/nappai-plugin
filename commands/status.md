---
name: nappai-status
description: Check whether the NappAI plugin is connected, whether the MCP server answers and where its credential comes from. Use it when the user asks if NappAI is set up, when the nappai tools don't show up, or before giving up on a flow failure.
allowed-tools: Bash(bash:*)
---

# NappAI setup status

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
```

Sum it up in two or three lines: whether the plugin is loaded, whether the MCP server is
registered and whether it answers. When something is missing, give the concrete step that fixes
it instead of describing the problem.

* **Not registered** → the `claude mcp add` command in `/nappai:connect`.
* **Registered but not connecting** → almost always an internal URL without the VPN, or a key
  that was rotated on the platform. Either way, running `claude mcp add` again replaces the
  registration; there is no need to remove anything first.
* **Connected but the agent sees no tools** → the session was opened before it was registered;
  reopen Claude Code.

The output already hides the headers. If you still see something that looks like a credential,
**do not repeat it** in your reply.
