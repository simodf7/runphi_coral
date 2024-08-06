
#!/bin/bash

#WARNING: configure with the right .cell
ZEPHYR_INMATE_CELL="qemu-arm64-zephyr-demo1.cell"

jailhouse cell create ${JAILHOUSE_DIR}/configs/arm64/${ZEPHYR_INMATE_CELL}
jailhouse cell load qemu-arm64-zephyr-demo1 ${NON_ROOTCELL_DIR}/microros_zephyr_ping_pong/zephyr.bin -a 0x70000000
jailhouse cell start qemu-arm64-zephyr-demo1
