-- generates lua file containing all the translations

compile = require "moonscript.compile"

lfs = require "lfs"

DIR = "locales/"
SOURCE_LOCALE = "en"

import types from require "tableshape"

argparse = require "argparse"

parser = argparse "build_translations.moon", "Build all translations into single file"
parser\option "--source-locale", "Which locale is the default", SOURCE_LOCALE
parser\option "--dir", "Directory to load translation files from", DIR, (str) -> if str\match "/$" then str else "#{str}/"
parser\option "--format", "Output format (lua, json, json_raw)", "lua", types.one_of({"lua", "json", "json_raw"})\transform
parser\flag "--nested", "Nest keys", false
parser\flag "--git", "Insert git hash as comment at top of output (Lua Only)"

args = parser\parse [v for _, v in ipairs arg]

json = require "cjson"

get_git_hash = ->
  -- note this needs to be called from the right directory
  f = io.popen "git rev-parse --short HEAD", "r"
  if revision = f\read "*a"
    revision\match "[^%s]+"

output = { }

flatten_nested = (t, prefix="", out={}) ->
  for k,v in pairs t
    if type(v) == "table"
      flatten_nested v, "#{prefix}#{k}.", out
    else
      out["#{prefix}#{k}"] = v

  out

empty_object = types.equivalent {}

merge_tables = (target, to_merge) ->
  assert type(target) == "table", "target for merge is not table"
  assert type(to_merge) == "table", "table to merge is not table"

  for k, v in pairs to_merge
    if target[k]
      if type(target[k]) == "string"
        error "can't merge into string: #{k}"
      merge_tables target[k], v
    else
      target[k] = v

visit_directory = (dir) ->
  for file in assert lfs.dir dir
    continue if file\match "^%.+$"
    path = "#{dir}#{file}"

    switch lfs.attributes path, "mode"
      when "directory"
        visit_directory "#{path}/"
      when "file"
        name = file\match "^([%w_]+).json$"
        continue unless name
        handle = assert io.open path
        contents = assert handle\read "*a"

        object = json.decode contents

        if empty_object object
          continue

        unless args.nested
          object = flatten_nested object

        if output[name]
          merge_tables output[name], object
        else
          output[name] = object

visit_directory args.dir

-- summarize completion
if args.format == "lua"
  -- remove any plural suffixes
  normalize_key = (key) -> (key\gsub("_%d+$", "")\gsub("_plural$", ""))
  source_translations = assert output[args.source_locale], "missing source locale: #{args.source_locale}"
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
      -- completion_ratio: found / #source_keys
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

switch args.format
  when "json_raw"
    print json.encode output
  when "json"
    local convert_syntax
    convert_syntax = types.one_of {
      types.equivalent({""}) / nil
      types.shape({ types.string }) / (t) -> t[1]
      types.array_of types.one_of {
        types.string
        types.shape({
          variable: types.string
        }, open: true) /  (v) -> {"v", v.variable}

        types.shape({
          tag: types.string
          contents: types.nil + types.proxy -> convert_syntax
        }, open: true) /  (v) -> {"t", v.tag, v.contents}
      }
    }

    import parse_tags from require "helpers.compiler"

    local strings_level
    strings_level = types.map_of types.string, types.one_of {
      types.string / parse_tags\match * convert_syntax
      if args.nested
        types.proxy -> strings_level
    }

    document = types.map_of types.string, strings_level

    print json.encode assert document\transform output
  when "lua"
    if args.git
      print "-- Generated file: commit #{get_git_hash!}"

    print (compile.tree {
      {"return", encode_value output}
    })
  else
    error "unknown format: #{args.format}"
