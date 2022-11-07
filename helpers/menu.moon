import trim from require "lapis.util"
import shell_escape from require "lapis.cmd.path"

dmenu = (prompt, options) ->
  options_data = if options
    table.concat options, "\n"
  else
    ''

  -- we have to use a temp file since it's too big to be written into popen
  -- command
  input_fname = assert os.tmpname!
  input_file = assert io.open input_fname, "w"
  input_file\write options_data
  input_file\close!

  cmd = "cat '#{shell_escape input_fname}' | dmenu -i -l 20 -p '#{shell_escape prompt}' -fn 'xos4 Terminus-16'"
  f = assert io.popen cmd
  with trim f\read("*all")
    os.remove input_fname

{:dmenu}
