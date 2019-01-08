#!/bin/bash

printf "Building docs ..."
echo "
# buildenv-omr

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