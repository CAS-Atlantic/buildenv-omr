#!/bin/bash

printf "Building docs ..."
echo "
# buildenv-omr

to use, clone this repo recursively (it uses submodules) 
inside the omr root directory 
N.B git ignores other git repos so you don't have to worry about this getting commited

to clone use 
\`\`\`
git clone --recursive
\`\`\`

refer to Makefile Usage for instruction on it's use

## Dependency

### For building using docker
    Docker:
        see https://docs.docker.com/install/linux/docker-ce/ubuntu/

    qemu-user-static:
        see you package manager
        ubuntu: qemu-user-static

### For building localy

    tar
    xz
    
    if ninja-build is provided we will use it 
    
## Makefile Usage
\`\`\`
$(make -s help)
\`\`\`
## buildOMR.sh wrapper Usage

NB. it is recommended you use the make file since it wraps all the script needs in one tidy package
\`\`\`
$(./buildOMR.sh help)
\`\`\`
## Other
" > README.md

sleep 1
echo "Done"
