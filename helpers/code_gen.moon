

find_variables = (syntax, vars={}) ->
  for node in *syntax
    if type(node) == "table"
      if node.variable
        vars[node.variable] = "simple"

      if node.tag
        vars[node.tag] = "function"
        find_variables node.contents, vars

  vars


string_to_code = (key, text) ->
  import parse_tags from require "helpers.compiler"
  syntax = parse_tags\match text

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


{:string_to_code, :find_variables}
