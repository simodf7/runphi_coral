#!/bin/bash

## Connection
IP=""
USER=""
SSH_ARGS=""
RSYNC_ARGS_SSH=""
RSYNC_ARGS=""
RSYNC_REMOTE_PATH=""

## CROSS COMPILING ARCHITECTURES
ARCH="arm64"
BUILD_ARCH="aarch64"
CROSS_COMPILE="aarch64-linux-gnu-"
REMOTE_COMPILE=""


## Boot Sources Configuration
BOOTCMD_CONFIG=""
DTS_CONFIG=""

## COMPONENTS ##
# QEMU
QEMU_BUILD="n"

# ATF
ATF_BUILD="n"

# U-BOOT 
UBOOT_BUILD="n"

# LINUX
LINUX_BUILD="y"
UPD_LINUX_COMPILE_ARGS="-c config-4.14.98-imx"
LINUX_COMPILE_ARGS=""
LINUX_PATCH_ARGS="" 
LINUX_REPOSITORY="https://coral.googlesource.com/linux-imx"
LINUX_BRANCH="4.14.98"
LINUX_COMMIT=""
LINUX_CONFIG=""  # impostare il config-4.14.98.imx 

# BUILDROOT
BUILDROOT_BUILD="n"

# JAILHOUSE
JAILHOUSE_BUILD="y"
UPD_JAILHOUSE_COMPILE_ARGS=""
JAILHOUSE_COMPILE_ARGS="" # da comprendere
JAILHOUSE_PATCH_ARGS=""
JAILHOUSE_REPOSITORY="https://github.com/nxp-imx/imx-jailhouse"
JAILHOUSE_BRANCH=""
JAILHOUSE_COMMIT=""
JAILHOUSE_CONFIG=""

# BOOTGEN
BOOTGEN_BUILD="n"

