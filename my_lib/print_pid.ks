@LAZYGLOBAL off.

parameter pid.

runoncepath("0:/KSLib/library/lib_exec").

local suffixes_to_ignore to lexicon().
for suffix in list("update", "reset", "hassuffix", "suffixnames", "istype") {
  suffixes_to_ignore:add(suffix, true).
}.
for suffixname in pid:suffixnames {
  if not suffixes_to_ignore:haskey(suffixname) {
    print suffixname + ": " + get_suffix(pid, suffixname).
  }.
}.
