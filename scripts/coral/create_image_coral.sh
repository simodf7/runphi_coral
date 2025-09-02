#!/bin/bash

set -e

# === Section 1: boot, rootfs and home.img creation  ===========

# DIRECTORIES
current_dir=$(dirname -- "$(readlink -f -- "$0")")
script_dir=$(dirname "${current_dir}")
source "${script_dir}"/common/common.sh

# Set the Environment
source "${script_dir}"/common/set_environment.sh "${TARGET}" "${BACKEND}"

IMG_DIR="${boot_sources_dir}" # sources directory
OUT_BOOT_DIR="${boot_dir}"  # output directory
JAILHOUSE_SRC_DIR="${jailhouse_dir}"

sudo losetup -D



MNT="/mnt/coral"
sudo mkdir -p "${MNT}"


# 1) boot.img
echo ">>> boot.img creation"

sudo dd if=/dev/zero of="boot.img" bs=1 count=0 seek="128M"

# Format as filesystem ext2
sudo mkfs.ext2 -F -L "boot" "boot.img"

# loop device association
LOOP=$(sudo losetup --show -f "boot.img")

# mount
sudo mount "${LOOP}" "${MNT}"

sudo cp -a --preserve=all "${IMG_DIR}/boot/"* "${MNT}"
sudo rm -f "${MNT}/Image" "${MNT}/System.map"* "${MNT}/config"*
sudo cp -a --preserve=all  "${OUT_BOOT_DIR}/Image"      "${MNT}/"
sudo cp -a --preserve=all "${OUT_BOOT_DIR}/System.map-4.14.98+" "${MNT}/"
sudo cp -a --preserve=all "${OUT_BOOT_DIR}/config-4.14.98+" "${MNT}/"

# 6) sync and unmount
sync
sudo umount "${MNT}"

echo "> Okay: created boot.img"
# 7) removing loop device
sudo losetup -d "${LOOP}"


# 2) rootfs.img
echo ">>>  rootfs.img creation"


sudo dd if=/dev/zero of="rootfs.img" bs=1 count=0 seek="4G"

# Format as filesystem ext4
sudo mkfs.ext4 -F -L "rootfs" "rootfs.img"

# loop device association
LOOP=$(sudo losetup --show -f "rootfs.img")


# mount
sudo mount "${LOOP}" "${MNT}"

sudo cp -a --preserve=all -r "${IMG_DIR}/rootfs/"* "${MNT}"

sudo rm -rf "${MNT}/lib/modules/"*
sudo bash -c 'echo "jailhouse"' > "${MNT}/etc/modules-load.d/jailhouse.conf"
sudo cp -a --preserve=all -r "${OUT_BOOT_DIR}/lib/modules/4.14.98+" "${MNT}/lib/modules/"
sudo cp -a --preserve=all "${OUT_BOOT_DIR}/lib/firmware/"* "${MNT}/lib/firmware/"
sudo cp -a --preserve=all -r "${OUT_BOOT_DIR}/usr/lib/"* "${MNT}/usr/lib/"
sudo cp -a --preserve=all -r "${OUT_BOOT_DIR}/usr/local/lib/"* "${MNT}/usr/local/lib/"
sudo cp -a --preserve=all -r "${OUT_BOOT_DIR}/usr/local/libexec" "${MNT}/usr/local/"
sudo cp -a --preserve=all -r "${JAILHOUSE_SRC_DIR}/pyjailhouse" "${MNT}/usr/local/libexec/"
sudo cp -a --preserve=all  "${OUT_BOOT_DIR}/usr/local/sbin/"* "${MNT}/usr/local/sbin/"
sudo cp -a --preserve=all -r "${OUT_BOOT_DIR}/usr/local/share/jailhouse" "${MNT}/usr/local/share"
sudo cp -a --preserve=all -r "${OUT_BOOT_DIR}/usr/local/share/man/man8" "${MNT}/usr/local/share/man"
sudo cp -a --preserve=all "${OUT_BOOT_DIR}/usr/share/bash-completion/completions/jailhouse" "${MNT}/usr/share/bash-completion/completions/"


sync
sudo umount "${MNT}"


echo "> Okay: created rootfs.img"
# 7) removing loop device
sudo losetup -d "${LOOP}"


# 3) home.img


echo ">>> creating home.img"


