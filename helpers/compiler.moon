-- this compiles translation strings into lua functions for fast
-- interpolation. compiled functions write to the buffer via passed functions


import trim from require "lapis.util"
import P, S, Cmt, Cp, Cg, Cb, Ct, C from require "lpeg"
import types from require "tableshape"

-- parses translation string for tags and interpolations
parse_tags = do
  open_tag = P"<" * Cg((1 - S"/>")^1, "tag_name") * P">"

  -- support {{x}} and %{x} syntax
  variable = P"{{" * C((1 - P"}}")^1) * P"}}" / (v) -> { variable: trim(v) }
  variable += P"%{" * C((1 - P"}")^1) * P"}" / (v) -> { variable: trim(v) }

  tag = Cmt Ct(open_tag), (s, pos, opts) ->
    rest = s\sub pos
    stop = P("</#{opts.tag_name}>") * Cp!
    until_stop = C((P(1) - stop)^0) * stop
    contents, after = until_stop\match rest

    unless contents
      return nil, after

    parsed_contents, err = parse_tags\match contents
    unless parsed_contents
      return nil, err

    after + pos - 1, {
      tag: opts.tag_name
      raw_contents: contents
      contents: parsed_contents
    }

  Ct P(-1) / "" + (C((P(1) - open_tag - variable)^1) + tag + variable)^0 * P(-1)


-- convertes parsed tree to lua syntax node
chunk_to_syntax = do
  tag_op_shape = types.shape {
    contents: types.table
    tag: types.string
  }, open: true

  variable_op_shape = types.shape { variable: types.string }, open: true

  simple_value = types.one_of { types.string, variable_op_shape }

  -- this tag can have value passed directly as argument
  simple_tag = types.shape {
    contents: types.shape { simple_value }
  }, open: true

  node_for_value = types.one_of {
    types.string / (s) ->
      {"string", '"', "%q"\format(s)\sub(2, -2) }

    variable_op_shape / (op) ->
      {
        "chain"
        {"ref", "variables"}
        {"dot", op.variable}
      }
  }

  (op) ->
    if n = node_for_value\transform op
      return {
        "chain"
        {"ref", "text_fn"}
        {"call", {n}}
      }

    if tag_op_shape op
      arg = if simple_tag op
        assert node_for_value\transform op.contents[1]
      else
        lines = [node_for_op child_op for child_op in *op.contents]
        if next lines
          {"fndef", {}, {}, "slim", lines}
        else
          nil

      return {
        "chain"
        {"ref", "variables"}
        {"dot", op.tag}
        {"call", {arg}}
      }

-- convert translations string to standalone lua function
compile_to_lua = (t) ->
  if type(t) == "string"
    t = assert parse_tags\match t

  { tree: compile_tree } = require "moonscript.compile"

  nodes = {
    {"assign", {"text_fn", "variables"}, {"..."}}
  }

  for chunk in *t
    table.insert nodes, chunk_to_syntax chunk

  (compile_tree nodes, implicitly_return_root: false)


compile = (t) ->
  code = assert compile_to_lua t
  loadstring(code)

{:parse_tags, :chunk_to_syntax, :compile_to_lua, :compile}
