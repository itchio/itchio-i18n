import shell_escape from require "lapis.cmd.path"
import from_json, to_json, trim from require "lapis.util"
import columnize from require "lapis.cmd.util"

import types from require("tableshape")

-- TODO:
-- handle when key already exists

argparse = require "argparse"

parser = argparse "insert_string.moon", "Add a translation to a locale file"
parser\argument "text", "Text to be inserted into translation file"
parser\option "--translations_file", "Where translation will be inserted", "locales/en.json"
parser\option "--from", "Filename where text was pulled from, to help infer key prefix"
parser\option "--prefix", "Set key prefix, don't show picker"
parser\option "--template", "Template for code output", '@t%q'
parser\option "--variable_template", "Template for code output", '{{%s}}'
parser\flag "--dryrun", "Don't write to translations file"

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

  cmd = "echo -n #{pre} | dmenu -i -l 20 -p '#{shell_escape prompt}' -fn 'xos4 Terminus-20'"
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
  out = str\lower!\gsub("[%s@\\:()!]+", "_")\gsub("[^%d%w_]", "")\gsub("__+", "_")
  out = out\gsub("^_+", "")\reverse!\gsub("^_+", "")\reverse!
  out

format_text = (str) ->
  unless str\match [=[^['"]]=]
    return str, convert_to_key str

  node = assert require("moonscript.parse").string str
  node = unpack node

  -- strip escape sequences
  import P, C, S, Cmt, Cs, Cp, Ct from require "lpeg"
  strip_escapes = Cs (P"\\#{node[2]}" / node[2] + P"\\\\" / "\\" + 1)^0

  extract_interpolations = do
    import build_grammar from require "moonscript.parse"
    import trim from require "lapis.util"

    White = S" \t\r\n"^0

    -- read as much valid moonscript as possible from a #{
    grammar = build_grammar!
    read_interpolation = P[[#{]] * White * Cmt(Cp! * grammar, (s, stop, start) ->
      true, trim s\sub start, stop - 1
    ) * P"}"

    Ct (read_interpolation + P(1))^0

  interpolations = assert extract_interpolations\match str

  out_chunks = {}
  key_parts = {}
  variables = {}

  k = 0
  for part in *node[3,]
    switch type part
      when "string"
        part = assert strip_escapes\match part
        table.insert out_chunks, part
        table.insert key_parts, convert_to_key part
      when "table"
        interpolate = types.shape { "interpolate", types.any\tag "exp" }, open: true
        if res = interpolate part
          k += 1
          code = assert interpolations[k], "missing interpoaltion at #{k}"
          variable = convert_to_key code
          table.insert out_chunks, args.variable_template\format variable
          table.insert key_parts, variable
          table.insert variables, { variable, code }
        else
          error "unknown string part type"

  table.concat(out_chunks), convert_to_key(table.concat key_parts, "_"), variables

prefix = args.prefix or dmenu "Prefix:", find_prefixes!

if prefix == ""
  os.exit 1
  return

text, key, variables = format_text args.text

suffix = dmenu "#{prefix}.", { key }

if suffix == ""
  os.exit 1
  return


merge = {}
key = "#{prefix}.#{suffix}"
parts = [part for part in key\gmatch "[^%.]+"]

current = merge
for i, p in ipairs parts
  if i == #parts
    current[p] = text
  else
    current[p] or= {}
    current = current[p]

to_append = to_json merge
out, raw_out = jq ". * #{to_append}"

if args.dryrun
  print raw_out
else
  assert(io.open(args.translations_file, "w"))\write raw_out

-- io.stderr\write "#{prefix}\t#{suffix}\t#{args.text}\n"
if variables and next variables
  out = {
    [[@t("]]
    "#{prefix}.#{suffix}"
    [[", ]]
  }

  for {name, expression} in *variables
    table.insert out, "#{name}: "
    table.insert out, expression
    table.insert out, ", "

  out[#out] = ")"
  print table.concat out
else
  print args.template\format "#{prefix}.#{suffix}"

