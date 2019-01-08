#!/bin/bash
set -e
[ "_${SOURCE}" == "_" ] && echo "SOURCE is not set exiting" && exit 1
[ "_${DEST}" == "_" ] && echo "DEST is not set exiting" && exit 1

MY_DESTINATION=$( readlink -f ${DEST} )
MY_SOURCE=$( readlink -f ${SOURCE} )
MY_DIR=$( dirname $(readlink -f $0) )

################################
# add the toolchain to the path
if [ "_${TOOLCHAIN}" != "_" ]; then
    [ "_${TARGET_ARCH}" == "_" ] && echo "TARGET_ARCH is not set for cross compilation" && exit 1
    MY_TOOLCHAIN=${TOOLCHAIN}
    MY_TARGET=${TARGET_ARCH}
    unset TARGET_ARCH
    unset TOOLCHAIN

    DEPENDS_DIR="${MY_DESTINATION}/../cross_build_dependency"

    if [ ! -e ${DEPENDS_DIR} ] || [ ! -e "${DEPENDS_DIR}/tools/ImportTools.cmake" ]; then
        mkdir -p ${DEPENDS_DIR} && cd ${DEPENDS_DIR}

        if [ "_$(which ninja | grep -v "not found")" != "_" ]; then
            cmake -GNinja -Wdev "${MY_SOURCE}"
            ninja -v
        else
            cmake -Wdev "${MY_SOURCE}"
            cmake --build .
        fi
    fi;
    
    export PATH="$(echo ${MY_TOOLCHAIN}):${PATH}"
    echo "
    ####### 
    PATH
        ${PATH}
    #######
    "
    sed "s/THIS_TARGET_ARCH/${MY_TARGET}/" ${MY_DIR}/cmake.template > ${MY_DIR}/${MY_TARGET}.cmake

    ##################################
    # build
    mkdir -p ${MY_DESTINATION} && cd ${MY_DESTINATION}
    if [ "_$(which ninja | grep -v "not found")" != "_" ]; then
        cmake \
            -GNinja \
            -Wdev \
            -DCMAKE_TOOLCHAIN_FILE="${MY_DIR}/${MY_TARGET}.cmake" \
            -DOMR_TOOLS_IMPORTFILE="${DEPENDS_DIR}/tools/ImportTools.cmake" \
            "$@" \
            ${MY_SOURCE}
 
        ninja -v
    else
        cmake \
            -Wdev \
            -DCMAKE_TOOLCHAIN_FILE="${MY_DIR}/${MY_TARGET}.cmake" \
            -DOMR_TOOLS_IMPORTFILE="${DEPENDS_DIR}/tools/ImportTools.cmake" \
            "$@" \
            ${MY_SOURCE}

        cmake --build .
    fi
else
    ##################################
    # build
    mkdir -p ${MY_DESTINATION} && cd ${MY_DESTINATION}
    if [ "_$(which ninja | grep -v "not found")" != "_" ]; then
        cmake -GNinja -Wdev "$@" "${MY_SOURCE}"
        ninja -v
    else
        cmake -Wdev "$@" "${MY_SOURCE}"
        cmake --build .
    fi
fi