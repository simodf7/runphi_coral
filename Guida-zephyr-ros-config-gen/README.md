# Micro-ROS and Zephyr Demo in Runphi (builder and manager)

## ROS2 and Micro-ROS Installation

We referred to guide in [https://micro.ros.org/docs/tutorials/core/zephyr_emulator/](https://micro.ros.org/docs/tutorials/core/zephyr_emulator/).

1. **Install ROS2**
   
   We recommend to install ROS2 via a docker container. We tested ``ROS2 HUMBLE`` version.

    ```
    # docker run -it -v /dev:/dev --privileged --name ros_humble_runphi ros:humble
    ```
       
2. **Setup Micro-ROS Workspace**
   
   After run the docker container, we obtain a terminal in which run all the following commands.


   ```
    ## Check $ROS_DISTRO, should be humble
    
    # echo $ROS_DISTRO
    humble

    ## Source the ROS 2 installation
    source /opt/ros/$ROS_DISTRO/setup.bash

    ## Create a workspace and download the micro-ROS tools
    # mkdir microros_ws
    # cd microros_ws
    # git clone -b $ROS_DISTRO https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup

    ## Update dependencies using rosdep
    # rm /etc/ros/rosdep/sources.list.d/20-default.list
    # apt update && rosdep init && rosdep update
    # rosdep install --from-paths src --ignore-src -y

    ## Install pip
    # apt-get install python3-pip -y

    ## Build micro-ROS tools and source them
    # colcon build
    # source install/local_setup.bash
    ```

## Zephyr Firmware for Micro-ROS Setup

1. **Replace the ``create.sh`` file in ``microros_ws/install/micro_ros_setup/config/zephyr/generic/`` with the patched version provided in this repo:**

    ```
    ### From host machine
    # docker cp ~/create.sh ros_humble_runphi:/microros_ws/install/micro_ros_setup/config/zephyr/generic/create.sh
    ```

    NOTE: ros_humble_runphi is the name of run container in "Install ROS" step.

2. **Download and set Zephyr and its SDK:**

    We assume a QEMU VM with a ARM Cortex A53. The board name is ``qemu_cortex_a53``

    ```
    ### From container
    user@hostname:/microros_ws# ros2 run micro_ros_setup create_firmware_ws.sh zephyr qemu_cortex_a53
    ```

3. **Copy the ping_ping and microros_extensions apps in zephyr_apps directory:**

    ```
    ### From host machine
    # docker cp /PATH_TO_repo/microros_extensions ros_humble_runphi:/microros_ws/firmware/zephyr_apps/
    # docker cp /PATH_TO_repo/ping_pong ros_humble_runphi:/microros_ws/firmware/zephyr_apps/apps/
    ```

4. **Patch picolibc.specs file:**
    ```
    ### From host machine
    # docker cp picolibc.specs ros_humble_runphi:/microros_ws/firmware/zephyr-sdk/aarch64-zephyr-elf/aarch64-zephyr-elf/lib/picolibc.specs
    ```

5. **Configure the firmware:**

    We assmume microROS broker is running on host with a bridge with IP ``192.0.3.1`` (is the br0 IP set in qemu-jailhouse environment, check [this](https://dessert.unina.it:8088/runphi/partitioned_container_demos/-/blob/main/demos/README.md#from-host-machine).)

    ```
    ### From container
    user@hostname:/microros_ws# ros2 run micro_ros_setup configure_firmware.sh ping_pong --transport udp --ip 192.0.3.1 --port 8888
    ```

6. **Be sure that ``firmware/zephyr_apps/microros_extensions/microros_transports.h`` has proper IP address for the broker (in our example 192.0.3.1):**
    ```
    ### From container
    user@hostname:/microros_ws# grep "default_params" /microros_ws/firmware/zephyr_apps/microros_extensions/microros_transports.h
    static zephyr_transport_params_t default_params = {.fd = 0};
    static zephyr_transport_params_t default_params = {{0,0,0}, "192.0.3.1", "8888"};
    static zephyr_transport_params_t default_params;
    ```

7. **Start the build process:**
    ```
    ### From container
    user@hostname:/microros_ws# ros2 run micro_ros_setup build_firmware.sh
    ```

    Now you can save all built artifact as a docker image to be reused after. Run the following:

    ```
    # docker commit ros_humble_runphi microros_humble_runphi_image
    sha256:c5befde097ddd9a0ef683452b6f1b663e28d1e5a8106c95f08b3dba0b0b594b3
    ```

All build artifacts are in ``/microros_ws/firmware/build/zephyr/`` dir. The ``zephyr.bin`` is the binary to be used as inmate in partitioned container.
## ROS2 Agent

1. **Run these commands to create, build, and run the ROS2 agent:**

    ```
    ### From host machine run a fresh docker container from microros_humble_runphi_image if you exited the previous one
    # docker run -it -v /dev:/dev --privileged --name ros_humble_runphi microros_humble_runphi_image

    ### From the container
    root@hostname:/microros_ws# source /opt/ros/$ROS_DISTRO/setup.bash
    root@hostname:/microros_ws# cd /microros_ws/
    root@hostname:/microros_ws# source install/local_setup.bash

    ## Download micro-ROS-Agent packages
    root@hostname:/microros_ws# ros2 run micro_ros_setup create_agent_ws.sh

    ## Build step
    root@hostname:/microros_ws# ros2 run micro_ros_setup build_agent.sh
    
    ```
    
## Demo in ``qemu-jailhouse`` environment

At this point, the file ``/microros_ws/firmware/build/zephyr/zephyr.bin``, within the container used to build ping pong demo, contains the ping pong binary used as inmate in a Jailhouse cell.

#### Setup ``qemu-jailhouse`` environment

* **Before building a ``qemu-jailhouse`` environment**

    If you want to add this binary as custom inmate into jailhouse directory run the following:

    ``docker cp ros_humble_runphi:/microros_ws/firmware/build/zephyr/zephyr.bin /PATH_TO_environment_builder/environment/qemu/jailhouse/custom_build/jailhouse/inmates/demos/arm64/zephyr_ping_pong.bin``

    Now, you should follow this [guide](https://dessert.unina.it:8088/runphi/environment_builder#how-to-use-the-repository) to build a ``qemu-jailhouse`` environment and use ``zephyr_ping_pong.bin`` as inmate in a non-root cell.

* **Already built a ``qemu-jailhouse`` environment**

    If you have already built a ``qemu-jailhouse`` environment, run the following:

    ###### Copy zephyr binary into inmates directory
    
    ```
    # docker cp ros_humble_runphi:/microros_ws/firmware/build/zephyr/zephyr.bin /PATH_TO_environment_builder/environment/qemu/jailhouse/build/jailhouse/    inmates/demos/arm64/ 
    ```

    ###### Reload jailhouse components into QEMU VM (Please, refer to this [this](https://dessert.unina.it:8088/runphi/environment_builder#3-load-projects))

    ```
    # cd /PATH_TO_environment_builder/
    # ./scripts/remote/load_components_to_remote.sh -j`` 
    ```

#### Run ping pong 

##### Run a micro-ROS agent
```
### From host machine run a fresh docker container from microros_humble_runphi_image and publish 8888/upd port

# docker run -it -v /dev:/dev --privileged -p 8888:8888/udp --name ros_humble_runphi microros_humble_runphi_image

### From container
root@hostname:/microros_ws# source install/local_setup.bash
root@hostname:/microros_ws# ros2 run micro_ros_agent micro_ros_agent udp4 --port 8888
    [1723130528.466883] info     | UDPv4AgentLinux.cpp | init                     | running...             | port: 8888
    [1723130528.467074] info     | Root.cpp           | set_verbose_level        | logger setup           | verbose_level: 4
```

##### Run the ping_pong Jailhouse non-root cell

```
### Run root cell for Zephyr DEMO
# cd /root/scripts_jailhouse_qemu
# ./jailhouse_setup/start_jailhouse.sh qemu-arm64-zephyr-rootcell.cell

### Configure eth1 interface on root cell to make a IVSHMEM pipe between root and non-root cell

# ./demos/zephyr_ping_pong_demo/config_net_eth1_zephyr_dhcp_demo.sh

### Run the non-root cell
# ./demos/zephyr_ping_pong_demo/zephyr_launch_nonroot_cell_ping_pong.sh

Created cell "qemu-arm64-zephyr-non-rootcell1"
Page pool usage after cell creation: mem 161/991, remap 528/131072
[   72.535672] Created Jailhouse cell "qemu-arm64-zephyr-non-rootcell1"
Cell "qemu-arm64-zephyr-non-rootcell1" can be loaded
Started cell "qemu-arm64-zephyr-non-rootcell1"
[00:00:00.000,000] <inf> ivshmem: PCIe: ID 0x4106110A, BDF 0x800, class-rev 0xFF000100
[00:00:00.010,000] <inf> ivshmem: MSI-X bar present: no
[00:00:00.010,000] <inf> ivshmem: SHMEM bar present: no
[00:00:00.010,000] <inf> ivshmem: State table size 0x1000
[00:00:00.010,000] <inf> ivshmem: RW section size 0x0
[00:00:00.010,000] <inf> ivshmem: Output section size 0x7F000
[00:00:00.010,000] <inf> ivshmem: Enabling INTx IRQ 141 (pin 2)
[00:00:00.010,000] <inf> ivshmem: ivshmem configured:
[00:00:00.010,000] <inf> ivshmem: - Registers at 0x10001000 (mapped to 0xEFEFE000)
[00:00:00.010,000] <inf> ivshmem: - Shared memory of 0xFF000 bytes at 0x7F900000 (mapped to 0x0)
[00:00:00.020,000] <inf> eth_ivshmem: ivshmem: id 1, max_peers 2
[00:00:00.020,000] <inf> eth_ivshmem: shmem queue: desc len 0x800, header size 0xD080, data size 0x71F80
[00:00:00.020,000] <inf> eth_ivshmem: MAC Address A6:67:72:4B:C0:A4
*** Booting Zephyr OS build v3.7.0-761-g0c7e87714d92 ***
[00:00:00.020,000] <inf> net_dhcpv4_client_sample: Run dhcpv4 client
[00:00:00.030,000] <inf> net_dhcpv4_client_sample: Start on eth_ivshmem: index=1


uart:~$ [   72.857045] IPv6: ADDRCONF(NETDEV_CHANGE): eth1: link becomes ready
[00:00:01.080,000] <inf> net_dhcpv4: Received: 192.0.2.10
[00:00:01.080,000] <inf> net_dhcpv4: Received: 192.0.2.10
uart:~$ [00:00:01.080,000] <inf> net_dhcpv4_client_sample:    Address[1]: 192.0.2.10
[00:00:01.080,000] <inf> net_dhcpv4_client_sample:    Address[1]: 192.0.2.10
uart:~$ [00:00:01.090,000] <inf> net_dhcpv4_client_sample:     Subnet[1]: 255.255.255.0
[00:00:01.090,000] <inf> net_dhcpv4_client_sample:     Subnet[1]: 255.255.255.0
uart:~$ [00:00:01.090,000] <inf> net_dhcpv4_client_sample:     Router[1]: 192.0.2.1
[00:00:01.090,000] <inf> net_dhcpv4_client_sample:     Router[1]: 192.0.2.1
uart:~$ [00:00:01.090,000] <inf> net_dhcpv4_client_sample: Lease time[1]: 600 seconds
[00:00:01.090,000] <inf> net_dhcpv4_client_sample: Lease time[1]: 600 seconds
uart:~$ Ping send seq 1687299856_1385592283
Ping send seq 1718562674_1385592283
Ping send seq 1530762823_1385592283
Ping send seq 743232442_1385592283
Ping send seq 1942525642_1385592283
....
```

##### Test /microROS/ping topic

```
### From host machine
# docker exec -it ros_humble_runphi /bin/bash

### From container
root@b3d179f80200:/# source /opt/ros/$ROS_DISTRO/setup.bash
root@b3d179f80200:/# ros2 topic echo /microROS/ping
stamp:
  sec: 202
  nanosec: 110000000
frame_id: '1654068131_1385592283'
---
stamp:
  sec: 204
  nanosec: 110000000
frame_id: '2002021665_1385592283'
---
stamp:
  sec: 206
  nanosec: 110000000
frame_id: '565096958_1385592283'
---
....
```

##### Test /microROS/pong topic

Open two terminals. On the firs subscribe to ``/microROS/pong`` topic, on the second send a ping via the ROS2 broker towards Jailhouse non-root cell.

```
1st terminal
### From host machine
# docker exec -it ros_humble_runphi /bin/bash
root@b3d179f80200:/# source /opt/ros/$ROS_DISTRO/setup.bash
root@b3d179f80200:/# ros2 topic echo /microROS/pong
stamp:
  sec: 0
  nanosec: 0
frame_id: fake_ping
---
....
```

```
2nd terminal
### From host machine
# docker exec -it ros_humble_runphi /bin/bash

root@b3d179f80200:/# source /opt/ros/$ROS_DISTRO/setup.bash
root@b3d179f80200:/# ros2 topic pub --once /microROS/ping std_msgs/msg/Header '{frame_id: "fake_ping"}'
publisher: beginning loop
publishing #1: std_msgs.msg.Header(stamp=builtin_interfaces.msg.Time(sec=0, nanosec=0), frame_id='fake_ping')
```

Check non-root cell printing the ping received:
```
....
Ping send seq 1484061832_1385592283
Ping send seq 1240941892_1385592283
Ping send seq 358766469_1385592283
Ping received with seq fake_ping. Answering.
Ping send seq 1876187127_1385592283
Ping send seq 985853053_1385592283
Ping send seq 822127230_1385592283
....
```

## Demo in runphi 

To run the ping pong application as a partitioned container via runphi, you can:

- Use the prebuilt image, namely ``dessertunina/microrospingpong:arm64jh``.
- Build the image from scratch using the binary obtained at the end of [this](https://dessert.unina.it:8088/runphi/environment_builder/-/edit/main/Guida-zephyr-ros-config-gen/README.md#zephyr-firmware-for-micro-ros-setup) step. Then, follow instructions [here](https://dessert.unina.it:8088/runphi/partitioned_container_demos/-/blob/main/README.md) to build the image.

Once obtained k8s image, you can use the following pod manifest (assuming the image name ``dessertunina/microrospingpong:arm64jh``):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: zephyr-pingpong
spec:
  terminationGracePeriodSeconds: 0
  containers:

  - name: zephyr
    image: dessertunina/microrospingpong:arm64jh
    imagePullPolicy: Always

  nodeName: buildroot
```

## Additional Resources

- [ROS2 Installation Guide](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debians.html)
- [Micro-ROS Zephyr Emulator Tutorial](https://micro.ros.org/docs/tutorials/core/zephyr_emulator/)
- [Zephyr Getting Started Guide](https://docs.zephyrproject.org/latest/develop/getting_started/index.html)
- [Runphi Repository](https://dessert.unina.it:8088/ldesi/runphi)




