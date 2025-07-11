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

VERSION="4.14.98"
INSTALL_PATH="/out" # da modificare

# WLAN sources directory
SRC_DIR="imx-board-wlan-src"

echo "==> Entering in ${SRC_DIR}"
cd "${SRC_DIR}" || { echo "Directory ${SRC_DIR} non trovata"; exit 1; }

echo "==> Checkout kernel version: ${VERSION}"
git checkout "${VERSION}"

echo "==> WLAN building"
make ARCH="${ARCH}" \
     CROSS_COMPILE="${CROSS_COMPILE}" \
     KERNEL_SRC="${KERNEL_SRC}"

echo "==> Wlan modules installation in ${INSTALL_PATH}"
make ARCH="${ARCH}" \
     CROSS_COMPILE="${CROSS_COMPILE}" \
     KERNEL_SRC="${KERNEL_SRC}" \
     INSTALL_MOD_PATH="${INSTALL_PATH}" modules_install

echo "==> WLAN successfully builded and installed"

echo "==> Linux Modules and kernel install"

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


