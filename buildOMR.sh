#!/bin/bash

################################
# add the toolchain to the path
for tc in toolchains/gcc-*
do 
    export PATH="${tc}/bin:${PATH}"
    echo ${tc} to PATH
done
echo ${PATH}

if [ "_$(which ninja | grep -v "not found")" != "_" ]; then
    exit (cmake -GNinja -Wdev "$@" && ninja -v)
else
    exit (cmake -Wdev "$@" && cmake --build .)
fi


