# **RunPHI Environment Builder**

**The purpose of this repository is to automate the building of multiple working environmets (Target + Backend) to use/test runPHI.**

To build a working environment we are going to use Pre-Built Components and To-Build Components.

- Pre-Built Components: all the pre-compiled software for the target. This is software that we are not interested in changing or modifying but is needed to have a complete working environment (e.g. board specific firmware).

- To-Build Components: all the software that is compiled using the scripts of this repository. This is the software that we are interested in changing and modifying dynamically.

Each environment (target + backend) is characterized by a configuration file (``<target>-<backend>.sh``, e.g., ``qemu-jailhouse.sh``) that specifies a set of "To-Build Components" that are characterized by specific compilation flags and specific GitHub repository/commit.
Each target "Pre-Built components" are instead stored in the ``/PATH_TO_RUNPHI/environment/qemu/jailhouse/`` directory

The ``~/build_environment.sh -t <target> -b <backend>`` command downloads each "To-Build component" from their GitHub repository, compiles them and puts the result artifacts with the "Pre-Built Components" in the right environment directory.
The backend directory of the specified target will then store all the files needed to boot and run our system (both in emulation or real hardware).

While the system is running the "remote" scripts (scripts/remote/) give you a simple way to load/update software components in the environment (e.g. Update Kernel, Load RunPHI, ...).

> **Project:**
>
> RunPHI: Enabling Mixed-criticality Containers via Partitioning Hypervisors in Industry 4.0
>
> **Authors:**
>
> > Daniele Ottaviano ([daniele.ottaviano@unina.it](mailto:daniele.ottaviano@unina.it))
> > DESSERT TEAM
>
> **University:** University of Naples, Federico II
>
>  <img src="https://upload.wikimedia.org/wikipedia/commons/a/a1/Napoli_university_logo.svg" alt="University Logo" width="50"/>

## Status of the Project

Supported TARGETs:

- [x] qemu
- [x] kria
- [ ] ...

Supported BACKENDs:

- [x] jailhouse
- [ ] ...

## Main Directories

- Dockerfile
  > Dockerfile to build the build container
- documentation
  > documentation of RunPHI Project
- scripts
  > Utility scripts (Core of Environment Builder)
- environment
  > List of Target/Backend
  
## Target/Backend Directories

- boot_sources
  > Directory with all the boot files which can be modified and compiled. (Device Tree Source, Boot Script, ...)
- build
  > Directory with all the "To Build Components" (U-Boot, Buildroot, Linux, Qemu, Jailhouse, ...)
- custom_build
  > Builds mirror directory with custom files (defconfig files, default_dts, cell_configs , ...)
- environment_cfgs
  > Configuration files describing all the components of the environment
- install
  > It is used as an overlay directory for the rootfs. Anything that you want to add to the target filesystem should be here (e.g. kernel modules, scripts, network configuration)
- output
  > Artifacts produced by compilations (To-Build Components artifact) + Pre-Built Components artifacts.

## Scripts

- clean
  - destroy_build.sh
    > Delete build and outputs of the \<target\>
  - remove_backend.sh
    > Delete all the files and configuration related to a specific \<backend\> in a specified \<target\>
  - remove_environment.sh
    > Delete all the files and configuration related to a specific environment (target + backend)
- common
  > Scripts used by other scripts to set the environmental variables (Users should not use them).
- compile
  > Scripts to compile "To-Build Components" individually
- defconfigs
  > Scripts to Save and Update the configurations of the configurable "To-Build Components"
- orchestration
  > Setup for orchestration
- patch
  > Utility to apply custom patches to components
- qemu
  > Script to launch the QEMU emulation (the target is QEMU).
- remote
  > Scripts to update and load components, images and utilities on the running environment.
- change_environment.sh
  > Change the current environment to set a specific \<target\>+\<backend\>.
- build_environment.sh
  > Download and compile all the "To-Build Components" for a given environment (\<target\>+\<backend\>) with a single script (it may take a while...).

## Dependencies

> [!WARNING]
> We strongly recommend you run the compiling scripts in a docker container to avoid unexpected errors due to different software versions (e.g., compilers version).

Be sure to add you username to docker group

```
sudo usermod -aG docker yourusername
sudo `newgrp docker`
```

To open a shell in the Docker image with all the needed dependencies just run:

```bash
cd ~/environment_builder
docker build -t runphi_env_builder .
docker run -it --rm --user $(id -u):$(id -g) -v /etc/passwd:/etc/passwd:ro --net=host --name env_builder_container -v ${PWD}:/home -w="/home" runphi_env_builder /bin/bash
```

