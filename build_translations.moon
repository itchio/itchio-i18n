-- generates lua file containing all the translations

compile = require "moonscript.compile"

lfs = require "lfs"

DIR = "locales/"

SOURCE_LOCALE = "en"

json = require "cjson"

output = { }

flatten_nested = (t, prefix="", out={}) ->
  for k,v in pairs t
    if type(v) == "table"
      flatten_nested v, "#{prefix}#{k}.", out
    else
      out["#{prefix}#{k}"] = v

  out

for file in assert lfs.dir DIR
  continue if file\match "^%.+$"
  name = file\match "^(%w+).json$"
  continue unless name
  handle = assert io.open "#{DIR}/#{file}"
  contents = assert handle\read "*a"

  object = json.decode contents
  output[name] = flatten_nested object

-- summarize completion
do
  -- remove any plural suffixes
  normalize_key = (key) -> (key\gsub("_%d+$", "")\gsub("_plural$", ""))
  source_translations = assert output[SOURCE_LOCALE], "missing source locale: #{SOURCE_LOCALE}"
  source_keys = {normalize_key(key), true for key in pairs source_translations}
  source_keys = [key for key in pairs source_keys]

  for locale, translations in pairs output
    found = 0
    translated_keys = {normalize_key(key), true for key in pairs output when type(key) == "string"}

    for key in *source_keys
      if translations[key]
        found += 1

    table.insert translations, {
      :found
      completion_ration: found / #source_keys
    }

import parse_tags, chunk_to_syntax from require "helpers.compiler"
import types from require "tableshape"

simple_string = types.shape { types.string }

string_to_syntax = (str) ->
  chunks = parse_tags\match str

  unless chunks
    error "failed to parse string: #{str}"

  if simple_string chunks
    return nil

  lines = [chunk_to_syntax chunk for chunk in *chunks]
  {"fndef", {{"text_fn"}, {"variables"}}, {}, "slim", lines}

encode_value = (v) ->
  switch type(v)
    when "number"
      {"number", v}
    when "table"
      keys = [k for k in pairs v]

      table.sort keys, (a, b) ->
        if type(a) != type(b)
          if type(a) == "number"
            return true

          if type(b) == "number"
            return false
        else
            return a < b

      {"table", for k in *keys
        if type(k) == "number"
          {
            encode_value v[k]
          }
        else
          k = tostring k
          {
            if k\match "%."
              {"string", '"', k}
            else
              {"key_literal", k}

            encode_value v[k]
          }
      }
    else
      str = tostring v

      if fn = string_to_syntax str
        return fn

      delim = if str\match '"'
        if str\match "'"
          '[==['
        else
          "'"
      else
        '"'

      {"string", delim, v}

print (compile.tree {
  {"return", encode_value output}
})
