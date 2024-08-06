#!/bin/bash
CONTROL_PLANE_IP="192.168.100.21"
HOSTNAME="buildroot"
current_dir=$(dirname -- "$(readlink -f -- "$0")")
script_dir=$(dirname -- "$(readlink -f -- "$current_dir")")
runphi_dir=$(dirname -- "$(readlink -f -- "$script_dir")")

echo "current_dir: ${current_dir}"
echo "script_dir: ${script_dir}"
echo "runphi_dir: ${runphi_dir}"

## TODO CLEAN THIS
if [ -z $1 ]; then
	IP_QEMU="192.0.3.76"
else
	IP_QEMU=$1
fi

## add checks for network connectivity to CONTROL PLANE and target QEMU VM
echo "Check networking for QEMU VM at ${IP_QEMU}"
ssh -q root@192.0.3.76 exit > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "QEMU VM at ${IP_QEMU} is not reachable (check ping, ssh, etc.)!"
	echo "Please, run ./scripts_jailhouse_qemu/jailhouse_setup/config_net_eth0_jailhouse_root_cell.sh within QEMU VM"
	exit 255
fi

echo "Check networking for CONTROL PLANE at ${CONTROL_PLANE_IP}"
ssh -q root@${CONTROL_PLANE_IP} exit > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "CONTROL PLANE at ${CONTROL_PLANE_IP} is not reachable (check ping, ssh, etc.)!"
	exit 255
fi


## Create the token calling the command on the control plane node to join the cluster
join_cmd=$(ssh root@${CONTROL_PLANE_IP} "export KUBECONFIG=/etc/kubernetes/admin.conf; kubeadm token create  --print-join-command" 2>/dev/null)
echo "executing ${join_cmd} on ${IP_QEMU}"

## Reset for sake of simplicity and avoid inconsistency
ssh root@${IP_QEMU} "kubeadm reset -f; ps -ef | grep /usr/bin/kubelet | awk '{print \$1}' | xargs kill -9 "
ssh root@${CONTROL_PLANE_IP} "export export KUBECONFIG=/etc/kubernetes/admin.conf; kubectl delete node ${HOSTNAME}"
## Copy again the configuration file dumped out by the kube reset
scp ${runphi_dir}/environment/qemu/jailhouse/install/var/lib/kubelet/configBR.yaml root@${IP_QEMU}:/var/lib/kubelet/configBR.yaml
## Perform inner networking config (load modules and configure flannel)
ssh root@${IP_QEMU} "/root/target/network_config_cluster.sh"
## Make the node join the cluster
ssh root@${IP_QEMU} "export KUBECONFIG=/etc/kubernetes/admin.conf;${join_cmd}" &
PID_JOIN=$!
echo "Waiting for the node to join"
sleep 20
## Since the kubeadm expects to have systemd which is not present, we do manually start the kubelet
ssh root@${IP_QEMU} "/etc/init.d/S92kubelet start"
wait $PID_JOIN
ssh root@${IP_QEMU} "mkdir -p /usr/share/runPHI"
scp -r ${runphi_dir}/runPHI/target/runPHI_cell_configs/* root@${IP_QEMU}:/usr/share/runPHI
