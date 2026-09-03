---
name: nappai-connect
description: Connect this Claude Code to the NappAI MCP server with a platform API key, using `claude mcp add --header "Authorization: Bearer <key>"`. Use it when the user asks how to connect, set up or register NappAI, where to put their API key, or when /nappai:status says the server is not registered.
argument-hint: [mcp-url]
allowed-tools: Bash(bash:*)
---

# Connect to the NappAI MCP server

You need **the MCP URL** for the user's deployment; it ends in `/flow-editor-mcp/mcp`. If they
haven't said it, ask — don't guess it and don't use an example one.

## The way to tell them (this is the main one)

One command, pasting the key straight into it. Give them this to run **in their terminal**,
with their URL and their key:

```
claude mcp add --scope user --transport http nappai \
  https://<host>/flow-editor-mcp/mcp \
  --header "Authorization: Bearer YOUR_API_KEY"
```

Then they reopen Claude Code and the tools are there. That is the whole thing: the credential
lives in their user configuration (`~/.claude.json`, mode 600) and nothing depends on
environment variables.

It must be a **platform** API key — the one used to call flows over the API — not a session
token. Running the command again replaces the registration, so it is also how a rotated key
gets updated.

## If they'd rather this plugin did it

The plugin's script does the same `claude mcp add`, and additionally checks the key against the
server **before** storing it, which turns a wrong key into a clear message instead of a server
that fails on every turn:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/connect.sh" <URL>
```

It reads the key from `~/.nappai/api-key` (mode 600); if that file isn't there, it prints the
three lines that create it.

## Never ask for the key in the chat

**Don't ask them to paste the API key here, and if they do paste it, don't repeat it and don't
put it in any command.** What is typed in the chat stays in the conversation transcript and is
sent to the model on every turn. The key belongs in their terminal, in the command above.

## Reading the script's output

| It says | What it means |
|---|---|
| `server "nappai" registered` | Done. Tell them to **reopen Claude Code**, then `/nappai:status` |
| `The MCP rejected the credential` | Wrong key for that deployment, or a session token instead of a platform key |
| `Couldn't reach …` | The URL doesn't answer; if it's internal, they need the VPN |
| `I can't find your platform API key` | No key file — it prints both ways to fix it |
