OWNER ?= omr_builder
UBUNTU_V ?= 16.04
GCC_V ?= 4.9

HOST := $(shell uname -m)
TARGET_ARCH ?= $(HOST)

THIS_DIR := $(shell readlink -f $${PWD} )
OMRDIR ?= $(shell cd .. && readlink -f $${PWD} )

ifeq ($(TARGET_ARCH),$(HOST))
  BUILD_TYPE := native
else
  BUILD_TYPE := cross
endif

ARCHES := x86_64 arm aarch64 i386 ppc64le s390x

UID_IN := $(shell ls -n $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f4)
GID_IN := $(shell ls -n $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f5)
USER_IN := $(shell ls -l $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f4)
GROUP_IN := $(shell ls -l $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f5)

MOUNT_TYPE := shared

.PHONY: help clean build build_native build_cross docker_native docker_cross run docker_run toolchains/gcc-$(TARGET_ARCH) the_docs

help:
	@echo -e "\
	Usage:\n\
		FLAGS:\n\
			TARGET_ARCH=\"target architecture\"      (default: $(TARGET_ARCH))\n\
				allows you to change the target architecture to build to \n\
\n\
			OWNER=\"docker repo\"                    (default: $(OWNER))\n\
				to change the repo the docker images are built to \n\
\n\
			UBUNTU_V=\"ubuntu version number\"       (default: $(UBUNTU_V))\n\
				to change the repo the docker images are built to \n\
\n\
			GCC_V=\"gcc version number\"             (default: $(GCC_V)) \n\
				to change the gcc version, might break so, thread carefully\n\
\n\
			OMRDIR=\"path/to/omr\"                   (default: ../) \n\
				to change the location of the omr root directory \n\
\n\
			BUILD_ROOT_DIR=\"/path/to/base/build\"   (default: OMRDIR/$(BUILD_ROOT_DIR))\n\
				to change the base directory to store all the builds (cross_build, native_build) \n\
\n\
		CMD:\n\
			build	\n\
				build the omr binaries based on the flags\n\
\n\
			docker_build	\n\
				build the omr binaries based on the flags inside a container \n\
\n\
			docker_native	\n\
				build the omr binaries based on the flags inside an architecture native container \n\
\n\
			[$(ARCHES)]	\n\
				To build one of the diplayed Docker container for this architecture\n\
\n\
			all	\n\
				To build all the docker architecture\n\
\n\
			clean \n\
				delete everything in here and do a make fresh\n\
\n\
			fresh \n\
				delete built binaries in $(BUILD_ROOT_DIR)\n\
\n\
			clean_docker \n\
				delete dangling containers and images and volumes\n\
			
			clean_docker
	\n\
	"

fresh:
	rm -Rf $(OMRDIR)/$(BUILD_ROOT_DIR)

clean: fresh
	git clean -dxf -e toolchains

clean_docker:
	@docker rm -v $$(docker ps -a -q) &> /dev/null; \
	docker volume rm $$(docker volume ls -q -f dangling=true) &> /dev/null; \
	docker rmi $$(docker images -f dangling=true) &> /dev/null; \
	echo -e "\nContainers Left -----------\n"; \
	docker ps -a; \
	echo -e "\nVolumes Left -----------\n"; \
	docker volume ls; \
	echo -e "\nImages Left -----------\n"; \
	docker images

docker_static_bin:
	@echo "Registering qemu user static"
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

	@echo "Copying the qemu arch static binaries to $@ so that we can add them in the docker file"
	mkdir -p $@
	for ARCH in $(ARCHES); do cp /usr/bin/qemu-$${ARCH}-static $@/; done;
	@echo "done"

toolchains/gcc-$(TARGET_ARCH):
	cd toolchains && ./get_$(TARGET_ARCH)_toolchain.sh

x86_64.Dockerfile: Dockerfile.template
	sed "s/THIS_DOCKER_ARCH/amd64/" Dockerfile.template > $@

i386.Dockerfile: Dockerfile.template	
	sed "s/THIS_DOCKER_ARCH/i386/" Dockerfile.template > $@

arm.Dockerfile: Dockerfile.template
	sed "s/THIS_DOCKER_ARCH/arm32v7/" Dockerfile.template > $@

aarch64.Dockerfile: Dockerfile.template
	sed "s/THIS_DOCKER_ARCH/arm64v8/" Dockerfile.template > $@

s390x.Dockerfile: Dockerfile.template
	sed "s/THIS_DOCKER_ARCH/s390x/" Dockerfile.template > $@

