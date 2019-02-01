import trim from require "lapis.util"
import shell_escape from require "lapis.cmd.path"

dmenu = (prompt, options) ->
  pre = if options
    "'#{shell_escape table.concat options, "\n"}'"
  else
    ''

  cmd = "echo -n #{pre} | dmenu -i -l 20 -p '#{shell_escape prompt}' -fn 'xos4 Terminus-16'"
  f = assert io.popen cmd
  trim f\read("*all")


{:dmenu}
