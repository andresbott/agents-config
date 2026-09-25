# Input: live Pi settings. $entry: a package object from pi-packages.txt, e.g.
#   {"source":"git:…","skills":["skills/foo"]}
# Seeds the manifest's resource filter: every plain-string package entry equal
# to $entry.source becomes $entry. Object entries are left alone (live filters
# win, e.g. edits made in `pi config`), and a missing source is never added —
# `pi install` owns adding it.
if (.packages | type) == "array"
then .packages |= map(if . == $entry.source then $entry else . end)
else .
end