ppc64le.Dockerfile: Dockerfile.template
	sed "s/THIS_DOCKER_ARCH/ppc64le/" Dockerfile.template > $@

# Build the docker environment
$(ARCHES): docker_static_bin
	$(MAKE) $@.Dockerfile
	sed -i "s/THIS_UBUNTU_V/$(UBUNTU_V)/g" $@.Dockerfile
	sed -i "s/THIS_GCC_VERSION/$(GCC_V)/g" $@.Dockerfile
	sed -i "s/THIS_GROUP/$(GROUP_IN)/g"  $@.Dockerfile
	sed -i "s/THIS_GID/$(GID_IN)/g"  $@.Dockerfile
	sed -i "s/THIS_USER/$(USER_IN)/g"  $@.Dockerfile
	sed -i "s/THIS_UID/$(UID_IN)/g"  $@.Dockerfile

	[ "$@" == "$(HOST)" ] \
	&&	sed -i "/THIS_QEMU_ARCH/d" $@.Dockerfile \
	||	sed -i "s/THIS_QEMU_ARCH/$@/g" $@.Dockerfile;

	docker build \
		-t $(OWNER)/$@ \
		-f $@.Dockerfile \
		.

all: $(ARCHES)

build: build_$(BUILD_TYPE)

docker_build: docker_$(BUILD_TYPE)

######################
# using docker build environement
docker_native: $(TARGET_ARCH)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN):$(MOUNT_TYPE) \
		-v $(OMRDIR):$(OMRDIR):$(MOUNT_TYPE) \
		-v /etc/passwd:/etc/passwd:ro,$(MOUNT_TYPE) \
		-e OMRDIR=$(OMRDIR) \
		-e BUILDER_DIR=$(THIS_DIR) \
		-e TARGET_ARCH=$(TARGET_ARCH) \
		-e MAKE_CMD=build \
		$(OWNER)/$(TARGET_ARCH)

docker_cross: $(HOST)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN):$(MOUNT_TYPE) \
		-v $(OMRDIR):$(OMRDIR):$(MOUNT_TYPE) \
		-v /etc/passwd:/etc/passwd:ro,$(MOUNT_TYPE) \
		-e OMRDIR=$(OMRDIR) \
		-e BUILDER_DIR=$(THIS_DIR) \
		-e TARGET_ARCH=$(TARGET_ARCH) \
		-e MAKE_CMD=build \
		$(OWNER)/$(HOST) \
		/bin/bash /init_script.sh

# attach to other container for cross build
	$(MAKE) docker_run \
		OMRDIR=$(OMRDIR) \
		BUILDER_DIR=$(THIS_DIR) \
		TARGET_ARCH=$(TARGET_ARCH)

############################
# runners 
docker_run: $(TARGET_ARCH)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN):$(MOUNT_TYPE) \
		-v $(OMRDIR):$(OMRDIR):$(MOUNT_TYPE) \
		-v /etc/passwd:/etc/passwd:ro,$(MOUNT_TYPE) \
		-e OMRDIR=$(OMRDIR) \
		-e BUILDER_DIR=$(THIS_DIR) \
		-e TARGET_ARCH=$(TARGET_ARCH) \
		-e MAKE_CMD=run \
		$(OWNER)/$(TARGET_ARCH)

######################
# using local build environement
build_native:
	mkdir -p $(OMRDIR)/build/native_build
	export SOURCE=$(OMRDIR) &&\
	export DEST=$(OMRDIR)/build/native_build &&\
	$(THIS_DIR)/buildOMR.sh -C$(THIS_DIR)/compile_target.cmake

build_cross: toolchains/gcc-$(TARGET_ARCH)
	mkdir -p $(OMRDIR)/build/cross_build
	export SOURCE=$(OMRDIR) &&\
	export DEST=$(OMRDIR)/build/cross_build &&\
	export TOOLCHAIN=$(THIS_DIR)/toolchains/gcc-$(TARGET_ARCH)/bin &&\
	$(THIS_DIR)/buildOMR.sh -C$(THIS_DIR)/compile_target.cmake
		
# attach to other container for cross build
	$(MAKE) docker_run TARGET_ARCH=$(TARGET_ARCH) OMRDIR=$(OMRDIR)

run:
	@echo "----------------------------"
	@echo "This is a place holder function your builds are located at $(OMRDIR)/$(BUILD_ROOT_DIR)"
	@echo "----------------------------"
	@echo "-------exiting from makefile"

the_docs:
	$(THIS_DIR)/build_docs.sh



	








