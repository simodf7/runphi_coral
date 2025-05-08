#!/bin/bash

usage() {
  echo -e "Usage: $0 \r\n \
  This script loads the selected components into the target filesystem:\r\n \
    [-a load all]\r\n \
    [-j load jailhouse]\r\n \
    [-r <RUNPHI MANAGER PATH> load runPHI]\r\n \
    [-t <target>]\r\n \
    [-b <backend>]\r\n \
    [-p <runPHI_manager_path> (required with -r or -a)]\r\n \
    [-h help]" 1>&2
  exit 1
}

# DIRECTORIES
current_dir=$(dirname -- "$(readlink -f -- "$0")")
script_dir=$(dirname "${current_dir}")
source ${script_dir}/common/common.sh

J=0
R=0

<<<<<<< HEAD
while getopts "jr:at:b:h" o; do
  echo "Processing option: -${o}, OPTARG: ${OPTARG}"  # Debug line
=======
while getopts "jrat:b:p:h" o; do
>>>>>>> 0bd852a32d424427479d8209280feb76a202261e
  case "${o}" in
  j)
    J=1
    ;;
  r)
    R=1
    runPHI_dir=${OPTARG}
    ;;
  a)
    J=1
    R=1
    ;;
  t)
    TARGET=${OPTARG}
    ;;
  b)
    BACKEND=${OPTARG}
    ;;
<<<<<<< HEAD
   h)
=======
  p)
    runPHI_dir=${OPTARG}
    ;;
  h)
>>>>>>> 0bd852a32d424427479d8209280feb76a202261e
    usage
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

# Validate input
if [ "${J}" -eq 0 ] && [ "${R}" -eq 0 ]; then
  echo "ERROR: Select a project to sync!"
  usage
fi

<<<<<<< HEAD
## check runphi path is specified
if [ "${R}" -eq 1 ]; then
	if [ -z ${runPHI_dir} ]; then
		echo "Please select a path for RUNPHI MANAGER!"
		usage
	fi
fi

=======
if [ "${R}" -eq 1 ]; then
  if [ -z "${runPHI_dir}" ]; then
    echo "ERROR: -p <runPHI_manager_path> is required when using -r or -a"
    usage
  fi
  if [ ! -d "${runPHI_dir}" ]; then
    echo "ERROR: The provided path '${runPHI_dir}' does not exist or is not a directory."
    exit 1
  fi
fi

# Set the Environment
source ${script_dir}/common/set_environment.sh ${TARGET} ${BACKEND}
>>>>>>> 0bd852a32d424427479d8209280feb76a202261e

echo "REMOTE: ${USER}@${IP}:${RSYNC_REMOTE_PATH}"
echo "ARGS: ${RSYNC_ARGS} ${RSYNC_ARGS_SSH}"

<<<<<<< HEAD
## note to install runphi into remote target

# create /usr/share/runPHI on target
#cp ~/runphi_manager/target/runPHI_cell_configs/* in /usr/share/runPHI
#cp ~/runphi_manager/target/target_configs/<TARGET>_platform_info.toml platform_info.toml
#cp ~/runphi_manager/target/target_configs/<TARGET>_state.toml state.toml

RUNPHI_INSTALL_DIR="/usr/share/runPHI"

if [ -z "${RSYNC_ARGS_SSH}" ]; then
  [ ${J} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${jailhouse_dir} ${USER}@${IP}:${RSYNC_REMOTE_PATH}

  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target ${USER}@${IP}:${RSYNC_REMOTE_PATH} # cp all runPHI_dir
  [ ${R} -eq 1 ] && ssh ${USER}@${IP} "mkdir -p ${RUNPHI_INSTALL_DIR}"
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/runPHI_cell_configs/* ${USER}@${IP}:${RUNPHI_INSTALL_DIR}
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/platform_info.toml
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/state.toml

=======
RUNPHI_INSTALL_DIR="/usr/share/runPHI"
ssh ${USER}@${IP} "date -u -s '$(date -u +'%Y-%m-%d %H:%M:%S')'"

if [ -z "${RSYNC_ARGS_SSH}" ]; then
  [ ${J} -eq 1 ] && rsync -ruv --modify-window=1 ${RSYNC_ARGS} ${jailhouse_dir} ${USER}@${IP}:${RSYNC_REMOTE_PATH}

  if [ ${R} -eq 1 ]; then
    rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target ${USER}@${IP}:${RSYNC_REMOTE_PATH}
    ssh ${USER}@${IP} "mkdir -p ${RUNPHI_INSTALL_DIR}"
    rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/runPHI_cell_configs/* ${USER}@${IP}:${RUNPHI_INSTALL_DIR}
    rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/platform_info.toml
    rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/target_configs/${TARGET}_state.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/state.toml
    rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/target_configs/${TARGET}_state.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/initial_state.toml

  fi
>>>>>>> 0bd852a32d424427479d8209280feb76a202261e
else
  [ ${J} -eq 1 ] && rsync -ruv --modify-window=1 ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${jailhouse_dir} ${USER}@${IP}:${RSYNC_REMOTE_PATH}
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir} ${USER}@${IP}:${RSYNC_REMOTE_PATH}

  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target ${USER}@${IP}:${RSYNC_REMOTE_PATH} # cp all runPHI_dir
  [ ${R} -eq 1 ] && ssh ${USER}@${IP} "mkdir -p ${RUNPHI_INSTALL_DIR}"
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target/runPHI_cell_configs/* ${USER}@${IP}:${RUNPHI_INSTALL_DIR}
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/platform_info.toml
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/state.toml


fi
