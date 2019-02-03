#!/bin/bash
set -e
set -o pipefail
set -o xtrace

# setup lua
luarocks-5.1 install moonscript
luarocks-5.1 install lua-cjson
luarocks-5.1 install tableshape
luarocks-5.1 install luafilesystem
eval $(luarocks-5.1 path)

cat $(which busted) | sed 's/\/usr\/bin\/lua5\.1/\/usr\/bin\/luajit/' > busted
chmod +x busted

./busted -o utfTerminal