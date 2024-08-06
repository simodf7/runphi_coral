#!/bin/bash

#WARNING: configure with the right .cell

ROOT_CELL=$1

if [ -z ${ROOT_CELL} ]; then
	echo "Please, specify the .cell name for root cell (e.g., qemu-arm64.cell)!"
	exit 255
fi

# Check if the firmware directory exists
if [ -d "/lib/firmware"  ]; then
       echo "firmware directory exists!"
else
	mkdir /lib/firmware
fi

# Clean up
jailhouse disable
rmmod jailhouse

# Copy the hypervisor image in the firmware directory
cp ${JAILHOUSE_DIR}/hypervisor/jailhouse.bin /lib/firmware/

# Insert the jailhouse module
insmod  ${JAILHOUSE_DIR}/driver/jailhouse.ko

# Start the hypervisor
jailhouse enable ${JAILHOUSE_DIR}/configs/arm64/${ROOT_CELL}
