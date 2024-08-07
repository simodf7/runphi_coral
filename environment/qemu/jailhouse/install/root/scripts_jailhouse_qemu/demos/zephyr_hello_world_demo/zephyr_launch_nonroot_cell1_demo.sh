#!/bin/bash

#WARNING: configure with the right .cell
ZEPHYR_INMATE_NAME="qemu-arm64-zephyr-non-rootcell1"
ZEPHYR_INMATE_CELL="qemu-arm64-zephyr-non-rootcell1.cell"
ARCH="arm64"

jailhouse cell create ${JAILHOUSE_DIR}/configs/arm64/${ZEPHYR_INMATE_CELL}
jailhouse cell load ${ZEPHYR_INMATE_NAME} ${NON_ROOTCELL_DIR}/${ARCH}/zephyr_demo.bin -a 0x70000000
jailhouse cell start ${ZEPHYR_INMATE_NAME}


