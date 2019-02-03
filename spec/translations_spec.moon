
lfs = require "lfs"
json = require "cjson"

DIRS = {
  "locales/"
  "locales/documents/"
  "locales/tags/"
}

SOURCE_LOCALE = "en"

flatten_nested = (t, prefix="", out={}) ->
  for k,v in pairs t
    if type(v) == "table"
      flatten_nested v, "#{prefix}#{k}.", out
    else
      out["#{prefix}#{k}"] = v

  out

each_translation_file = (fn) ->
  for dir in *DIRS
    for file in assert lfs.dir dir
      continue if file\match "^%.+$"
      name = file\match "^([%w_-]+).json$"
      continue unless name

      handle = assert io.open "#{dir}/#{file}"
      contents = assert handle\read "*a"
      fn dir, name, json.decode(contents)


import parse_tags from require "helpers.compiler"

describe "itchio i18n", ->
  describe "parses", ->
    each_translation_file (dir, name, contents) ->
      strings = flatten_nested contents
      describe "#{dir} #{name}", ->
        for key, text in pairs strings
          it "#{key}", ->
            unless parse_tags\match(text)
              error "failed to parse:\n#{text}"
