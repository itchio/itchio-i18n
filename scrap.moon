

import parse_tags, compile_to_lua from require "helpers.compiler"


require("moon").p parse_tags\match "To log in, <a>click here</a> and type your password"

print compile_to_lua "To log in, <a>click here</a> and type your password"

