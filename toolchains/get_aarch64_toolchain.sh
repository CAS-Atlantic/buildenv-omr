#!/bin/bash

set -e 

############################
# aarch64 toolchain depends
TAR_EXT=tar.xz
UNTAR_CMD=xJ
TOOLCHAIN=gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu
URL=https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/aarch64-linux-gnu/${TOOLCHAIN}.${TAR_EXT}

# build toolchain dependencies
if [ ! -d gcc-aarch64 ]; then
    wget ${URL} -qO- | tar -${UNTAR_CMD} \
    && mv ${TOOLCHAIN} gcc-aarch64
fi