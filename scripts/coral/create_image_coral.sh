#!/bin/bash

# ----------------------------------------------------------------
# full_workflow.sh
#
# 1) Mount-loop e aggiornamento di boot.img, rootfs.img e home.img
# 2) Creazione immagine 7 GiB con u-boot.imx iniettato
# ----------------------------------------------------------------

set -e

# === Sezione 1: aggiornamento immagini esistenti ===========

# DIRECTORIES
current_dir=$(dirname -- "$(readlink -f -- "$0")")
script_dir=$(dirname "${current_dir}")
source "${script_dir}"/common/common.sh

# Set the Environment
source "${script_dir}"/common/set_environment.sh "${TARGET}" "${BACKEND}"

IMG_DIR="${boot_sources_dir}"

NEW_BOOT_DIR="${boot_dir}"        # Image, System.map
KMODS_SRC_DIR="${boot_dir}"/lib/modules/
JAILHOUSE_SRC_DIR="${jailhouse_dir}"

sudo losetup -D

echo "Cartella di build: ${build_dir}"


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

sudo cp -a --preserve=all "${build_dir}/boot/"* "${MNT}"
sudo rm -f "${MNT}/Image" "${MNT}/System.map"* "${MNT}/config"*
sudo cp -a --preserve=all  "${NEW_BOOT_DIR}/Image"      "${MNT}/"
sudo cp -a --preserve=all "${NEW_BOOT_DIR}/System.map-4.14.98+" "${MNT}/"
sudo cp -a --preserve=all "${NEW_BOOT_DIR}/config-4.14.98+" "${MNT}/"

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

sudo cp -a --preserve=all -r "${build_dir}/rootfs/"* "${MNT}"

sudo rm -rf "${MNT}/lib/modules/"*
sudo bash -c 'echo "jailhouse"' > "${MNT}/etc/modules-load.d/jailhouse.conf"
sudo cp -a --preserve=all -r "${KMODS_SRC_DIR}/4.14.98+" "${MNT}/lib/modules/"
sudo cp -a --preserve=all "${NEW_BOOT_DIR}/lib/firmware/"* "${MNT}/lib/firmware/"
sudo cp -a --preserve=all -r "${NEW_BOOT_DIR}/usr/lib/"* "${MNT}/usr/lib/"
sudo cp -a --preserve=all -r "${NEW_BOOT_DIR}/usr/local/lib/"* "${MNT}/usr/local/lib/"
sudo cp -a --preserve=all -r "${NEW_BOOT_DIR}/usr/local/libexec" "${MNT}/usr/local/"
sudo cp -a --preserve=all -r "${JAILHOUSE_SRC_DIR}/pyjailhouse" "${MNT}/usr/local/libexec/"
sudo cp -a --preserve=all  "${NEW_BOOT_DIR}/usr/local/sbin/"* "${MNT}/usr/local/sbin/"
sudo cp -a --preserve=all -r "${NEW_BOOT_DIR}/usr/local/share/jailhouse" "${MNT}/usr/local/share"
sudo cp -a --preserve=all -r "${NEW_BOOT_DIR}/usr/local/share/man/man8" "${MNT}/usr/local/share/man"
sudo cp -a --preserve=all "${NEW_BOOT_DIR}/usr/share/bash-completion/completions/jailhouse" "${MNT}/usr/share/bash-completion/completions/"

# sudo cp "${JAILHOUSE_SRC_DIR}/tools/jailhouse" "${MNT}/usr/local/bin"
# sudo cp "${JAILHOUSE_SRC_DIR}/hypervisor/jailhouse.bin" "${MNT}/lib/firmware/"

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


sudo cp -a --preserve=all -r "${build_dir}/home/"* "${MNT}"
sudo cp -a --preserve=all -r "${JAILHOUSE_SRC_DIR}" "${MNT}/"
sync
sudo umount "${MNT}"
echo ">>> created home.img"
echo 

sudo losetup -d "${LOOP}"


# Spostamento immagini 
sudo mv "boot.img" "${IMG_DIR}/"
sudo mv "rootfs.img" "${IMG_DIR}/"
sudo mv "home.img" "${IMG_DIR}/"



