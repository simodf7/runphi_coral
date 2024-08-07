#!/bin/bash

#WARNING: configure with the right .cell and .dtb

LINUX_INMATE_CELL="qemu-arm64-linux-demo.cell"
LINUX_INMATE_DTB="inmate-qemu-arm64.dtb"

jailhouse cell linux \
	${JAILHOUSE_DIR}/configs/arm64/${LINUX_INMATE_CELL} \
	${NON_ROOTCELL_DIR}/arm64/linux/Image \
	-d ${JAILHOUSE_DIR}/configs/arm64/dts/${LINUX_INMATE_DTB} \
	-i ${NON_ROOTCELL_DIR}/arm64/linux/rootfs.cpio.gz \
	-c "console ttyAMA0,115200"
