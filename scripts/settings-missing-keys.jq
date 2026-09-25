# Slurped input: .[0] = repo settings defaults, .[1] = live Pi settings.
# Emits the default leaf keys the live file lacks, dotted and comma-separated
# (empty string when every default is already set). Arrays count as leaves:
# a live array replaces the default one wholesale.
.[1] as $live
| [ .[0]
    | paths(type != "object")
    | select(all(.[]; type == "string"))
    | select(. as $p | ($live | try getpath($p) catch null) == null)
    | join(".") ]
| join(", ")
