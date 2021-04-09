export LUET?=$(shell which luet)
export ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
ISO_SPEC?=$(ROOT_DIR)/iso/sampleOS.yaml
CLEAN?=false
export TREE?=$(ROOT_DIR)/packages

BUILD_ARGS?=--pull --no-spinner --only-target-package --live-output
FLAVOR?=opensuse
VALIDATE_OPTIONS?=-s
DESTINATION?=$(ROOT_DIR)/build
REPO_CACHE?=raccos/sampleos
PULL_REPOS?=raccos/$(FLAVOR) raccos/sampleos
FINAL_REPO?=raccos/releases-sampleos

PACKAGES?=$(shell yq r -j $(ISO_SPEC) 'packages.[*]' | jq -r '.[]' | sort -u)
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
	curl https://get.mocaccino.org/luet/get_luet_root.sh |  sh
	luet install -y repository/mocaccino-extra-stable
	luet install -y utils/jq utils/yq system/luet-devkit
endif

clean:
	 rm -rf $(DESTINATION) $(ROOT_DIR)/.qemu $(ROOT_DIR)/*.iso $(ROOT_DIR)/*.sha256

.PHONY: build
build:
	$(LUET) build $(BUILD_ARGS) \
	--values $(ROOT_DIR)/packages/cOS/values/$(FLAVOR).yaml \
	--tree=$(TREE) $(PACKAGES) \
	--destination $(DESTINATION)

create-repo:
	$(LUET) create-repo --tree "$(TREE)" \
    --output $(DESTINATION) \
    --packages $(DESTINATION) \
    --name "sampleOS" \
    --descr "sampleOS $(FLAVOR)" \
    --urls "" \
    --tree-filename tree.tar \
    --type http

publish-repo:
	$(LUET) create-repo $(PUBLISH_ARGS) --tree "$(TREE)" \
    --output $(FINAL_REPO) \
    --packages $(DESTINATION) \
    --name "sampleOS" \
    --descr "sampleOS $(FLAVOR)" \
    --urls "" \
    --tree-filename tree.tar \
    --push-images \
    --type docker

validate:
	$(LUET) tree validate --tree $(TREE) $(VALIDATE_OPTIONS)

# ISO

$(DESTINATION):
	mkdir $(DESTINATION)

$(DESTINATION)/conf.yaml: $(DESTINATION)
	touch $(ROOT_DIR)/build/conf.yaml
	yq w -i $(ROOT_DIR)/build/conf.yaml 'repositories[0].name' 'sampleOS'
	yq w -i $(ROOT_DIR)/build/conf.yaml 'repositories[0].enable' true

local-iso: create-repo $(DESTINATION)/conf.yaml
	yq w -i $(DESTINATION)/conf.yaml 'repositories[0].urls[0]' $(DESTINATION)
	yq w -i $(DESTINATION)/conf.yaml 'repositories[0].type' 'disk'
	$(LUET) geniso-isospec $(ISO_SPEC)

iso: $(DESTINATION)/conf.yaml
	yq w -i $(DESTINATION)/conf.yaml 'repositories[0].type' 'docker'
	yq w -i $(DESTINATION)/conf.yaml 'repositories[0].urls[0]' $(FINAL_REPO)
	$(LUET) geniso-isospec $(ISO_SPEC)
