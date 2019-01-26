import shell_escape from require "lapis.cmd.path"
import from_json, to_json, trim from require "lapis.util"
import columnize from require "lapis.cmd.util"

SOURCE = "locales/en.json"

source_text = assert ..., "missing source string"

jq = (command) ->
  handle = assert io.popen "jq --indent 4 '#{shell_escape command}' '#{shell_escape SOURCE}'"
  res = assert handle\read "*a"
  from_json(res), res

dmenu = (prompt, options) ->
  pre = if options
    columns = for opt in *options
      if type(opt) == "table"
        opt
      else
        {opt}

    "'#{shell_escape columnize columns, 0, nil, false}'"
  else
    ''

  cmd = "echo -n #{pre} | dmenu -i -l 20 -p '#{shell_escape prompt}' -fn 'xos4 Terminus-16'"
  f = assert io.popen cmd
  trim f\read("*all")


find_prefixes = ->
  current_strings = jq "."
  ignore_suffixes = {"one", "few", "many", "other"}

  -- find prefixes
  prefixes = {}
  for key in pairs current_strings
    parts = [part for part in key\gmatch "[^%.]+"]

    continue if #parts == 1

    -- remove ignored suffixes
    for i in *ignore_suffixes
      if parts[#parts] == i
        parts[#parts] = nil
        break

    -- remove the key name
    parts[#parts] = nil
    prefix = table.concat parts, "."
    prefixes[prefix] = true


  prefixes = [k for k in pairs prefixes]
  table.sort prefixes
  prefixes

convert_to_key = (str) ->
  out = str\lower!\gsub("%s+", "_")\gsub("[^%d%w_]", "")
  out

prefix = dmenu "Prefix:", find_prefixes!

if prefix == ""
  os.exit 1
  return

suffix = dmenu "#{prefix}.", {
  convert_to_key source_text
}

if suffix == ""
  os.exit 1
  return

print prefix, suffix, source_text

to_append = to_json { ["#{prefix}.#{suffix}"]: source_text }
out, raw_out = jq ". + #{to_append}"
assert(io.open(SOURCE, "w"))\write raw_out

