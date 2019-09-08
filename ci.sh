#!/bin/bash
set -e
set -o pipefail
set -o xtrace

# setup lua
luarocks --lua-version=5.1 install moonscript
luarocks --lua-version=5.1 install lua-cjson
luarocks --lua-version=5.1 install tableshape
luarocks --lua-version=5.1 install luafilesystem
eval $(luarocks --lua-version=5.1 path)

cat $(which busted) | sed 's/\/usr\/bin\/lua5\.1/\/usr\/bin\/luajit/' > busted
chmod +x busted

./busted -o utfTerminal