It is possible to run the scripts without docker but you will need the following packages (we don't recommend it):

```bash
apt-get update
apt-get install -y git make sed binutils diffutils python3 ninja-build build-essential bzip2 tar findutils unzip cmake rsync u-boot-tools gcc-arm-none-eabi gcc-aarch64-linux-gnu libglib2.0-dev libpixman-1-dev wget cpio rsync bc libncurses5 flex bison openssl libssl-dev kmod python3-pip file pkg-config
pip3 install Mako
```

## How to use the repository

> [!NOTE]
> For each script you can use the flag _-h_ (help) to understand the behavior of the script and the accepted flags.

### 0. Check the Environment Configuration

All information regarding the environment, including GitHub repositories, commits, patches, and more, can be found in the following file, be sure to check it before starting the build: environment_builder/\<target\>/\<backend\>/environment_cfgs/\<target\>-\<backend\>.sh

### 1. Download, configure, and compile everything

Launch the following script to download, configure and compile all the "To-Build Components" for the chosen \<target\> (e.g. qemu) and \<backend\> (e.g. jailhouse):

```bash
./scripts/build_environment.sh -t <target> -b <backend>
```

From now on the chosen target and backend will be the default ones. If you need to change for some reason the default target and backend, we provide the script "change_environment":

```bash
./scripts/change_environment.sh -t <target> -b <backend>
```

Otherwhise if you need to change the target and backend just for a single script you can always add the flags -t \<target\> -b \<backend\> to any other script.

### 2. Preparing the bootable SD for the target board 

To prepare the SD, you need to create two partitions on it:
- boot: size 1G, FAT32 format
- rootfs: size 31G (supposing the SD is 32G), ext4 format

Supposing that ``/dev/sda`` is the name of the SD card device.

##### Delete all existing partitions
```
# fdisk /dev/sda

## Command (m for help): d # delete all existing partitions with 'd' option, and accept all prompts, until there are no more partitions
## Command (m for help): w # write modification
```

##### Create boot and root partitions
```
# fdisk /dev/sda

# Command (m for help): n # create boot partition, select all default, except size (last sector) +1GB

## Partition type
##   p   primary (0 primary, 0 extended, 4 free)
##   e   extended (container for logical partitions)

# First sector (2048-61132799, default 2048): 2048
# Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-61132799, default 61132799): +1GB

## Created a new partition 1 of type 'Linux' and of size 954 MiB.

# Command (m for help): a # to make it bootable

## Selected partition 1
## The bootable flag on partition 1 is enabled now.

# Command (m for help): n # all default, to create a 2nd partition, size all remaining free space
# Command (m for help): w # write modification to fs

## Partition number (2-4, default 2):
## First sector (1955840-61132799, default 1955840):
## Last sector, +/-sectors or +/-size{K,M,G,T,P} (1955840-61132799, default 61132799):

## Created a new partition 2 of type 'Linux' and of size 28.2 GiB.
```

##### Format boot and root partitions 
```
# sudo mkfs.vfat /dev/sdc1 -n boot
mkfs.fat 4.2 (2021-01-31)
mkfs.fat: /dev/sdc1 contains a mounted filesystem. 

# sudo mkfs.ext4 -L root /dev/sdc2
mke2fs 1.47.0 (5-Feb-2023)
/dev/sdc2 contains a ext4 file system labelled 'root'
	created on Mon Feb 10 11:28:09 2025
Proceed anyway? (y,N) y
Creating filesystem with 7397120 4k blocks and 1851392 inodes
Filesystem UUID: c9e1c436-3c71-4e06-87fc-c600e142c898
Superblock backups stored on blocks:
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
	4096000

Allocating group tables: done
Writing inode tables: done
Creating journal (32768 blocks): done
Writing superblocks and filesystem accounting information: done
```

Then mount the boot partition with (Supposing /mnt/sd_boot is an available path) and remove old files:
```bash
mount -t vfat /dev/sda1 /mnt/sd_boot
rm -r /mnt/sd_boot/*
```

Then copy the boot files generated by the buid_environment script.
```bash
cd environment_builder/environment/<target>/<backend>/output/boot
cp BOOT.BIN Image boot.scr system.dtb /mnt/sd_boot/
umount /mnt/sd_boot 
```

In the rootfs partition we have to copy the rootfs files generated by the buid_environment script.
```bash
mount -t ext4 /dev/sda2 /mnt/sd_rootfs/
rm -r /mnt/sd_rootfs/*
cd environment_builder/environment/<target>/<backend>/output/rootfs
tar xf ./rootfs.tar -C /mnt/sd_rootfs/
umount /mnt/sd_rootfs
```

Be sure to set the board in SD boot mode (e.g. for zcu102 https://xilinx.github.io/Embedded-Design-Tutorials/docs/2021.1/build/html/docs/Introduction/ZynqMPSoC-EDT/8-boot-and-configuration.html#running-the-image-on-the-zcu102-board). 
> [!NOTE]
> The rootfs can also be compressed, and in that case there is no need to create a second partition but it is often convenient to have it uncompressed and easily accessible.

### 3. Configure ssh [OPTIONAL but RECOMMENDED]

> [!NOTE]
> All the scripts in ./scripts/remote/* can be launched outside the docker container.

**While the board/QEMU is running** (skip to [this](https://dessert.unina.it:8088/runphi/environment_builder/-/blob/main/README.md#4-test-qemu-jailhouse-environment) if you want to test a ``qemu-jailhouse`` environment), use the following script on the host machine to create a local key pair for the user (if it doesn't exist) and send the pub key to the target to authorize the host to exchange data without requiring any password

```bash
./scripts/remote/set_remote_ssh.sh
```

After executing above script you can ssh QEMU VM without password.


### 4. Load projects

**While the board/QEMU is running** (skip to [this](https://dessert.unina.it:8088/runphi/environment_builder/-/blob/main/README.md#4-test-qemu-jailhouse-environment) if you want to test a ``qemu-jailhouse`` environment), use the following script to sync the install directory in the target file system:

```bash
./scripts/remote/load_install_dir_to_remote.sh
```

Use the following script to load (or update if already loaded) runPHI and Jailhouse in the board filesystem (run with -h flag for help).

```bash
./scripts/remote/load_components_to_remote.sh -r -j
```

Verify in the /root directory if the files have been loaded correctly.

### 5. Test Environment

- **QEMU-Jailhouse**: refer to this [README](https://dessert.unina.it:8088/runphi/environment_builder/-/blob/main/environment/qemu/jailhouse/README.md)

### 6. Updates

If you manually modify the configuration in one of the "To-Built Components" (e.g., buildroot, Linux, jailhouse) you may need to compile them again. So there is a script for each of them (run using -h to see the possible flags):

```bash
./scripts/compile/buildroot_compile.sh
./scripts/compile/linux_compile.sh
./scripts/compile/jailhouse_compile.sh
...
```

Some of the "To-Build Components" (buildroot, Linux, and jailhouse) have configuration files. If the component works for the target and you want to save the actual configurations just run the script (the flag indicates the which component configuration to save):

```bash
./scripts/defconfigs/buildroot_save_defconfigs.sh
./scripts/defconfigs/linux_save_defconfigs.sh
./scripts/defconfigs/jailhouse_save_defconfigs.sh
...
```

If you change something and the configurations don't work anymore, you can update the last saved configurations:

```bash
./scripts/defconfigs/buildroot_update_defconfigs.sh
./scripts/defconfigs/linux_update_defconfigs.sh
./scripts/defconfigs/jailhouse_update_defconfigs.sh
```

### 7. Destroy environment

```
$ cd ~/environment_builder
$ docker run -it --rm --user $(id -u):$(id -g) -v /etc/passwd:/etc/passwd:ro --net=host --name env_builder_container_gigi -v ${PWD}:/home -w="/home" runphi_env_builder /bin/bash

## within the container 
root@test:~# ./scripts/clean/destroy_build.sh
Default environment
TARGET: zcu104
BACKEND: jailhouse
Do you really want to delete zcu104/jailhouse builds? (y/n): y
```

## Step by Step procedure (to do...)

## Warnings

> [!WARNING]
> If you modify the overlay fs (i.e. "install" directory), you must recompile buildroot to update the filesystem (be careful to not make it bloated).
> [!WARNING]
> In order to run Jailhouse, the Linux kernel needs to be configured enabling CONFIG_OF_OVERLAY, CONFIG_KALLSYMS_ALL, and CONFIG_KPROBES.

## To do

- Add MPSoCs emulated boards (Ultrascale+ emulation in QEMU)
- Add Components (Bao, Xen, U-Boot, ...)
- Add multi-architectural managment (x86, riscv, ...)
- Add new Boads support (ZCU104, Tegra, ...)
