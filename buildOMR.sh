#!/bin/bash
set -e

help_me () {
EXIT_CODE=$1
shift
echo "$@
    Usage:

        $0 [cmake extra args] ... 

        Necessary Variables:

            SOURCE=\"path/to/omr/source

            DEST=\"path/to/omr/build/directory\"

        To cross compile set 

            TOOLCHAIN=\"path/to/toolchain/bin\"
                This script will pick up the first *-g++ in the directory and request it's triplet

        N.B when cross compiling we build the native architecture depency @ \${DEST}/../cross_build_dependency
"
exit $EXIT_CODE
}

[ "_$1" == "_help" ]    && help_me 0
[ "_${SOURCE}" == "_" ] && help_me 1 "ERROR: SOURCE is not set exiting"
[ "_${DEST}" == "_" ]   && help_me 1 "ERROR: DEST is not set exiting"

MY_DESTINATION=$( readlink -f ${DEST} )
MY_SOURCE=$( readlink -f ${SOURCE} )
MY_DIR=$( dirname $(readlink -f $0) )
mkdir -p ${MY_DESTINATION} && cd ${MY_DESTINATION}

################################
# add the toolchain to the path
if [ "_${TOOLCHAIN}" != "_" ]; then
    export PATH="$(echo ${TOOLCHAIN}):${PATH}"
    MY_TARGET_TRIPLET=$( $(find ${TOOLCHAIN} -name "*-g++") -dumpmachine)  
    MY_TARGET=$(echo ${MY_TARGET_TRIPLET} | cut -d '-' -f 1)
    unset TOOLCHAIN

    DEPENDS_DIR="${MY_DESTINATION}/../cross_build_dependency"

    if [ ! -e ${DEPENDS_DIR} ] \
    || [ ! -e "${DEPENDS_DIR}/tools/ImportTools.cmake" ] \
    || [ ! -e "${DEPENDS_DIR}/tools/hookgen/hookgen" ] \
    || [ ! -e "${DEPENDS_DIR}/tools/tracegen/tracegen" ] \
    || [ ! -e "${DEPENDS_DIR}/tools/tracemerge/tracemerge" ]
    then
        rm -r ${DEPENDS_DIR} || true
        mkdir -p ${DEPENDS_DIR} && cd ${DEPENDS_DIR}

        if [ "_$(which ninja | grep -v "not found")" != "_" ]; then
            cmake -GNinja -Wdev "${MY_SOURCE}"
            ninja -v
        else
            cmake -Wdev "${MY_SOURCE}"
            cmake --build .
        fi
    fi;
    sed "s/THIS_TARGET_ARCH/${MY_TARGET}/g" ${MY_DIR}/cmake.template > ${MY_DIR}/${MY_TARGET}.cmake
    sed -i "s/THIS_TARGET_TRIPLE/${MY_TARGET_TRIPLET}/g" ${MY_DIR}/${MY_TARGET}.cmake

    ##################################
    # build
    cd ${MY_DESTINATION}
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