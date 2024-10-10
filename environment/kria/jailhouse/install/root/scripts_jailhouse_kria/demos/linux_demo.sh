#!/bin/bash

#WARNING: configure with the right .cell and .dtb

LINUX_INMATE_CELL="zynqmp-kv260-linux-demo.cell"
LINUX_INMATE_DTB="inmate-zynqmp.dtb"

jailhouse cell linux \
	${JAILHOUSE_DIR}/configs/arm64/${LINUX_INMATE_CELL} \
	${NON_ROOTCELL_LINUX_DIR}/Image \
	-d ${JAILHOUSE_DIR}/configs/arm64/dts/${LINUX_INMATE_DTB} \
	-i ${NON_ROOTCELL_LINUX_DIR}/initrd \
	-c "console ttyAMA0,115200"
