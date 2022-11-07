import trim from require "lapis.util"
import shell_escape from require "lapis.cmd.path"

dmenu = (prompt, options) ->
  options_data = if options
    table.concat options, "\n"
  else
    ''

  menu_command = "dmenu -i -l 20 -p '#{shell_escape prompt}' -fn 'xos4 Terminus-16'"

  -- example of using rofi:
  -- shell_escape prompt menu_command = "rofi -location 2 -theme-str 'window { width:100%;}' -dmenu -p '#{shell_escape prompt}'"

  -- we have to use a temp file since it's too big to be written into popen
  -- command
  input_fname = assert os.tmpname!
  input_file = assert io.open input_fname, "w"
  input_file\write options_data
  input_file\close!

  f = assert io.popen "cat '#{shell_escape input_fname}' | #{menu_command}"
  with trim f\read("*all")
    os.remove input_fname

{:dmenu}
