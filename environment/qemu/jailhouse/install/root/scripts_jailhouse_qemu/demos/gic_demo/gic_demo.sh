#!/bin/bash

#WARNING: configure with the right .cell
BAREMETAL_INMATE_CELL="qemu-arm64-inmate-demo.cell"

jailhouse cell create ${JAILHOUSE_DIR}/configs/arm64/${BAREMETAL_INMATE_CELL}
jailhouse cell load inmate-demo ${JAILHOUSE_DIR}/inmates/demos/arm64/gic-demo.bin 
jailhouse cell start inmate-demo
