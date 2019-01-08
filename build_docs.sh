#!/bin/bash

printf "Building docs ..."
echo "
# buildenv-omr

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