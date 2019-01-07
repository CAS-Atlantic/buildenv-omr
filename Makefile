OWNER ?= omr_builder
UBUNTU_V ?= "16.04"
GCC_V ?= "4.9"

HOST := $(shell uname -m)
TARGET ?= $(HOST)

OMRDIR ?= $(shell readlink -f ..)

#######################
# this is for building the binaries
DEPENDENCY_BUILD ?= build_dependency
CROSS_BUILD ?= cross_build
NATIVE_BUILD ?= native_build

ifeq ($(TARGET),$(HOST))
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

.PHONY: help clean build $(DEPENDENCY_BUILD) $(CROSS_BUILD) $(NATIVE_BUILD) run docker_build docker_cross_build docker_attach get_toolchain

help:
	@echo -e "\n\
	Usage:\n\
		FLAGS:
			TARGET="target architecture" allows you to change the target architecture to build to 

		CMD:
			build
			$(ARCHES)			To build one of the Docker container for this architecture
			all					To build all the architecture
			clean				delete everything in here
			fresh				delete built binaries
	\n\
	"

fresh:
	rm -Rf $(OMRDIR)/$(DEPENDENCY_BUILD)
	rm -Rf $(OMRDIR)/$(CROSS_BUILD)
	rm -Rf $(OMRDIR)/$(NATIVE_BUILD)

clean: fresh
	git clean -dxf

toolchains:
	mkdir -p toolchains

############################
# aarch64 toolchain depends
AARCH64_TC_TAR_EXT := tar.xz
AARCH64_UNTAR_CMD := xJ
AARCH64_TC := gcc-linaro-$(AARCH64_TOOLCHAIN_VERSION).4-2017.01-x86_64_aarch64-linux-gnu
AARCH64_TC_URL := https://releases.linaro.org/components/toolchain/binaries/$(AARCH64_TOOLCHAIN_VERSION)-2017.01/aarch64-linux-gnu/$(AARCH64_TC).$(AARCH64_TC_TAR_EXT)

toolchains/gcc-aarch64: toolchains
	# build toolchain dependencies
	wget $(AARCH64_TC_URL) -qO- | tar -C toolchains -$(AARCH64_UNTAR_CMD) \
	&& mv toolchains/$(AARCH64_TC) toolchains/gcc-aarch64 \
	&& sed "s/THIS_TARGET_ARCH/aarch64/" cmake.template > toolchains/aarch64.cmake

docker_static_bin:
	@echo "Registering qemu user static"
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

	@echo "Copying the qemu arch static binaries to $@ so that we can add them in the docker file"
	mkdir -p $@
	for ARCH in $(ARCHES); do cp /usr/bin/qemu-$${ARCH}-static $@/; done;
	@echo "done"

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

docker_build: $(TARGET)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN) \
		-v $(OMRDIR):$(OMRDIR) \
		-e OMRDIR=$(OMRDIR) \
		-e INIT_ARGS=build \
		$(OWNER)/$(TARGET)

docker_cross_build: $(HOST)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN) \
		-v $(OMRDIR):$(OMRDIR) \
		-e OMRDIR=$(OMRDIR) \
		-e INIT_ARGS="cross_build TARGET=$(TARGET)" \
		$(OWNER)/$(HOST)

docker_attach: $(TARGET)
	docker run -it \
		--privileged \
		-v /home/$(USER_IN):/home/$(USER_IN) \
		-v $(OMRDIR):$(OMRDIR) \
		-e OMRDIR=$(OMRDIR) \
		-e INIT_ARGS=run \
		$(OWNER)/$(TARGET)
	

#################
# for building the binary
build: $(BUILD_TYPE)

$(NATIVE_BUILD):
	mkdir -p $(OMRDIR)/$(NATIVE_BUILD); \
	cd $(OMRDIR)/$(NATIVE_BUILD); \
	cmake \
		-GNinja \
		$(OMRDIR); \
	ninja

$(DEPENDENCY_BUILD):
	mkdir -p $(OMRDIR)/$(DEPENDENCY_BUILD); \
	cd $(OMRDIR)/$(DEPENDENCY_BUILD); \
	cmake \
		-GNinja \
		$(OMRDIR); \
	ninja

$(CROSS_BUILD): $(DEPENDENCY_BUILD) toolchains/gcc-$(TARGET)
	mkdir -p $(OMRDIR)/$(CROSS_BUILD); \
	cd $(OMRDIR)/$(CROSS_BUILD); \
	export PATH=$(THIS_DIR)/toolchains/gcc-$(TARGET)/bin:$(PATH); \
	cmake \
		-GNinja \
		-DCMAKE_TOOLCHAIN_FILE=$(THIS_DIR)/toolchains/$(TARGET).cmake \
		-DOMR_TOOLS_IMPORTFILE=$(OMRDIR)/$(DEPENDENCY_BUILD)/tools/ImportTools.cmake \
		$(OMRDIR); \
	ninja

run:
	@echo "This is a place holder function, exiting from makefile"



	








