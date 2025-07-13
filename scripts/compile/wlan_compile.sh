#!/bin/bash

# compile_wlan.sh - Script per compilare e installare il modulo WLAN
# Utilizzo:
#   ./compile_wlan.sh
# Variabili d'ambiente usate di default:
#   ARCH (es. arm64)
#   CROSS_COMPILE (es. aarch64-linux-gnu-)
#   KERNEL_SRC (directory sorgenti kernel)
#

set -e


# DIRECTORIES
current_dir=$(dirname -- "$(readlink -f -- "$0")")
script_dir=$(dirname "${current_dir}")
source "${script_dir}"/common/common.sh

# Set the Environment
source "${script_dir}"/common/set_environment.sh "${TARGET}" "${BACKEND}"

VERSION="4.14.98"
INSTALL_PATH=${boot_dir}
KERNEL_SRC=${linux_dir}


echo "==> Entering in ${wlan_dir}"
cd "${wlan_dir}" || { echo "Directory ${wlan_dir} non trovata"; exit 1; }


make ARCH=${ARCH} \
     CROSS_COMPILE=${CROSS_COMPILE} \
     KERNEL_SRC=${KERNEL_SRC}

make ARCH=${ARCH} \
     CROSS_COMPILE=${CROSS_COMPILE} \
     KERNEL_SRC=${KERNEL_SRC} \
     INSTALL_MOD_PATH=${INSTALL_PATH} modules_install


# Modules install
make -C "${KERNEL_SRC}" INSTALL_MOD_PATH="${INSTALL_PATH}" modules_install

# Kernel install
make -C "${KERNEL_SRC}" \
     ARCH="${ARCH}" \
     CROSS_COMPILE="${CROSS_COMPILE}" \
     INSTALL_PATH="${INSTALL_PATH}" install

echo "Modules and kernel installed in ${INSTALL_PATH}"


# Modules Dependency update
echo "Updating depmod on ${INSTALL_PATH}"
depmod -b "${INSTALL_PATH}" $(cd "${KERNEL_SRC}" && make -s kernelrelease)