sudo dd if=/dev/zero of="home.img" bs=1 count=0 seek="2G"

# Format as filesystem ext4
sudo mkfs.ext4 -F -L "home" "home.img"

# loop device association
LOOP=$(sudo losetup --show -f "home.img")

# mount
sudo mount "${LOOP}" "${MNT}"

sudo cp -a --preserve=all -r "${JAILHOUSE_SRC_DIR}" "${MNT}/"
sync
sudo umount "${MNT}"
echo ">>> created home.img"
echo 

sudo losetup -d "${LOOP}"


# Images created are moved to boot sources directory 
sudo mv "boot.img" "${IMG_DIR}/"
sudo mv "rootfs.img" "${IMG_DIR}/"
sudo mv "home.img" "${IMG_DIR}/"


sudo cp "${OUT_BOOT_DIR}/Image" "${IMG_DIR}/"
echo ">>> File 'Image' aggiornato in ${IMG_DIR}."


# === Section 2: complete image creation =============

echo "=== Starting bootable image creation ==="

IMG="flashcard_custom.img"
SIZE_GIB=7                             # total image dimension in GiB
SD_PART_START=16384                    # 8 MiB offset from the start
UBOOT_SEEK_KB=33                       # offset in KiB for u-boot.imx

# Dimension calculation 
# 1 GiB = 1024^3 byte
IMAGE_BYTES=$(( SIZE_GIB * 1024**3 ))
IMAGE_SIZE="${SIZE_GIB}G"
START_BYTES=$(( SD_PART_START * 512 ))
END_BYTES=$(( IMAGE_BYTES - 1 ))

echo "Cartella sorgente: ${IMG_DIR}"
echo "Dimensione immagine: ${IMAGE_SIZE} (${IMAGE_BYTES} byte)"

echo ">>> 1) Creating empty image"
sudo dd if=/dev/zero of="$IMG" bs=1 count=0 seek="$IMAGE_SIZE"

echo ">>> 2) Making partition"
sudo parted --script "$IMG" \
  mklabel msdos \
  mkpart primary ext2 ${START_BYTES}B ${END_BYTES}B \
  set 1 boot on



echo ">>> 3) Associating loop device..."
LOOP_DEV=$(sudo losetup --show -f "$IMG")
echo "Loop device: $LOOP_DEV"

sudo partx -a "$LOOP_DEV"

PART_DEV="${LOOP_DEV}p1"

if [ ! -b "$PART_DEV" ]; then

  DEV_NAME=$(basename "$PART_DEV")
  DEV_PATH="/dev/$DEV_NAME"

  MAJOR_MINOR=$(cat /sys/class/block/$(basename "$LOOP_DEV")/${DEV_NAME}/dev 2>/dev/null || true)
  if [ -z "$MAJOR_MINOR" ]; then
    sudo losetup -d "$LOOP_DEV"
    exit 1
  fi

  MAJOR=$(echo "$MAJOR_MINOR" | cut -d: -f1)
  MINOR=$(echo "$MAJOR_MINOR" | cut -d: -f2)

  sudo mknod "$DEV_PATH" b "$MAJOR" "$MINOR"
  sudo chmod 660 "$DEV_PATH"

  PART_DEV="$DEV_PATH"
fi

echo ">>> 4) ext2 formatting on ${PART_DEV}..."
sudo mkfs.ext2 -L boot "$PART_DEV"


echo ">>> 5) Mounting partition and file moving."
MNT_IMG=$(mktemp -d)
sudo mount "${PART_DEV}" "$MNT_IMG"

echo "   - Moving file from  ${IMG_DIR} into mount directory "
sudo cp -a "${IMG_DIR}/." "$MNT_IMG/"


echo ">>> Sincronizing and unmounting..."
sync
sudo umount "$MNT_IMG"

# u-boot.imx raw injection
echo ">>> 6) u-boot.imx injection at ${UBOOT_SEEK_KB}KiB..."
sudo dd if="${IMG_DIR}/u-boot.imx" of="$LOOP_DEV" bs=1K seek="$UBOOT_SEEK_KB" conv=fsync

# Cleanup
echo ">>> 7) Releasing loop device..."
sudo losetup -d "$LOOP_DEV"

echo "Image '$IMG' correttecly created!"
echo "-> REMEMBER: To Flash on sd >>> dd if=$IMG of=/dev/sdX bs=4M && sync"

