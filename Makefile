export LUET?=$(shell which luet)
export ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
ISO_SPEC?=$(ROOT_DIR)/iso.yaml
CLEAN?=false
export TREE?=$(ROOT_DIR)/packages

BUILD_ARGS?=--pull --no-spinner --only-target-package --live-output
VALIDATE_OPTIONS?=-s
REPO_CACHE?=raccos/sampleos
PULL_REPOS?=raccos/opensuse
FINAL_REPO?=raccos/releases-sampleos

PACKAGES?=system/sampleOS
HAS_LUET := $(shell command -v luet 2> /dev/null)
PUBLISH_ARGS?=
ISO?=$(ROOT_DIR)/$(shell ls *.iso)

export REPO_CACHE
ifneq ($(strip $(REPO_CACHE)),)
	BUILD_ARGS+=--image-repository $(REPO_CACHE)
endif

export PULL_REPOS
ifneq ($(strip $(PULL_REPOS)),)
	BUILD_ARGS+=$(shell printf -- "--pull-repository %s " $(PULL_REPOS))
endif

all: deps build

deps:
ifndef HAS_LUET
ifneq ($(shell id -u), 0)
	@echo "You must be root to perform this action."
	exit 1
endif
	cd /tmp && curl https://get.mocaccino.org/luet/get_luet_root.sh | sh
	cd /tmp && luet install -y extension/makeiso
endif

clean:
	 rm -rf $(ROOT_DIR)/build $(ROOT_DIR)/.qemu $(ROOT_DIR)/*.iso $(ROOT_DIR)/*.sha256

.PHONY: build
build:
	$(LUET) build $(BUILD_ARGS) \
	--destination $(ROOT_DIR)/build \
	--from-repositories $(PACKAGES)

create-repo:
	$(LUET) create-repo \
	--output $(ROOT_DIR)/build \
	--name "sampleOS" \
	--from-repositories 

publish-repo:
	$(LUET) create-repo $(PUBLISH_ARGS) \
	--output $(FINAL_REPO) \
	--name "sampleOS" \
	--from-repositories \
	--push-images \
	--type docker

validate:
	$(LUET) tree validate $(VALIDATE_OPTIONS)

# ISO
iso: create-repo
	$(LUET)-makeiso $(ISO_SPEC) --local $(ROOT_DIR)/build