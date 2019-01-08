
# buildenv-omr

## Dependency

### For building using docker
    Docker:
        see https://docs.docker.com/install/linux/docker-ce/ubuntu/

    qemu-user-static:
        see you package manager
        ubuntu: qemu-user-static

### For building localy

    if ninja-build is provided we will use it 
    
## Makefile Usage
```
Usage:
	FLAGS:
		TARGET_ARCH="target architecture"      (default: x86_64)
			allows you to change the target architecture to build to 

		OWNER="docker repo"                    (default: omr_builder)
			to change the repo the docker images are built to 

		UBUNTU_V="ubuntu version number"       (default: 16.04)
			to change the repo the docker images are built to 

		GCC_V="gcc version number"             (default: 4.9) 
			to change the gcc version, might break so, thread carefully

		OMRDIR="path/to/omr"                   (default: ../) 
			to change the location of the omr root directory 

		BUILD_ROOT_DIR="/path/to/base/build"   (default: OMRDIR/build)
			to change the base directory to store all the builds (cross_build, native_build) 

	CMD:
		build	
			build the omr binaries based on the flags

		[x86_64 arm aarch64 i386 ppc64le s390x]	
			To build one of the diplayed Docker container for this architecture

		all	
			To build all the docker architecture

		clean 
			delete everything in here and do a make fresh

		fresh 
			delete built binaries in build
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

