#!/bin/bash

#WARNING: configure with the right .cell
#TODO: this configuration does not work with another non-root cell zephyr with dhcp...fix it

ZEPHYR_INMATE_NAME="qemu-arm64-zephyr-non-rootcell2"
ZEPHYR_INMATE_CELL="qemu-arm64-zephyr-non-rootcell2.cell"

ARCH="arm64"

jailhouse cell create ${JAILHOUSE_DIR}/configs/arm64/${ZEPHYR_INMATE_CELL}
jailhouse cell load ${ZEPHYR_INMATE_NAME} ${NON_ROOTCELL_DIR}/bin/${ARCH}/zephyr_dhcp.bin -a 0x70000000
jailhouse cell start ${ZEPHYR_INMATE_NAME}
