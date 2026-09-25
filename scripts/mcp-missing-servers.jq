# Slurped input: .[0] = repo MCP defaults, .[1] = live Pi mcp.json.
# Emits the default server names the live .mcpServers lacks, comma-separated
# (empty string when every default server is already present).
(.[1].mcpServers // {}) as $live
| [ .[0].mcpServers | keys[] | select(. as $name | $live | has($name) | not) ]
| join(", ")
