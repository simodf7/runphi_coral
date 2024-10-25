#!/bin/bash

PLATFORM="zynqmp-zcu102"

CPUs=("RPU" "APU" "RISCV")

echo "Platform: ${PLATFORM}"

# Check if the first argument is provided, otherwise prompt the user
if [ -z "$1" ]; then
    echo "Please choose the CPU where to launch the inmate cell(RPU, APU, RISCV):"
    read CELL_CHOICE
else
    CELL_CHOICE=$1
fi

# CPU choice validation
if [[ ! " ${CPUs[@]} " =~ " ${CELL_CHOICE} " ]]; then
    echo "Invalid CPU choice (RPU, APU, RISCV)."
    exit 1
fi
# Map the user input to the corresponding cell file
BAREMETAL_INMATE_CELL="${PLATFORM}-${CELL_CHOICE}-inmate-demo.cell"
INMATE="inmate-demo-${CELL_CHOICE}"
ARCH=$(case $CELL_CHOICE in
    APU) echo "arm64" ;;
    RPU) echo "armr5" ;;
    RISCV) echo "riscv" ;;
esac)

# Check if the second argument is provided, otherwise prompt the user
if [ -z "$2" ]; then
    echo "Please choose the demo to launch from the following options:"
    for demo_file in ${JAILHOUSE_DIR}/inmates/demos/${ARCH}/*-demo.bin; 
    do 
        demo_name=$(basename "$demo_file" | sed 's/-demo\.bin//')
        echo "$demo_name"
    done
    read DEMO_CHOICE
else
    DEMO_CHOICE=$2
fi

# Check if the demo choice is valid
DEMO_VALID=false
for demo_file in ${JAILHOUSE_DIR}/inmates/demos/${ARCH}/*-demo.bin; 
do 
    demo_name=$(basename "$demo_file" | sed 's/-demo\.bin//')
    if [ "$demo_name" == "$DEMO_CHOICE" ]; then
        DEMO_VALID=true
        DEMO_BIN="${demo_name}-demo.bin"
        DEMO_BIN_TCM="${demo_name}-demo_tcm.bin"
        break
    fi
done

if [ "$DEMO_VALID" == false ]; then
    echo "Invalid demo choice. Exiting."
    exit 1
fi

jailhouse cell create ${JAILHOUSE_DIR}/configs/arm64/${BAREMETAL_INMATE_CELL}
if [ "$CELL_CHOICE" == "RPU" ]; then
    jailhouse cell load ${INMATE} ${JAILHOUSE_DIR}/inmates/demos/${ARCH}/${DEMO_BIN_TCM} -a 0xffe00000 ${JAILHOUSE_DIR}/inmates/demos/${ARCH}/${DEMO_BIN}
else
    jailhouse cell load ${INMATE} ${JAILHOUSE_DIR}/inmates/demos/${ARCH}/${DEMO_BIN}
fi
jailhouse cell start ${INMATE}