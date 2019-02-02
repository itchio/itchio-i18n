import shell_escape from require "lapis.cmd.path"
import from_json, to_json, trim from require "lapis.util"
import columnize from require "lapis.cmd.util"

import types from require("tableshape")
import dmenu from require "helpers.menu"

-- TODO:
-- handle when key already exists

argparse = require "argparse"

parser = argparse "insert_string.moon", "Add a translation to a locale file"
parser\argument "text", "Text to be inserted into translation file"
parser\option "--translations_file", "Where translation will be inserted", "locales/en.json"
parser\option "--from", "Filename where text was pulled from, to help infer key prefix"
parser\option "--prefix", "Set key prefix, don't show picker"
parser\option "--variable_template", "Template for code output", '{{%s}}'
parser\flag "--dryrun", "Don't write to translations file"

args = parser\parse [v for _, v in ipairs arg]

jq = (command) ->
  handle = assert io.popen "jq --indent 4 '#{shell_escape command}' '#{shell_escape args.translations_file}'"
  res = assert handle\read "*a"
  from_json(res), res


find_prefixes = ->
  current_strings = jq "."

  -- find prefixes
  recurse = (t, path="", prefixes={}) ->
    for k,v in pairs t
      if type(v) == "string"
        continue if path == ""
        prefixes[path\gsub "%.$", ""] = true
      else
        recurse v, "#{path}#{k}.", prefixes

    prefixes

  prefixes = recurse current_strings
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
key = "#{prefix}.#{suffix}"\gsub("%.%.+", ".")
parts = [part for part in key\gmatch "[^%.]+"]

existing = if file = io.open(args.translations_file, "r")
  from_json assert file\read "*a"

local overwriting

current = merge
path = {}
for i, p in ipairs parts
  if i == #parts
    if existing and existing[p] and type(existing[p]) != "string"
      error "type mismatch: #{table.concat path, "."}.#{p}, expected string, have #{type existing[p]}"

    current[p] = text
    overwriting = existing and existing[p]
  else
    if existing and existing[p] and type(existing[p]) != "table"
      error "type mismatch: #{table.concat path, "."}.#{p}, expected table, have #{type existing[p]}"

    current[p] or= {}
    current = current[p]
    table.insert path, p

    if existing
      existing = existing[p]

to_append = to_json merge
out, raw_out = jq ". * #{to_append}"

can_write = if overwriting
  if overwriting == text
    false -- no need to write
  else
    "yes" == dmenu "overwrite: #{overwriting}", { "yes", "no" }
else
  true

if args.dryrun
  print raw_out
else
  if can_write
    assert(io.open(args.translations_file, "w"))\write raw_out

-- io.stderr\write "#{prefix}\t#{suffix}\t#{args.text}\n"
import string_to_code from require "helpers.code_gen"
string_to_code key, text
