# SampleOS

SampleOS is a dummy example of a derivate system built with containerOS-toolkit (**cOS-toolkit**).
The purpose of this repository is moslty to showcase and demonstrate how to
extend and customize containerOS using its own toolkit.

cOS is built from containers, and completely hosted on image registries. The
build process results in a single container image used to deliver regular
upgrades in OTA approach. Refer to [**cOS project**](https://github.com/rancher-sandbox/cOS-toolkit) for further details
regarding the toolkit or the base cOS system.

This SampleOS only includes a dummy http service on top of the cOS base that
listens to `http://<IP>:8090/fortuneteller` which is enabled through a
cloud-init configuration ([10_sampleOSService.yaml](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/packages/sampleOSService/10_sampleOSService.yaml)) applied at
boot time the over the ephemeral `/etc`.

<!-- TOC -->

- [SampleOS](#sampleos)
    - [Quick start](#quick-start)
    - [Build SampleOS With docker](#build-sampleos-with-docker)
    - [Build SampleOS Locally](#build-sampleos-locally)
        - [Install build dependencies.](#install-build-dependencies)
        - [Build the actual sampleOS root tree](#build-the-actual-sampleos-root-tree)
        - [Create an ISO with the built root tree from SampleOS](#create-an-iso-with-the-built-root-tree-from-sampleos)
    - [Manual build without Makefile targets](#manual-build-without-makefile-targets)
        - [Install OS dependencies for ISO building](#install-os-dependencies-for-iso-building)
        - [Install luet and its extensions](#install-luet-and-its-extensions)
        - [Build the SampleOS root tree](#build-the-sampleos-root-tree)
        - [Create the local repository](#create-the-local-repository)
        - [Generate the ISO](#generate-the-iso)
    - [System upgrades](#system-upgrades)
    - [Build cache](#build-cache)
    - [Repository layout](#repository-layout)

<!-- /TOC -->

## Quick start

Download the ISO (see actions [artifacts](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/actions)) and boot it with the hipervisor of
your choice. The ISO can be simply boot using KVM with the following commands:

```bash
# create a virtual disk of 20G
$ qemu-img create -f raw test.img 20G

# Run a VM with the ISO
$ qemu-kvm -m 2048 -cdrom sampleOS-0.20210415.iso -hda test.img
```

Default root password is set to `sampleos` on in [04_accounting.yaml](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/packages/sampleOS/04_accounting.yaml), then, after loging into the VM, you can check SampleService by typing:

```bash
# Service status
systemctl status sampleservice

# Check is up and running properly
curl -L http://localhost:8090/fortuneteller
```

## Build SampleOS With docker

cOS has a docker image which can be used to build cOS locally in order to generate the cOS packages and the cOS iso from your checkout.

From your git folder, use the `.envrc` file:

```bash
$> source .envrc
$> cos-build
```

or manually:

```bash
$> docker build -t cos-builder .
$> docker run --privileged=true \
   --rm -v /var/run/docker.sock:/var/run/docker.sock \
   -v $PWD:/cOS cos-builder
```

## Build SampleOS Locally

SampleOS can be build locally by using the following make targets.

### 1. Install build dependencies.

```bash
# Install toolchain dependencies (luet, luet-makeiso)
$ sudo make deps
```

### 2. Build the actual sampleOS root tree

```bash
# Builds all the packages of the repository
$ sudo make build
```

### 3. Create an ISO with the built root tree from SampleOS

```bash
# Creates a local repo and builds an ISO using the local repository
# on top of the raccos/realeases-cos docker repository
$ sudo make local-iso
```

## Manual build without Makefile targets

The sampleOS relies on [**luet**](https://luet-lab.github.io/docs/) for the build, in fact this is the
core of the toolchain. Consider running the following commands to build SampleOS.

### 1. Install OS dependencies for ISO building

- squashfs
- xorriso

```bash
# Install packages for openSUSE
zypper in squashfs xorriso
```

### 2. Install luet and its extensions

```bash
# Installing Luet (or grab a release from https://github.com/mudler/luet/releases )
$ curl https://get.mocaccino.org/luet/get_luet_root.sh |  sh

# Install luet makeiso for iso creation (or grab a release from https://github.com/mudler/luet-makeiso/releases )
$ sudo luet install -y extension/makeiso
```

### 3. Build the SampleOS root tree

```bash
$ sudo luet build --only-target-package --pull --image-repository raccos/sampleos \
     --tree packages --from-repositories system/sampleOS
```

Where:
- **--only-target-package**: tells that we will just need to build `system/sampleOS`, and not its dependencies
- **--pull**: Enable reusal of the `cos-toolkit` image caches
- **--image-repository**: Is where our resulting caches images are named after. Combined with `--push` it allows to push all the images used during build. It is optional
- **--tree**: A path where the specfiles are, in this case `packages`. Defaults to current working directory
- **--from-repositories**: Allow to resolve package dependencies compilation specs from remote repositories (see `.luet.yaml`)

The resulting artifacts will be available in `build/`. You can tweak the output folder with the `--destination` flag.

### 4. Create the local repository

```bash
$ luet create-repo --tree packages --name sampleOS --from-repositories
```

### 5. Generate the ISO

```bash
$ sudo luet-makeiso iso.yaml --local build
```

## System upgrades

The sampleOS derivative install can be upgraded in two ways:

- by running `cos-upgrade` and attaching to the standard upgrade channel (default)
- by running `cos-upgrade <container_image>` to upgrade to a specific container image


To push the images required for upgrades via standard channel upgrades, pass the `--push-images --type docker --output <image reference>` to `luet create-repo`.

The same image reference needs to be annotated [here](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/7355876847367b75485873987e1217f1e1fe6254/packages/sampleOS/02_upgrades.yaml#L37) so calling `cos-upgrade` will automatically pull from the container image.

_Note:_ You can also run `make FINAL_REPO=<image_reference> publish-repo`, which automatically pushes the images to `raccos/releases-sampleos`.

To push upgrades by image tags ( e.g. pointing at `foo/bar:latest` ), set [CHANNEL_UPGRADES](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/7355876847367b75485873987e1217f1e1fe6254/packages/sampleOS/02_upgrades.yaml#L50) to `false` in `/etc/cos-upgrade-image` and provide a default [UPGRADE_IMAGE](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/7355876847367b75485873987e1217f1e1fe6254/packages/sampleOS/02_upgrades.yaml#L49).

## Build cache

Build cache allows to rebuild the same packages given a git checkout (assuming the cache images are pushed during build). 

The cache images are generated under the image reference passed by `--image-repository` and they can be pushed automatically during build time by specifying the `--push` flag.

_Note:_ In order to use build caches, you need to include the `cos-toolkit` tree checkout, or either as a git submodule under the `packages` folder, or by specifying an additional `--tree` argument when calling `luet build` pointing to a local path.


## Repository layout

`cos-toolkit` uses [luet](https://github.com/mudler/luet) behind the scenes to build the images. Luet uses a YAML syntax and a template engine to define packages that are built from containers.

The sample repository and `cos-toolkit` are [Luet trees](https://luet-lab.github.io/docs/docs/concepts/packages/specfile/) which contains package definitions. This allows derivatives to re-use the same components of `cos` as a whole, just consume parts of it or **point to specific versions of it** by checking out the `cos-toolkit` version in the derivative's tree repository.

The [.luet.yaml](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/.luet.yaml) file in the repository root defines where to take the compilations definition from and links it with the images built by the `cos-toolkit` CI. 

_Note: You can at any time decide to drop this file and replace it with a git submodule inside the `packages` directory - this allows you to point to specific versions of `cos-toolkit`._

In the repository we define just two packages: 

- The definition of our OS `system/sampleOS` (https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/packages/sampleOS/definition.yaml)
- The definition of our App `app/sampleOSService` (https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/packages/sampleOSService/definition.yaml)

We can see we reuse `cos` as we reference it in the `sampleOS` [build requirements](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/packages/sampleOS/build.yaml#L1):

```yaml
join:
- category: "system"
  name: "cos"
  version: ">=0"
- category: "app"
  name: "sampleOSService"
  version: ">=0"
```

This already allows us to inherit all the `system/cos` featureset, which is presented in the [README](https://github.com/rancher-sandbox/cOS-toolkit#readme). Another approach is [available here](https://github.com/rancher-sandbox/epinio-appliance-demo-sample/blob/master/packages/epinioOS/build.yaml#L1) where we use `requires` instead. See also the [official docs](https://luet-lab.github.io/docs/docs/concepts/packages/specfile/#package-source-image) for more details.

We just apply some minor changes ( default username and password ) and [define where our images will be pushed to](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/packages/sampleOS/02_upgrades.yaml). This is needed in order to allow `cos-upgrade` to upgrade from your container registry.


At this point, we have our application, which is a golang app, and the build definition looks like the following:

```yaml
requires:
- name: "golang"
  category: "build"
  version: ">=0"

env:
- PATH=$PATH:/usr/local/go/bin
- GOPATH=/luetbuild/go

steps:
- zypper in -y {{.Values.additional_packages}}
- go build -o sampleOSService main.go 
- mv sampleOSService /usr/bin
- cp 10_sampleOSService.yaml /system/oem/
```

We have added some additional packages needed for our service (`zypper in -y {{.Values.additional_packages}}`, where `additional_packages` are defined [here](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/packages/sampleOSService/definition.yaml#L5)), and we have built the golang application by requiring `build/golang`, which is provided by `cos-toolkit`.

At this point, `cos-build` will just run `luet build` and `luet geniso` inside a container. `geniso` is a simple script that reads the [iso spec](https://github.com/rancher-sandbox/cos-toolkit-sample-repo/blob/master/iso.yaml) and creates an ISO with the defined luet packages, which in our case is `system/sampleOS`.

For a more concrete example where we embed [k3s](https://k3s.io/) and pinpoint to a specific `cos-toolkit` version, see the [EpinioOS appliance demo example](https://github.com/rancher-sandbox/epinio-appliance-demo-sample)