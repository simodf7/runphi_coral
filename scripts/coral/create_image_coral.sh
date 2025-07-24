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

# Cartella con le immagini da modificare
IMG_DIR="${boot_sources_dir}"

# Punti di origine dei file compilati (modifica se serve)
NEW_BOOT_DIR="${boot_dir}"        # Image, System.map
KMODS_SRC_DIR="${boot_dir}"/lib/modules/
JAILHOUSE_SRC_DIR="${jailhouse_dir}"

sudo losetup -D

# Punto di mount temporaneo
MNT="/mnt/coral"
sudo mkdir -p "${MNT}"

echo "=== Inizio aggiornamento immagini ==="

# 1) boot.img
echo ">>> Mount and update boot.img"
sudo mount -t ext2 -o loop,rw "${IMG_DIR}/boot.img" "${MNT}"
sudo rm -f "${MNT}/Image" "${MNT}/System.map"* "${MNT}/config"*
sudo cp "${NEW_BOOT_DIR}/Image"      "${MNT}/"
sudo cp "${NEW_BOOT_DIR}/System.map-4.14.98+" "${MNT}/"
sudo cp "${NEW_BOOT_DIR}/config-4.14.98+" "${MNT}/"
sync
sudo umount "${MNT}"
echo ">>> boot.img aggiornato."

# 2) rootfs.img
echo ">>> Mount and update rootfs.img"
sudo mount -t ext4 -o loop,rw "${IMG_DIR}/rootfs.img" "${MNT}"
sudo rm -rf "${MNT}/lib/modules/"*
sudo bash -c 'echo "jailhouse"' > "${MNT}/etc/modules-load.d/jailhouse.conf"
sudo cp -r "${KMODS_SRC_DIR}/4.14.98+" "${MNT}/lib/modules/"
sudo cp "${NEW_BOOT_DIR}/lib/firmware/"* "${MNT}/lib/firmware/"
sudo cp -r "${NEW_BOOT_DIR}/usr/lib/"* "${MNT}/usr/lib/"
sudo cp -r "${NEW_BOOT_DIR}/usr/local/lib/"* "${MNT}/usr/local/lib/"
sudo cp -r "${NEW_BOOT_DIR}/usr/local/libexec" "${MNT}/usr/local/"
sudo cp -r "${JAILHOUSE_SRC_DIR}/pyjailhouse" "${MNT}/usr/local/libexec/"
sudo cp "${NEW_BOOT_DIR}/usr/local/sbin/"* "${MNT}/usr/local/sbin/"
sudo cp -r "${NEW_BOOT_DIR}/usr/local/share/jailhouse" "${MNT}/usr/local/share"
sudo cp -r "${NEW_BOOT_DIR}/usr/local/share/man/man8" "${MNT}/usr/local/share/man"
sudo cp "${NEW_BOOT_DIR}/usr/share/bash-completion/completions/jailhouse" "${MNT}/usr/share/bash-completion/completions/"

# sudo cp "${JAILHOUSE_SRC_DIR}/tools/jailhouse" "${MNT}/usr/local/bin"
# sudo cp "${JAILHOUSE_SRC_DIR}/hypervisor/jailhouse.bin" "${MNT}/lib/firmware/"

sync
sudo umount "${MNT}"
echo ">>> rootfs.img aggiornato."

# 3) home.img
echo ">>> Mount and update home.img"
sudo mount -t ext4 -o loop,rw "${IMG_DIR}/home.img" "${MNT}"
sudo cp -r "${JAILHOUSE_SRC_DIR}" "${MNT}/"
sync
sudo umount "${MNT}"
echo ">>> home.img aggiornato."

echo "=== Fine aggiornamento immagini ==="
echo

# === Sezione 1.5: pulizia e aggiornamento 'Image' in necessary ===

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

