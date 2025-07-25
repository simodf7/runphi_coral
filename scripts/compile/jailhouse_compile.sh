#!/bin/bash

usage() {
  echo -e "Usage: $0 \r\n \
  This script compile the jailhouse hypervisor:\r\n \
    [-r <remote core> compile rCPU code demo and libraries (all, armr5, riscv32)]\r\n \
    [-B <benchmark name> for Taclebench demo]\r\n \
    [-n install jailhouse in the NFS directory]\r\n \
    [-i install jailhouse in the install directory]\r\n \
    [-t <target>]\r\n \
    [-b <backend>]\r\n \
    [-h help]" 1>&2
  exit 1
}

# DIRECTORIES
current_dir=$(dirname -- "$(readlink -f -- "$0")")
script_dir=$(dirname "${current_dir}")
source "${script_dir}"/common/common.sh

INSTALL_OVERLAY="n"
INSTALL_NFS="n"
RCPU_COMPILE="n"

#Benchmark name
BENCHNAME=""
RCPUs=""
CORE=""

while getopts "r:B:nit:b:h" o; do
  case "${o}" in
  n)
    INSTALL_NFS="Y"
    ;;
  i)
    INSTALL_OVERLAY="Y"
    ;;
  r)
    RCPU_COMPILE="Y"  
    RCPUs=${OPTARG}
    ;;
  B)
    BENCHNAME=${OPTARG}
    ;;
  t)
    TARGET=${OPTARG}
    ;;
  b)
    BACKEND=${OPTARG}
    ;;
  h)
    usage
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

# Set the Environment
source "${script_dir}"/common/set_environment.sh "${TARGET}" "${BACKEND}"

# If target is coral, use imx-jailhouse build and install
if [[ "${TARGET}" == "coral" ]]; then
  echo "Compiling and installing Jailhouse for Coral..."
  cd ${jailhouse_dir} || { echo "Directory imx-jailhouse not found"; exit 1; }


  SYSROOT=${install_dir}

  # Build
  make ARCH=${ARCH} \
       CROSS_COMPILE=${CROSS_COMPILE} \
       CC="aarch64-linux-gnu-gcc --sysroot=${SYSROOT}" \
       KDIR=${linux_dir}
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Jailhouse make failed for Coral"; exit 1
  fi

  # Install modules
  make ARCH=${ARCH} \
       CROSS_COMPILE=${CROSS_COMPILE} \
       CC="aarch64-linux-gnu-gcc --sysroot=${SYSROOT}" \
       KDIR=${linux_dir} \
       INSTALL_MOD_PATH=${boot_dir} modules_install 
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Jailhouse modules_install failed for Coral"; exit 1
  fi

 
   # Install Jailhouse
   make ARCH=${ARCH} \
         CROSS_COMPILE=${CROSS_COMPILE} \
         CC="aarch64-linux-gnu-gcc --sysroot=${SYSROOT}" \
         KDIR=${linux_dir} \
         DESTDIR=${boot_dir} \
         PREFIX=/usr install 
   if [[ $? -ne 0 ]]; then
    echo "ERROR: Jailhouse install failed for Coral"; exit 1
  fi
     
   python3 setup.py install \
         --prefix=/usr \
         --root=${boot_dir}
   if [[ $? -ne 0 ]]; then
	echo "ERROR: Jailhouse python setup failed for Coral"; exit 1 
   fi



  echo "Jailhouse for Coral compiled and installed successfully"
  exit 0
fi




