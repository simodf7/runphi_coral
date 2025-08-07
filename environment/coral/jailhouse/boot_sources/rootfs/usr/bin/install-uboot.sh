#!/bin/bash

BOOT_PART=mmcblk0boot0
MMCBLK_RO_PATH=/sys/block/${BOOT_PART}/force_ro

UBOOT_PACKAGE_SIZE=$(stat -c%s /boot/u-boot.imx)

function check_emmc_matches {
  local UBOOT_CURRENT=$(mktemp)
  dd if=/dev/${BOOT_PART} of=${UBOOT_CURRENT} \
    count=${UBOOT_PACKAGE_SIZE} \
    bs=512 \
    skip=66 \
    iflag=count_bytes
  diff ${UBOOT_CURRENT} /boot/u-boot.imx
  local DIFF_RETURN_CODE=$?
  rm ${UBOOT_CURRENT}
  return ${DIFF_RETURN_CODE}
}

# Check if the u-boot on eMMC is the same as u-boot from the package
check_emmc_matches

if [[ $? -eq 0 ]]; then
  exit 0
fi

# Get the read-only setting for the bootloader
MMCBLK_RO=$(cat ${MMCBLK_RO_PATH})

# Disable read-only on bootloader block device
echo 0 > ${MMCBLK_RO_PATH}

UPDATE_SUCCESS=false
# Write the bootloader image into the block device
for i in `seq 1 5`
do
  dd if=/boot/u-boot.imx of=/dev/${BOOT_PART} bs=512 seek=66
  check_emmc_matches
  if [[ $? -eq 0 ]]; then
    UPDATE_SUCCESS=true
    break
  fi
done

# Restore whatever the setting was before
echo ${MMCBLK_RO} > ${MMCBLK_RO_PATH}

if [[ "${UPDATE_SUCCESS}" != true ]]; then
  echo "Failed to update u-boot! Rebooting is unsafe!"
  exit 1
fi