-- select a translation key from all available keys

import from_json from require "lapis.util"
import shell_escape from require "lapis.cmd.path"
import dmenu from require "helpers.menu"
import columnize from require "lapis.cmd.util"

argparse = require "argparse"

parser = argparse "select_key.moon ", "Select key from translation"
parser\option "--translations_file", "Where translation will be inserted", "locales/en.json"
parser\option "--template", "Template for code output", '@t%q'
parser\flag "--show-text", "Also show key values"
parser\flag "--code", "Return key as code"

args = parser\parse [v for _, v in ipairs arg]

jq = (command) ->
  handle = assert io.popen "jq --indent 4 '#{shell_escape command}' '#{shell_escape args.translations_file}'"
  res = assert handle\read "*a"
  from_json(res), res

source_strings = jq "."

-- flatten the file
flatten_table = (t, path="", out={}) ->
  for k,v in pairs t
    if type(v) == "string"
      out["#{path}#{k}"] = v
    else
      flatten_table v, "#{path}#{k}.", out

  out


options = for k,v in pairs flatten_table source_strings
  {k,v}

options = [line for line in columnize(options, 0, 2, false)\gmatch "[^\n]+"]
table.sort options
out = dmenu "key", options
return if out == ""

key, text = out\match "([^%s]+)%s+(.+)"

if args.code

  import parse_tags from require "helpers.compiler"
  syntax = parse_tags\match text

  find_variables = (syntax, vars={}) ->
    for node in *syntax
      if type(node) == "table"
        if node.variable
          vars[node.variable] = "simple"

        if node.tag
          vars[node.tag] = "function"
          find_variables node.contents, vars

    vars

  variables = find_variables syntax

  if next variables
    has_function = false
    has_numeric = false

    code_chunks = for k,v in pairs variables
      if v == "function"
        has_function = true

      val = v == "function" and "(...) ->" or "nil"
      if k\match "^%d+$"
        has_numeric = true
        val
      else
        "#{k}: #{val}"

    var_code = table.concat code_chunks, ", "
    if has_numeric
      var_code = "{ #{var_code} }"

    if has_function
      print "@tt \"#{key}\", #{var_code}"
    else
      print "@t(\"#{key}\", #{var_code})"
  else
    print "@t\"#{key}\""

  -- see if we have vars
else
  print key


