#!/bin/bash

#WARNING: configure with the right .cell
BAREMETAL_INMATE_CELL="zynqmp-zcu104-RPU-inmate-demo.cell"
BINARY="baremetal-demo.bin"
BINARY_TCM="baremetal-demo_tcm.bin"

jailhouse cell create ${JAILHOUSE_DIR}/configs/arm64/${BAREMETAL_INMATE_CELL}
jailhouse cell load inmate-demo-RPU  ${JAILHOUSE_DIR}/inmates/demos/armr5/${BINARY_TCM} -a 0xffe00000  ${JAILHOUSE_DIR}/inmates/demos/armr5/${BINARY}
jailhouse cell start inmate-demo-RPU
