-- generates lua file containing all the translations

compile = require "moonscript.compile"

lfs = require "lfs"

DIR = "locales/"

json = require "cjson"

output = { }

for file in assert lfs.dir DIR
  continue if file\match "^%.+$"
  name = file\match "^(%w+).json$"
  continue unless name
  handle = assert io.open "#{DIR}/#{file}"
  contents = assert handle\read "*a"

  object = json.decode contents
  output[name] = object

encode_value = (v) ->
  switch type(v)
    when "number"
      {"number", v}
    when "table"
      keys = [k for k in pairs v]
      table.sort keys
      {"table", for k in *keys
        k = tostring k

        {
          if k\match "%."
            {"string", '"', k}
          else
            {"key_literal", k}

          encode_value(v[k])
        }
      }

    else
      str = tostring v

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