echo ">>> Pulizia e aggiornamento 'Image' in ${IMG_DIR}"  # rimozione vecchia Image e copia nuova
sudo rm -f "${IMG_DIR}/Image"
sudo cp "${NEW_BOOT_DIR}/Image" "${IMG_DIR}/"
echo ">>> File 'Image' aggiornato in ${IMG_DIR}."


# === Sezione 2: creazione flashcard_custom.img =============

echo "=== Inizio creazione immagine flashcard_custom.img ==="

# Configurazione
IMG="flashcard_custom.img"
SIZE_GIB=7                             # dimensione immagine in GiB
SD_PART_START=16384                    # primo settore partizione (8 MiB)
UBOOT_SEEK_KB=33                       # offset in KiB per u-boot.imx

# Calcolo dimensioni
# 1 GiB = 1024^3 byte
IMAGE_BYTES=$(( SIZE_GIB * 1024**3 ))
IMAGE_SIZE="${SIZE_GIB}G"
START_BYTES=$(( SD_PART_START * 512 ))
END_BYTES=$(( IMAGE_BYTES - 1 ))

# Informazioni
echo "Cartella sorgente: ${IMG_DIR}"
echo "Dimensione immagine: ${IMAGE_SIZE} (${IMAGE_BYTES} byte)"

echo ">>> 1) Creo file immagine sparso..."
sudo dd if=/dev/zero of="$IMG" bs=1 count=0 seek="$IMAGE_SIZE"

echo ">>> 2) Partizionamento (msdos)..."
sudo parted --script "$IMG" \
  mklabel msdos \
  mkpart primary ext2 ${START_BYTES}B ${END_BYTES}B \
  set 1 boot on



echo ">>> 3) Associazione loop device..."
LOOP_DEV=$(sudo losetup --show -f "$IMG")
echo "Loop device: $LOOP_DEV"

echo ">>> 3.1) Creazione partizioni con partx..."
sudo partx -a "$LOOP_DEV"

PART_DEV="${LOOP_DEV}p1"

echo ">>> 3.2) Verifico presenza partizione..."
if [ ! -b "$PART_DEV" ]; then
  echo ">>> ${PART_DEV} non trovato. Provo a creare manualmente con mknod."

  DEV_NAME=$(basename "$PART_DEV")
  DEV_PATH="/dev/$DEV_NAME"

  MAJOR_MINOR=$(cat /sys/class/block/$(basename "$LOOP_DEV")/${DEV_NAME}/dev 2>/dev/null || true)
  if [ -z "$MAJOR_MINOR" ]; then
    echo "Errore: impossibile leggere major/minor per $DEV_NAME"
    sudo losetup -d "$LOOP_DEV"
    exit 1
  fi

  MAJOR=$(echo "$MAJOR_MINOR" | cut -d: -f1)
  MINOR=$(echo "$MAJOR_MINOR" | cut -d: -f2)

  echo ">>> Creo nodo device $DEV_PATH con major=$MAJOR minor=$MINOR"
  sudo mknod "$DEV_PATH" b "$MAJOR" "$MINOR"
  sudo chmod 660 "$DEV_PATH"

  PART_DEV="$DEV_PATH"
fi

echo ">>> 4) Formattazione ext2 su ${PART_DEV}..."
sudo mkfs.ext2 -L boot "$PART_DEV"



echo ">>> 5) Mount e copia file..."
MNT_IMG=$(mktemp -d)
sudo mount "${PART_DEV}" "$MNT_IMG"

# Copia dei contenuti
echo "   - Copio filesystem e boot da ${IMG_DIR}"
sudo cp -a "${IMG_DIR}/." "$MNT_IMG/"

# Fine copia
echo ">>> Sincronizzo e smonto..."
sync
sudo umount "$MNT_IMG"

# Iniezione raw di u-boot.imx
echo ">>> 6) Inietto u-boot.imx a ${UBOOT_SEEK_KB}KiB..."
sudo dd if="${IMG_DIR}/u-boot.imx" of="$LOOP_DEV" bs=1K seek="$UBOOT_SEEK_KB" conv=fsync

# Cleanup
echo ">>> 7) Rilascio loop device..."
sudo losetup -d "$LOOP_DEV"

echo "✅ Immagine '$IMG' creata correttamente!"
echo "-> Flash: dd if=$IMG of=/dev/sdX bs=4M && sync"

