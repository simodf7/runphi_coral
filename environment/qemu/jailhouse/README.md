# Run demos

After building the environment ``qemu-jailhouse``, (check [this](https://dessert.unina.it:8088/runphi/environment_builder#1-download-configure-and-compile-everything)), start QEMU VM:

```
# cd /PATH_TO_RUNPHI/
# ./scripts/qemu/start_qemu.sh
```

Make sure to load all built components (e.g., jailhouse, etc.) into QEMU VM (check [this](https://dessert.unina.it:8088/runphi/environment_builder#4-load-projects)). Then, run demos as described in the following (all commands are executed within the QEMU VM).

#### GIC demo

```
# cd /root/scripts_jailhouse_qemu

### Run root cell for GIC DEMO
# ./jailhouse_setup/start_jailhouse.sh qemu-arm64.cell

### Run non-root cell gic demo
# ./demos/gic_demo/gic_demo.sh

...

Cell "inmate-demo" can be loaded
Started cell "inmate-demo"
Initializing the GIC...
Initializing the timer...
Timer fired, jitter: 202596 ns, min: 202596 ns, max: 202596 ns
Timer fired, jitter: 152887 ns, min: 152887 ns, max: 202596 ns
Timer fired, jitter: 121370 ns, min: 121370 ns, max: 202596 ns
Timer fired, jitter:  81177 ns, min:  81177 ns, max: 202596 ns
Timer fired, jitter: 138306 ns, min:  81177 ns, max: 202596 ns

```

#### Linux demo

```
# cd /root/scripts_jailhouse_qemu

### Run root cell for LINUX DEMO
# ./jailhouse_setup/start_jailhouse.sh qemu-arm64.cell

### Run non-root cell Linux
# ./demos/linux_demo/linux_demo.sh

.....
Cell "qemu-arm64-linux-demo" can be loaded
Started cell "qemu-arm64-linux-demo"

Welcome to Buildroot
buildroot login:


### Log in with user: root and pwd: root
```

#### Zephyr HELLO WORLD demo

```
### Run root cell for Zephyr DEMO
# cd /root/scripts_jailhouse_qemu
# ./jailhouse_setup/start_jailhouse.sh qemu-arm64-zephyr-rootcell.cell

### Launch non-root cell 1 for hello world
# ./demos/zephyr_hello_world_demo/zephyr_launch_nonroot_cell1_demo.sh

### N.B.: once launchin the first zephyr cell, current UART is lost.
### Go to runphi project and launch ./scripts/remote/ssh_connection.sh to get 
### control over QEMU VM

### Launch non-root cell 1 for hello world
# ./demos/zephyr_hello_world_demo/zephyr_launch_nonroot_cell2_demo.sh

#### Get cell list
# jailhouse cell list
ID      Name                    State             Assigned CPUs           Failed CPUs
0       qemu-arm64-zephyr-rootcellrunning           4-15
1       qemu-arm64-zephyr-non-rootcell1running           0-1
2       qemu-arm64-zephyr-non-rootcell2running           2-3

### Destroy cells
# jailhouse cell destroy 1
# jailhouse cell destroy 2
# jailhouse disable
```

#### Zephyr DHCP demo

```
### Run root cell for Zephyr DEMO
# cd /root/scripts_jailhouse_qemu
# ./jailhouse_setup/start_jailhouse.sh qemu-arm64-zephyr-rootcell.cell

### Configure eth1 interface on root cell to make a IVSHMEM pipe between root and non-root cell

# ./demos/zephyr_dhcp_demo/config_net_eth1_zephyr_dhcp_demo.sh
Bringing down interface eth1...
Configuring IP address 192.0.2.1/24 on eth1...
Bringing up interface eth1...
Starting DHCP server on eth1...
Adding forwarding iptables rule from eth0<->eth1...
Internet Systems Consortium DHCP Server 4.4.3-P1
Copyright 2004-2022 Internet Systems Consortium.
All rights reserved.
For info, please visit https://www.isc.org/software/dhcp/
Config file: /etc/dhcp/dhcpd.conf
Database file: /var/lib/dhcp/dhcpd.leases
PID file: /var/run/dhcpd.pid
Wrote 0 leases to leases file.
Listening on LPF/eth1/5e:8b:0f:63:57:6e/192.0.2.0/24
Sending on   LPF/eth1/5e:8b:0f:63:57:6e/192.0.2.0/24
Sending on   Socket/fallback/fallback-net
Server starting service
...

### Launch non-root cell for Zephyr DHCP demo

# ./demos/zephyr_dhcp_demo/zephyr_launch_nonroot_cell1_dhcp.sh
DHCPDISCOVER from d6:a5:55:b2:6a:f7 via eth1
DHCPOFFER on 192.0.2.10 to d6:a5:55:b2:6a:f7 via eth1
DHCPREQUEST for 192.0.2.10 (192.0.2.1) from d6:a5:55:b2:6a:f7 via eth1
DHCPACK on 192.0.2.10 to d6:a5:55:b2:6a:f7 via eth1

### On non-root cell UART you should view the following:

### uart:~$ [  964.662663] NOHZ tick-stop error: Non-RCU local softirq work is pending, handler #08!!!
### [  964.665928] IPv6: ADDRCONF(NETDEV_CHANGE): eth1: link becomes ready
### [00:00:01.090,000] <inf> net_dhcpv4: Received: 192.0.2.10
### [00:00:01.090,000] <inf> net_dhcpv4: Received: 192.0.2.10
### uart:~$ [00:00:01.100,000] <inf> net_dhcpv4_client_sample:    Address[1]: 192.0.2.10
### [00:00:01.100,000] <inf> net_dhcpv4_client_sample:    Address[1]: 192.0.2.10
### uart:~$ [00:00:01.100,000] <inf> net_dhcpv4_client_sample:     Subnet[1]: 255.255.255.0
### [00:00:01.100,000] <inf> net_dhcpv4_client_sample:     Subnet[1]: 255.255.255.0
### uart:~$ [00:00:01.100,000] <inf> net_dhcpv4_client_sample:     Router[1]: 192.0.2.1
### [00:00:01.100,000] <inf> net_dhcpv4_client_sample:     Router[1]: 192.0.2.1
### uart:~$ [00:00:01.100,000] <inf> net_dhcpv4_client_sample: Lease time[1]: 600 seconds
### [00:00:01.100,000] <inf> net_dhcpv4_client_sample: Lease time[1]: 600 seconds
### uart:~$

### From non-root cell Zephyr try to ping 8.8.8.8
uart:~$ net ping 8.8.8.8
PING 8.8.8.8
28 bytes from 8.8.8.8 to 192.0.2.10: icmp_seq=1 ttl=112 time=26.25 ms
28 bytes from 8.8.8.8 to 192.0.2.10: icmp_seq=2 ttl=112 time=26.66 ms
28 bytes from 8.8.8.8 to 192.0.2.10: icmp_seq=3 ttl=112 time=25.33 ms
```

#### Zephyr PING PONG micro-ROS DEMO

_**TODO**_
