#!/bin/bash

usage() {
  echo -e "Usage: $0 \r\n \
  This script load the selected components in the target filesystem:\r\n \
    [-a load all]\r\n \
    [-j load jailhouse]\r\n \
    [-r <RUNPHI MANAGER PATH> load runPHI]\r\n \
    [-t <target>]\r\n \
    [-b <backend>]\r\n \
    [-h help]" 1>&2
  exit 1
}

# DIRECTORIES
current_dir=$(dirname -- "$(readlink -f -- "$0")")
script_dir=$(dirname "${current_dir}")
source ${script_dir}/common/common.sh

J=0
R=0

while getopts "jr:at:b:h" o; do
  echo "Processing option: -${o}, OPTARG: ${OPTARG}"  # Debug line
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
source ${script_dir}/common/set_environment.sh ${TARGET} ${BACKEND}

# Check input
if [ "${J}" -eq 0 ] && [ "${R}" -eq 0 ]; then
  echo "ERROR: Select a project to sync!"
  usage
fi

## check runphi path is specified
if [ "${R}" -eq 1 ]; then
	if [ -z ${runPHI_dir} ]; then
		echo "Please select a path for RUNPHI MANAGER!"
		usage
	fi
fi


echo "REMOTE: ${USER}@${IP}:${RSYNC_REMOTE_PATH}"
echo "ARGS: ${RSYNC_ARGS} ${RSYNC_ARGS_SSH}"

## note to install runphi into remote target

# create /usr/share/runPHI on target
#cp ~/runphi_manager/target/runPHI_cell_configs/* in /usr/share/runPHI
#cp ~/runphi_manager/target/target_configs/<TARGET>_platform_info.toml platform_info.toml
#cp ~/runphi_manager/target/target_configs/<TARGET>_state.toml state.toml

RUNPHI_INSTALL_DIR="/usr/share/runPHI"
ssh ${USER}@${IP} "date -u -s '$(date -u +'%Y-%m-%d %H:%M:%S')'"
if [ -z "${RSYNC_ARGS_SSH}" ]; then
  [ ${J} -eq 1 ] && rsync -ruv --modify-window=1 ${RSYNC_ARGS} ${jailhouse_dir} ${USER}@${IP}:${RSYNC_REMOTE_PATH}

  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target ${USER}@${IP}:${RSYNC_REMOTE_PATH} # cp all runPHI_dir
  [ ${R} -eq 1 ] && ssh ${USER}@${IP} "mkdir -p ${RUNPHI_INSTALL_DIR}"
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/runPHI_cell_configs/* ${USER}@${IP}:${RUNPHI_INSTALL_DIR}
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/platform_info.toml
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/state.toml

else
  [ ${J} -eq 1 ] && rsync -ruv --modify-window=1 ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${jailhouse_dir} ${USER}@${IP}:${RSYNC_REMOTE_PATH}
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir} ${USER}@${IP}:${RSYNC_REMOTE_PATH}

  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target ${USER}@${IP}:${RSYNC_REMOTE_PATH} # cp all runPHI_dir
  [ ${R} -eq 1 ] && ssh ${USER}@${IP} "mkdir -p ${RUNPHI_INSTALL_DIR}"
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target/runPHI_cell_configs/* ${USER}@${IP}:${RUNPHI_INSTALL_DIR}
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/platform_info.toml
  [ ${R} -eq 1 ] && rsync -ruv ${RSYNC_ARGS} "${RSYNC_ARGS_SSH}" ${runPHI_dir}/target/target_configs/${TARGET}_platform_info.toml ${USER}@${IP}:${RUNPHI_INSTALL_DIR}/state.toml


fi