# Always copy configs, custom dts, custom cells, and custom inmates before builing Jailhouse
#cp "${custom_jailhouse_cell_dir}"/dts/*.dts "${jailhouse_cell_dir}"/dts/
cp -r "${custom_jailhouse_cell_dir}"/* "${jailhouse_cell_dir}"
cp -r "${custom_jailhouse_inmate_demos_dir}"/* "${jailhouse_inmate_demos_dir}"

# Compile jailhouse (INPUT: kernel directory, installation directory)
make -C "${jailhouse_dir}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KDIR="${linux_dir}" #ARCH=arm64 CROSS_COMPILE=${aarch64_buildroot_linux_gnu_dir}/aarch64-buildroot-linux-gnu-
if [[ $? -ne 0 ]]; then
  echo "ERROR: The make command failed during the compilation of JAILHOUSE"
  exit 1
else
  echo "JAILHOUSE has been successfully compiled"
fi

# Compile RCPU demo
if [[ "${RCPU_COMPILE,,}" =~ ^y(es)?$ ]]; then
  # Check remote core
  if [[ "${RCPUs}" == "all" ]]; then
    CORE=""
  elif [[ "${RCPUs}" == "armr5" ]]; then
    CORE="_armr5"
  elif [[ "${RCPUs}" == "riscv32" ]]; then
    CORE="_riscv32"
  else
    echo "ERROR: Invalid remote core specified. try 'all', 'armr5' or 'riscv32'"
    exit 1
  fi
  # clean and compile
  make -C "${jailhouse_dir}" clean-remote${CORE} REMOTE_COMPILE="${REMOTE_COMPILE}" 
  make -C "${jailhouse_dir}" remote${CORE} REMOTE_COMPILE="${REMOTE_COMPILE}" BENCH=${BENCHNAME} 
  
  if [[ $? -ne 0 ]]; then
    echo "ERROR: The make command failed during the compilation of JAILHOUSE RPU demo"
    exit 1
  else
    echo "JAILHOUSE ${RCPUs} DEMO has been successfully compiled"
  fi
else
  echo "Skipping compiling JAILHOUSE RCPUs DEMO"
fi

# Install Jailhouse in the NFS directory
if [[ "${INSTALL_NFS,,}" =~ ^y(es)?$ ]]; then
  make -C "${jailhouse_dir}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KDIR="${linux_dir}" DESTDIR="${rootfs_dir}/${TARGET}" install 
  if [[ $? -ne 0 ]]; then
    echo "ERROR: The make command failed during the installation of JAILHOUSE in the NFS directory"
    exit 1
  fi
  cp -rf "${jailhouse_dir}" "${rootfs_dir}/${TARGET}/root/" > /dev/null 2>&1

  # Jailhouse should install pyjailhouse in the libexec/jailhouse directory but it doesn't. So lets do it manually
  echo "moving pyjailhouse in the right directory..."
  pyjailhouse_path=$(find "${rootfs_dir}/${TARGET}/usr/local/lib" -type d -name "pyjailhouse")
  cp -r "${pyjailhouse_path}" "${rootfs_dir}/${TARGET}/usr/local/libexec/jailhouse"
  # fi

  echo "JAILHOUSE has been successfully installed in the NFS directory!"
else
  echo "Skipping installation ..."
fi

# Install Jailhouse in the overlay filesystem
if [[ "${INSTALL_OVERLAY,,}" =~ ^y(es)?$ ]]; then
  make -C "${jailhouse_dir}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KDIR="${linux_dir}" DESTDIR="${project_dir}"/install install #ARCH=arm64 CROSS_COMPILE=${aarch64_buildroot_linux_gnu_dir}/aarch64-buildroot-linux-gnu-
  if [[ $? -ne 0 ]]; then
    echo "ERROR: The make command failed during the installation of JAILHOUSE"
    exit 1
  fi
  echo "JAILHOUSE has been successfully installed in the install directory!"

  # Create overlay directory structure
  mkdir -p "${install_dir}"/root/inmates/demos/linux
  mkdir -p "${install_dir}"/root/configs/dts

  # Copy compiled cell, compiled device tree, demos bin, in the final rootfs
  cp "${jailhouse_dir}"/configs/arm64/*.cell "${install_dir}"/root/configs
  cp "${jailhouse_dir}"/configs/arm64/dts/*.dtb "${install_dir}"/root/configs/dts
  cp "${jailhouse_dir}"/inmates/demos/arm64/*.bin "${install_dir}"/root/inmates/demos

  # Jailhouse should install pyjailhouse in the libexec/jailhouse directory but it doesn't. So lets do it manually
  if [ -d "${install_dir}/usr/local/libexec/jailhouse/pyjailhouse" ]; then
    echo "pyjailhouse is already in the right directory"
  else
    echo "moving pyjailhouse in the right directory..."
    pyjailhouse_path=$(find "${install_dir}" -type d -name "pyjailhouse")
    mv "${pyjailhouse_path}" "${install_dir}"/usr/local/libexec/jailhouse
  fi

else
  echo "Skipping installation ..."
fi
