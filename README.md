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

From your git folder:

```bash
$> docker build -t cos-builder .
$> docker run --privileged=true --rm -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/cOS cos-builder
```

or use the `.envrc` file:

```bash
$> source .envrc
$> cos-build
```

## Build SampleOS Locally

SampleOS can be build locally by using the following make targets.

Install build dependencies:

```bash
# Install toolchain dependencies (luet, luet-extensions and yq)
$ sudo make deps
```

Build the actual sampleOS root tree:

```bash
# Builds all the packages of the repository
$ sudo make build
```

Create an ISO with the built root tree from SampleOS:

```bash
# Creates a local repo and builds an ISO using the local repository
# on top of the raccos/realeases-cos docker repository
$ sudo make local-iso
```

### Manual build without Makefile targets

The sampleOS relies on [**luet**](https://luet-lab.github.io/docs/) for the build, in fact this is the
core of the toolchain. Consider running the following commands to build SampleOS.

Install OS dependencies for ISO and filesystems management:

```bash
# Install packages for openSUSE
zypper in squashfs xorriso dosfstools
```

Install luet and its extensions:

```bash
# Installing Luet
$ curl https://get.mocaccino.org/luet/get_luet_root.sh |  sh

# Install the luet extensions repository configuration
$ sudo luet install -y repository/mocaccino-extra-stable

# Install luet extensions and utilities require for ISO creation
$ sudo luet install -y utils/jq utils/yq system/luet-devkit
```

Build the SampleOS root tree:

```bash
$ sudo luet build --only-target-package --pull --image-repository raccos/sampleos \
     --pull-repository raccos/opensuse --destination build --from-repositories system/sampleOS
```

Create the local repository for the build packages:

```bash
$ luet create-repo --output build --name sampleOS --from-repositories
```

Generate the ISO

```bash
$ sudo luet geniso-isospec iso/sampleOS.yaml
```
