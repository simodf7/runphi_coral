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

- docker
  > Dockerfile to build the build container
- documentation
  > documentation of RunPHI Project
- runPHI
  > runPHI source code
- scripts
  > Utility scripts (Core of RunPHI Project)
- environment
  > List of Target/Backend
  
## Target/Backend Directories

- build
  > Directory with all the "To Build Components" (Linux, Buildroot, Qemu, Jailhouse, ...)
- custom_build
  > Builds mirror directory with custom files (defconfig files, dts, .c , ...)
- environment_cfgs
  > Configuration files for the environment
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
  > Scripts to Save and Update the configuration of the configurable "To-Build Components"
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

### 1. Download, configure, and compile everything

Launch the following script to download, configure and compile all the "To-Build Components" for the chosen \<target\> (e.g. qemu) and \<backend\> (e.g. jailhouse):

```bash
./scripts/build_environment.sh -t <target> -b <backend>
```

From now on the chosen target and backend will be the default ones. If you need to change for some reason the default target and backend, we provide the script "change_environment":

```bash
./scripts/change_environment.sh -t <target> -b <backend>
```

Otherwhise if you need to change the target and backend just for a single script you can always add the flags -t \<target\> -b \<backend\>.

### 2. Configure ssh [OPTIONAL but RECOMMENDED]

> [!NOTE]
> All the scripts in ./scripts/remote/* can be launched outside the docker container.

**While the board/QEMU is running** (skip to [this](https://dessert.unina.it:8088/runphi/environment_builder/-/blob/main/README.md#4-test-qemu-jailhouse-environment) if you want to test a ``qemu-jailhouse`` environment), use the following script on the host machine to create a local key pair for the user (if it doesn't exist) and send the pub key to the target to authorize the host to exchange data without requiring any password

```bash
./scripts/remote/set_remote_ssh.sh
```

After executing above script you can ssh QEMU VM without password.


### 3. Load projects

**While the board/QEMU is running** (skip to [this](https://dessert.unina.it:8088/runphi/environment_builder/-/blob/main/README.md#4-test-qemu-jailhouse-environment) if you want to test a ``qemu-jailhouse`` environment), use the following script to sync the install directory in the target file system:

```bash
./scripts/remote/load_install_dir_to_remote.sh
```

Use the following script to load (or update if already loaded) runPHI and Jailhouse in the board filesystem (run with -h flag for help).

```bash
./scripts/remote/load_components_to_remote.sh -r -j
```

Verify in the /root directory if the files have been loaded correctly.

### 4. Test QEMU-Jailhouse environment

Refer to this [README](https://dessert.unina.it:8088/runphi/environment_builder/-/blob/main/environment/qemu/jailhouse/README.md)

## Updates

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
