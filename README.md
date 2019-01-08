
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
```

```
## buildOMR.sh wrapper Usage

NB. it is recommended you use the make file since it wraps all the script needs in one tidy package
```

    Usage:

        ./buildOMR.sh [cmake extra args] ... 

        Necessary Variables:

            SOURCE="path/to/omr/source

            DEST="path/to/omr/build/directory"

        To cross compile set 

            TOOLCHAIN="path/to/toolchain/bin"
                This script will pick up the first *-g++ in the directory and request it's triplet

        N.B when cross compiling we build the native architecture depency @ ${DEST}/../cross_build_dependency
```
## Other

