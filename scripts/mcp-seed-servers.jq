# Slurped input: .[0] = repo MCP defaults, .[1] = live Pi mcp.json.
# Adds default servers whose name is missing from the live .mcpServers. Server
# definitions are atomic: a live entry with the same name wins whole and is
# never deep-merged (e.g. a live stdio `command` must not gain a default `url`).
# Every other live key (settings, imports, …) is kept as is.
.[0].mcpServers as $defaults
| .[1]
| .mcpServers = ($defaults + (.mcpServers // {}))
