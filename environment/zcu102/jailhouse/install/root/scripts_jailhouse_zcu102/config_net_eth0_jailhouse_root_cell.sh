#!/bin/bash

# Assegna indirizzo ip a eth0
# eth0 è l'interfaccia tap assegnata alla VM QEMU

# TODO: eth0 IP address (e.g., 192.0.3.76) must be taken from ${IP} in 'environment/qemu/jailhouse/environment_cfgs/qemu-jailhouse.sh'

ETH0_NAME="eth0"
ETH0_IP="192.0.3.76"
ETH0_NETMASK="255.255.255.0"
DEFAULT_GATEWAY="192.0.3.1"  ## NODE: this is the br0 address assigned in host machine

ip addr add ${ETH0_IP}/${ETH0_NETMASK} dev ${ETH0_NAME}
echo "Addedd ${ETH0_IP} to ${ETH0_NAME} NIC (tap0 interface in QEMU VM)"

#echo "Adding iptables DNAT rules..."
#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Default route is set to the host's bridge IP

# TODO: make gateway IP as a param
ip route add default via ${DEFAULT_GATEWAY}

# Configure DNS to gateway IP
echo "nameserver ${DEFAULT_GATEWAY}" > /etc/resolv.conf
