OWNER ?= omr_builder
UBUNTU_V ?= "16.04"
GCC_V ?= "4.9"

HOST := $(shell uname -m)
TARGET_ARCH ?= $(HOST)

WITH_DOCKER ?= false
OMRDIR ?= $(shell readlink -f ..)

#######################
# this is for building the binaries
BUILD_ROOT_DIR ?= build
CROSS_BUILD ?= $(BUILD_ROOT_DIR)/cross_build
NATIVE_BUILD ?= $(BUILD_ROOT_DIR)/native_build

ifeq ($(TARGET_ARCH),$(HOST))
  BUILD_TYPE := $(NATIVE_BUILD)
else
  BUILD_TYPE := $(CROSS_BUILD)
endif

#######################
# this is for the toolchain try to match gcc_v with version
AARCH64_TOOLCHAIN_VERSION := 4.9

ARCHES := x86_64 arm aarch64 i386 ppc64le s390x

THIS_DIR := $(shell readlink -f .)
UID_IN := $(shell ls -n $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f4)
GID_IN := $(shell ls -n $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f5)
USER_IN := $(shell ls -l $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f4)
GROUP_IN := $(shell ls -l $(OMRDIR) | grep OmrConfig.cmake | cut -d ' ' -f5)

.PHONY: help clean build docker_$(CROSS_BUILD) docker_$(NATIVE_BUILD) run docker_run toolchains/gcc-$(TARGET_ARCH)

help:
	@echo -e "\n\
	Usage:\n\
		FLAGS:
			TARGET_ARCH="target architecture" allows you to change the target architecture to build to 

		CMD:
			build
			$(ARCHES)			To build one of the Docker container for this architecture
			all					To build all the architecture
			clean				delete everything in here
			fresh				delete built binaries
			patch_aarch64		this patches aarch64 to build only jitbuilder
	\n\
	"

fresh:
	rm -Rf $(BUILD_ROOT_DIR)
	rm -Rf $(OMRDIR)/$(NATIVE_BUILD)

clean: fresh
	git clean -dxf -e toolchains/gcc_

docker_static_bin:
	@echo "Registering qemu user static"
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

	@echo "Copying the qemu arch static binaries to $@ so that we can add them in the docker file"
	mkdir -p $@
	for ARCH in $(ARCHES); do cp /usr/bin/qemu-$${ARCH}-static $@/; done;
	@echo "done"

toolchains/gcc-$(TARGET_ARCH):
	toolchains/get_$(TARGET_ARCH)_toolchain.sh

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
	||	sed -i "s/THIS_QEMU_ARCH/docker_static_bin\/qemu-$@-static/g" $@.Dockerfile;

	docker build \
		-t $(OWNER)/$@ \
		-f $@.Dockerfile \
		.

all: $(ARCHES)

build: $(OMRDIR)/$(BUILD_TYPE)

docker_build: docker_$(BUILD_TYPE)

######################
# using docker build environement
docker_$(NATIVE_BUILD): $(TARGET_ARCH)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN) \
		-v $(OMRDIR):$(OMRDIR) \
		-e OMRDIR=$(OMRDIR) \
		-v /etc/passwd:/etc/passwd \
		-e INIT_ARGS="$(OMRDIR)/$(NATIVE_BUILD) OMRDIR=$(OMRDIR); cd $(OMRDIR)/$(NATIVE_BUILD)" \
		$(OWNER)/$(TARGET_ARCH)

docker_$(CROSS_BUILD): $(HOST)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN) \
		-v $(OMRDIR):$(OMRDIR) \
		-e OMRDIR=$(OMRDIR) \
		-v /etc/passwd:/etc/passwd \
		$(OWNER)/$(HOST) \
		/bin/bash -c 'cd $(THIS_DIR) && make $(OMRDIR)/$(CROSS_BUILD) TARGET_ARCH=$(TARGET_ARCH) OMRDIR=$(OMRDIR)'

# attach to other container for cross build
	$(MAKE) docker_run TARGET_ARCH=$(TARGET_ARCH) OMRDIR=$(OMRDIR)

############################
# runners 
docker_run: $(TARGET_ARCH)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN) \
		-v /etc/passwd:/etc/passwd \
		-v $(OMRDIR):$(OMRDIR) \
		-e OMRDIR=$(OMRDIR) \
		-e INIT_ARGS="run ; cd $(CROSS_BUILD)" \
		$(OWNER)/$(TARGET_ARCH)

######################
# using local build environement
$(OMRDIR)/$(NATIVE_BUILD):
	export SOURCE=$(OMRDIR) &&\
	export DEST=$(OMRDIR)/$(NATIVE_BUILD) &&\
	$(THIS_DIR)/buildOMR.sh -C$(THIS_DIR)/compile_target.cmake

$(OMRDIR)/$(CROSS_BUILD): toolchains/gcc-$(TARGET_ARCH)
	export SOURCE=$(OMRDIR) &&\
	export DEST=$(OMRDIR)/$(CROSS_BUILD) &&\
	export TOOLCHAIN=$(THIS_DIR)/toolchains/gcc-$(TARGET_ARCH)/bin &&\
	export TARGET_ARCH=$(TARGET_ARCH) &&\
	$(THIS_DIR)/buildOMR.sh -C$(THIS_DIR)/compile_target.cmake
		
# attach to other container for cross build
	$(MAKE) docker_run TARGET_ARCH=$(TARGET_ARCH) OMRDIR=$(OMRDIR)

run:
	@echo "This is a place holder function, exiting from makefile"



	








