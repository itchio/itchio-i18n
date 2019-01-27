import shell_escape from require "lapis.cmd.path"
import from_json, to_json, trim from require "lapis.util"
import columnize from require "lapis.cmd.util"

argparse = require "argparse"

parser = argparse "insert_string.moon", "Add a translation to a locale file"
parser\argument "text", "Text to be inserted into translation file"
parser\option "--translations_file", "Where translation will be inserted", "locales/en.json"
parser\option "--from", "Filename where text was pulled from, to help infer key prefix"
parser\option "--prefix", "Set key prefix, don't show picker"
parser\option "--template", "Template for code output", '@t%q'

args = parser\parse [v for _, v in ipairs arg]

jq = (command) ->
  handle = assert io.popen "jq --indent 4 '#{shell_escape command}' '#{shell_escape args.translations_file}'"
  res = assert handle\read "*a"
  from_json(res), res

dmenu = (prompt, options) ->
  pre = if options
    "'#{shell_escape table.concat options, "\n"}'"
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

  -- if we have a file, infert a prefix
  if args.from
    candidate = args.from\gsub("^views/", "")\gsub("^widgets/", "")\gsub("%.moon$", "")\gsub("/", ".")
    prefixes = [p for p in *prefixes when p != candidate]
    table.insert prefixes, 1, candidate

  prefixes

convert_to_key = (str) ->
  out = str\lower!\gsub("%s+", "_")\gsub("[^%d%w_]", "")
  out

prefix = args.prefix or dmenu "Prefix:", find_prefixes!

if prefix == ""
  os.exit 1
  return

suffix = dmenu "#{prefix}.", {
  convert_to_key args.text
}

if suffix == ""
  os.exit 1
  return

to_append = to_json { ["#{prefix}.#{suffix}"]: args.text }
out, raw_out = jq ". + #{to_append}"
assert(io.open(args.translations_file, "w"))\write raw_out

io.stderr\write "#{prefix}\t#{suffix}\t#{args.text}\n"
print args.template\format "#{prefix}.#{suffix}"

