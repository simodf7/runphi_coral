#!/bin/bash

## Connection
## QEMU SLIRP MODE with ssh forwarding on 5022 port
# IP="localhost"
# USER="root"
# SSH_ARGS="-p 5022"
# RSYNC_ARGS_SSH="ssh -p 5022"
# RSYNC_ARGS="-e"
# RSYNC_REMOTE_PATH="/root"

## QEMU TAP MODE
IP="192.0.3.76"
USER="root"
SSH_ARGS=""
RSYNC_ARGS_SSH=""
RSYNC_ARGS=""
RSYNC_REMOTE_PATH=""


## CROSS COMPILING ARCHITECTURES
ARCH="arm64"

## If BUILDROOT_BUILD="y" you can use the buildroot compiler
# CROSS_COMPILE="${aarch64_buildroot_linux_gnu_dir}/aarch64-buildroot-linux-gnu-"
CROSS_COMPILE="aarch64-linux-gnu-" 

REMOTE_COMPILE="arm-none-eabi-"

## COMPONENTS ##

### EMULATION

# QEMU
QEMU_BUILD="y"
QEMU_COMPILE_ARGS=""
QEMU_PATCH_ARGS=""
QEMU_REPOSITORY="https://github.com/Xilinx/qemu.git"
QEMU_BRANCH="xlnx_rel_v2023.1"
QEMU_COMMIT="21adc9f99e813fb24fb65421259b5b0614938376"

### FIRMWARE 

# ATF
ATF_BUILD="n"

# U-BOOT 
UBOOT_BUILD="n"

### KERNEL

# LINUX
LINUX_BUILD="y"
UPD_LINUX_COMPILE_ARGS=""
LINUX_COMPILE_ARGS="-m"
LINUX_PATCH_ARGS=""

## You can use Xilinx Linux by setting proper repo (no ivshmem-net support)
# LINUX_REPOSITORY="https://github.com/Xilinx/linux-xlnx.git"

LINUX_REPOSITORY="https://github.com/siemens/linux.git"
LINUX_BRANCH="jailhouse-enabling/5.15"
LINUX_COMMIT="" #E.g., LINUX_COMMIT="9f943ff23cec02b0b2db9e777197fb298ca2c4aa", LINUX_COMMIT="7484228ddbb5760eac350b1b4ffe685c9da9e765"

### FILESYSTEM 

# BUILDROOT
BUILDROOT_BUILD="y"
UPD_BUILDROOT_COMPILE_ARGS=""
BUILDROOT_COMPILE_ARGS=""
BUILDROOT_PATCH_ARGS="-p 0001-gcc-target.patch"
BUILDROOT_REPOSITORY="https://github.com/buildroot/buildroot.git"
BUILDROOT_BRANCH="2023.05.x"
BUILDROOT_COMMIT="25d59c073ac355d5b499a9db5318fb4dc14ad56c"

### BACKEND (e.g., Jailhouse, Xen, Linux full isol)

# JAILHOUSE
JAILHOUSE_BUILD="y"
UPD_JAILHOUSE_COMPILE_ARGS=""
JAILHOUSE_COMPILE_ARGS=""
JAILHOUSE_PATCH_ARGS="-p 0001-Update-for-kernel-version-greater-then-5-7-and-5-15.patch"
JAILHOUSE_REPOSITORY="https://gitlab.com/minervasys/public/jailhouse.git"
JAILHOUSE_BRANCH="minerva/public"
JAILHOUSE_COMMIT="b817b436e3fdaa7fad999b47adc94180b18bff75"

### TARGET SPECIFIC (e.g., bootgen create BOOTBIN for Xilinx board)

# BOOTGEN
BOOTGEN_BUILD="n"
