#!/bin/bash

################################
# add the toolchain to the path
for tc in toolchains/gcc-*
do 
    export PATH="${tc}/bin:${PATH}"
    echo ${tc} to PATH
done
echo ${PATH}

exit (cmake -GNinja -Wdev "$@" && ninja -v)


