
lfs = require "lfs"
json = require "cjson"

DIRS = {
  "locales/"
  "locales/documents/"
  "locales/tags/"
}

SOURCE_LOCALE = "en"

import types from require "tableshape"

flatten_nested = (t, prefix="", out={}) ->
  for k,v in pairs t
    if type(v) == "table"
      flatten_nested v, "#{prefix}#{k}.", out
    else
      out["#{prefix}#{k}"] = v

  out

each_translation_file = (fn) ->
  for dir in *DIRS
    local source_texts

    rows = for file in assert lfs.dir dir
      continue if file\match "^%.+$"
      name = file\match "^([%w_-]+).json$"
      continue unless name

      handle = assert io.open "#{dir}/#{file}"
      contents = assert handle\read "*a"
      contents = flatten_nested json.decode contents

      if name == SOURCE_LOCALE
        assert not source_texts, "duplicate source texts"
        source_texts = contents

      { dir, name, contents}

    for r in *rows
      args = {unpack r}
      table.insert args, source_texts
      fn unpack args

import parse_tags from require "helpers.compiler"
import find_variables from require "helpers.code_gen"

describe "parses", ->
  each_translation_file (dir, name, strings, source_strings) ->
    describe "#{dir} #{name}", ->
      for key, text in pairs strings
        it "#{key}", ->
          syntax = parse_tags\match(text)
          unless syntax
            error "failed to parse:\n#{text}"

          return if strings == source_strings

          -- is it included in source text?
          singular_key = key\gsub("_%d+$", "")\gsub("_plural$", "")
          source_text = source_strings[singular_key] or source_strings[singular_key.."_plural"]
          unless source_text
            error "extra key '#{key}':\n#{text}"

          -- see if the variables match
          expected_variables = types.equivalent find_variables(parse_tags\match source_text)
          unless expected_variables find_variables syntax
            error "variables do not match:\n#{source_text}\n#{text}"




