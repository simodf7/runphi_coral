#!/bin/bash

usage() {
  echo -e "Usage: $0 \r\n \
  This script copy the pub key to the remote target:\r\n \
    [-t <target>]\r\n \
    [-b <backend>]\r\n \
    [-h help]" 1>&2
  exit 1
}

current_dir=$(dirname -- "$(readlink -f -- "$1")")
script_dir=$(dirname -- "$(readlink -f -- "$current_dir")")
env_builder_dir=$(dirname -- "$(readlink -f -- "$script_dir")")
source ${script_dir}/common/common.sh


while getopts "t:b:h" o; do
  case "${o}" in
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

RUNPHI_DIR=$1
#CONTROL_PLANE_IP="192.168.100.21"
CONTROL_PLANE_IP=$2
CONTROL_PLANE_USER="root"

RUNPHI_NODE_HOSTNAME=$3
RUNPHI_NODE_IP=$4
RUNPHI_NODE_USER="root"

if [ -z ${RUNPHI_DIR} ]; then
	echo "Please, specify runphi_manager absolute path!"
	exit 255
fi

if [ -z ${CONTROL_PLANE_IP} ]; then
	echo "Please, specify Kubernetes control plane node IP (e.g., 192.168.100.21)..."
	exit 255
fi

if [ -z ${RUNPHI_NODE_HOSTNAME} ]; then
	echo "Please, specify the hostname of node being used as worker node for hosting partitioned containers (e.g., buildroot)..."
	exit 255
fi

if [ -z ${RUNPHI_NODE_IP} ]; then
	echo "Please, specify the IP for runphi worker node for hosting partitioned containers (e.g., 192.0.3.76)..."
	exit 255
fi


echo "current_dir: ${current_dir}"
echo "script_dir: ${script_dir}"
echo "env_builder_dir: ${env_builder_dir}"
echo "runphi_manager dir: ${RUNPHI_DIR}"

# Check if RUNPHI_DIR is a proper runphi_manager dir (simple check with target dir...)
if [ ! -d ${RUNPHI_DIR}/target ]; then
	echo "OOPS, ${RUNPHI_DIR} seems to be not a proper runphi_manager dir...PLS CHECK!"
	exit 255
fi

## add checks for network connectivity to CONTROL PLANE and target QEMU VM
echo "Check networking for QEMU VM at ${RUNPHI_NODE_IP}"
ssh -q ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP} exit > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "QEMU VM at ${RUNPHI_NODE_IP} is not reachable (check ping, ssh, etc.)!"
	echo "Please, run ./scripts_jailhouse_qemu/jailhouse_setup/config_net_eth0_jailhouse_root_cell.sh within QEMU VM"
	exit 255
fi

echo "Check networking for CONTROL PLANE at ${CONTROL_PLANE_IP}"
ssh -q ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP} exit > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "CONTROL PLANE at ${CONTROL_PLANE_IP} is not reachable (check ping, ssh, etc.)!"
	exit 255
fi


## Create the token calling the command on the control plane node to join the cluster
join_cmd=$(ssh ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP} "export KUBECONFIG=/etc/kubernetes/admin.conf; kubeadm token create  --print-join-command" 2>/dev/null)
echo "executing ${join_cmd} on ${RUNPHI_NODE_IP}"

## Reset for sake of simplicity and avoid inconsistency
ssh ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP} "kubeadm reset -f; ps -ef | grep /usr/bin/kubelet | awk '{print \$1}' | xargs kill -9 "
ssh ${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP} "export KUBECONFIG=/etc/kubernetes/admin.conf; kubectl delete node ${RUNPHI_NODE_HOSTNAME}"

## Copy again the configuration file dumped out by the kube reset
scp ${env_builder_dir}/environment/qemu/jailhouse/install/var/lib/kubelet/configBR.yaml ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP}:/var/lib/kubelet/configBR.yaml

## Perform inner networking config (load modules and configure flannel)
ssh ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP} "/root/target/network_config_cluster.sh"

## Make the node join the cluster
ssh ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP} "modprobe br_netfilter; export KUBECONFIG=/etc/kubernetes/admin.conf;${join_cmd}" &
PID_JOIN=$!
echo "Waiting for the node to join"
sleep 20

## Since the kubeadm expects to have systemd which is not present, we do manually start the kubelet
ssh ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP} "/etc/init.d/S92kubelet start"
wait $PID_JOIN
ssh ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP} "mkdir -p /usr/share/runPHI"
ssh ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP} "mkdir -p /usr/share/runPHI/include"
scp ${RUNPHI_DIR}/target/target_configs/${TARGET}.toml ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP}:/usr/share/runPHI/platform-info.toml
scp ${RUNPHI_DIR}/target/target_configs/${TARGET}_initial_state.toml ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP}:/usr/share/runPHI/state.toml

# Define source and destination paths
SOURCE_DIR="${RUNPHI_DIR}/target/runPHI_cell_configs"
DEST_DIR="${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP}:/usr/share/runPHI"

# Step 1: Copy all contents of runPHI_cell_configs except qemu-cell.h and omnivisor-cell.h
rsync -av --exclude 'include/qemu-cell.h' --exclude 'include/omnivisor-cell.h' "${SOURCE_DIR}/" "${DEST_DIR}"

# Step 2: Determine the correct file to copy based on TARGET
if [ "$TARGET" == "qemu" ]; then
    FILE_TO_COPY="qemu-cell.h"
else
    FILE_TO_COPY="omnivisor-cell.h"
fi

# Step 3: Copy the selected file, renaming it to cell.h
scp "${SOURCE_DIR}/include/${FILE_TO_COPY}" "${DEST_DIR}/include/cell.h"

# scp -r ${RUNPHI_DIR}/target/runPHI_cell_configs/* ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP}:/usr/share/runPHI
scp -r $(find ${RUNPHI_DIR}/target -maxdepth 1 -type f) ${RUNPHI_NODE_USER}@${RUNPHI_NODE_IP}:/root/target/
