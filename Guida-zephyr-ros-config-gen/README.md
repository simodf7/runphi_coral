# Micro-ROS and Zephyr Setup Guide

This repository contains the necessary materials and instructions to set up a micro-ROS and Zephyr environment.

## Repository Contents
- `cells/`
- `ping_pong_docker/`
- `zephyr/`
- `zephyr_apps/`
- `create.sh`
- `runphi_docker.sh`
- `zephyr.bin`

## Directory Structure
After following the steps below, you will have the following structure in your home directory:

    
    home/
    ├── microros_ws/
    ├── runphi/
    ├── runphi_docker.sh
    ├── zephyrproject/ (optional)
    └── zephyr-sdk-0.16.8/ (optional)
    

## ROS2 and Micro-ROS Installation

We referred to guide in [https://micro.ros.org/docs/tutorials/core/zephyr_emulator/](https://micro.ros.org/docs/tutorials/core/zephyr_emulator/).

1. **Install ROS2**
   
   We recommend to install ROS2 via a docker container. We tested ``ROS2 HUMBLE`` version.

    ```
    # mkdir ${HOME}/microros_ws
    # docker run -it -v /dev:/dev -v ${HOME}/microros_ws:/microros_ws -p 8888:8888/udp --privileged --name ros_humble_runphi ros:humble
    ```
    
    Port 8888/UDP is published to allow microros broker to be contacted by outside.
   
2. **Setup Micro-ROS Workspace**
   
   Follow this modified version of the guide [here](https://micro.ros.org/docs/tutorials/core/zephyr_emulator/):

   ```
    ## Check $ROS_DISTRO, should be humble
    
    # echo $ROS_DISTRO
    humble

    ## Source the ROS 2 installation
    source /opt/ros/$ROS_DISTRO/setup.bash

    ## Create a workspace and download the micro-ROS tools
    # cd microros_ws
    # git clone -b $ROS_DISTRO https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup

    ## Update dependencies using rosdep
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

    We assmume microROS broker is running on host with a bridge with IP ``192.0.3.1`` (is the br0 IP set in qemu-jailhouse environment, check (this)[https://dessert.unina.it:8088/runphi/partitioned_container_demos/-/blob/main/demos/README.md#from-host-machine].)

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

All build artifacts are in ``/microros_ws/firmware/build/zephyr/`` dir. The ``zephyr.bin`` is the binary to be used as inmate in partitioned container.

## ROS2 Agent

1. **Run these commands to create, build, and run the ROS2 agent:**

    ```bash
    # Download micro-ROS-Agent packages
    ros2 run micro_ros_setup create_agent_ws.sh

    # Build step
    ros2 run micro_ros_setup build_agent.sh
    source install/local_setup.bash

    # Run a micro-ROS agent
    ros2 run micro_ros_agent micro_ros_agent udp4 --port 8888

## Zephyr and Zephyr-SDK Installation
Note: micro-ROS has its own Zephyr and Zephyr-SDK environment, so installing an additional instance is optional.

1. **Follow the guide [here](https://docs.zephyrproject.org/latest/develop/getting_started/index.html) for installation.**

2. **To build different Zephyr images, navigate to:**

    ```bash
    $HOME/microros_ws/firmware/zephyrproject/zephyr

3. **If zephyr is also installed in the home directory it's possible to use west also here:**

    ```bash
    $HOME/zephyrproject/zephyr

4. **Run the west build tool:**

    ```bash
    west build -p always -b qemu_cortex_a53 lite-jailhouse/zephyr_app/
    west build -p always -b qemu_cortex_a53 samples/drivers/ethernet/dhcp_ivshmem/

With these commands we can rebuild the binary for the hello world and dhcp apps

# Runphi Setup

1. **Clone thid branch of the official repository:**

    ```bash
    cd $HOME
    git clone -b zephyr_micro-ros_config-gen https://dessert.unina.it:8088/ldesi/runphi.git

2. **Ensure the following packages are installed: bridge-utils, uml-utilities, dnsmasq, and net-tools.**

3. **Copy runphi_docker.sh to your $HOME folder.**

4. **Build and run the Docker container:**

    ```bash
    cd runphi/docker
    docker build -t runphidocker .
    cd ../../
    sudo ./runphy_docker.sh

## Cells configuration

1. **Ensure the ROS2 agent is running:**

    ```bash
    ros2 run micro_ros_agent micro_ros_agent udp4 --port 8888

2. **Inside QEMU:**

    ```bash
    cd scripts_jailhouse_qemu/
    sh start_jailhouse_net.sh
    sh ping_pong_zephyr.sh


3. **From a terminal window, subscribe to the micro-ROS ping topic:**

    ```bash
    ros2 topic echo /microROS/ping


4. **From another terminal window, subscribe to the micro-ROS pong topic:**

    ```bash
    ros2 topic echo /microROS/pong


5. **From yet another terminal window, send a fake ping:**

    ```bash
    ros2 topic pub --once /microROS/ping std_msgs/msg/Header '{frame_id: "fake_ping"}'


You should see the fake_ping in the ping subscriber console, and the micro-ROS node in the Zephyr cell will respond with a pong, which will appear in the pong subscriber console.

# Orchestration

As of now, a Zephyr micro-ROS cell has been executed manually and its functioning has been tested. The next step is to set-up and test the RunPHI framework by deploying the partitioned container inside an automatically configured cell. 

1. **First, it is necessary to build the docker container for the application.**

    ```bash
    # Move to the provided folder:
    cd ping_pong_docker
    # Build and push the docker:
    docker build -t yourname/dockername:latestjh .
    docker push yourname/dockername:latestjh

2. **Now continue from the QEMU machine:**

    ```bash
    #Press CTRL+A X to exit from QEMU and start it again:
    /PATH_TO_RUNPHI/scripts/qemu/start_qemu.sh

    # Inside QEMU VM:

    # start Jailhouse and root cell (for Zephyr: jailhouse/configs/arm64/qemu-arm64-rootcell_ZEPHYR.cell)
    cd scripts_jailhouse_qemu/
    sh start_jailhouse_net.sh qemu-arm64-rootcell_ZEPHYR.cell

    # configure network by setting eth0 forwarning eth1 traffic (eth1 will be used by ZEPHYR cell)
    sh config_net.sh

    # From the host machine:
    # Set-up RunPHI workspace in /usr/share/runPHI dir inside the QEMU VM.
    cd /PATH_TO_RUNPHI/runPHI/runPHI_cell_configs
    
    # the following copy all stuff needed tu run partitioned containers
    ./set_runphi_ws.sh
    
    # Let QEMU node joining  as a node to a Kubernetes orchestrator cluster.
    # 
    # CHECK ISSUE: https://dessert.unina.it:8088/ldesi/runphi/-/issues/13
    # on the master node launch
    # kubeadm token create --print-join-command
    # Use the command generated, e.g.:
    # kubeadm join 192.168.100.21:6443 --token hq1d5p.xjn6t7288l3p4r3h --discovery-token-ca-cert-hash sha256:03da27c59362b40cc3d5b3e8a646c2e19d2855122ddc0005b68d0f5266cfc451)

    # If kubeadm kubeadm join fails run "kubeadm reset -f" 
    # However /var/lib/kubelet/configBR.yaml will be deleted, so add a mechanism to re-copy it from "environment/qemu/jailhouse/install/var/lib/kubelet/configBR.yaml"

3. **Create the app.yaml file as described in chapter four**

    Define the application manifest in control plane nodes as in the following:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
        name: demo
    spec:
        terminationGracePeriodSeconds: 0
        containers:
        - name: zephyr
        image: myname/myapp:latest
        resources:
            limits:
            memory: "200Mi"
            cpu: "2"
        requests:
            memory: "100Mi"
            cpu: "1"
        nodeName: buildroot

4. **Get the latest runphi binary and copy from host into QEMU VM**

    ```bash
    # Look /PATH_TO_RUNPHI/runPHI/rust_runphi/README.md
    # scp /PATH_TO_RUNPHI/runPHI/rust_runphi/target/aarch64-unknown-linux-gnu/release/runphi to QEMU VM
    scp /PATH_TO_RUNPHI/runPHI/rust_runphi/target/aarch64-unknown-linux-gnu/release/runphi root@192.0.7.36:/root/runphi
    ```

5. **From the QEMU machine:**

    ```bash
    cd /usr/share/runPHI
    # Start the kubelet
    sh ./start_kubelet.sh

    # Replace runc executable with RunPHI
    cp /usr/bin/runc /usr/local/sbin/runc_vanilla

    cp /root/runphi /usr/bin/runc

    ## Launch containerd patched for Jailhouse ARM64 with runphi config.toml
    /usr/bin/containerd_arm64jh --config /etc/containerd/containerd_runphi_config.toml --log-level info > /var/log/container.log 2>&1

    # setup FLANNEL
    sh setup_flannel.sh

6. **Run the POD**
    From the k8s control plane node:

    ```bash
    # To start the partitioned container
    kubectl apply -f app.yaml
    
    # To destroy the partitioned container
    kubectl delete -f app.yaml
    ```

## Additional Resources

- [ROS2 Installation Guide](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debians.html)
- [Micro-ROS Zephyr Emulator Tutorial](https://micro.ros.org/docs/tutorials/core/zephyr_emulator/)
- [Zephyr Getting Started Guide](https://docs.zephyrproject.org/latest/develop/getting_started/index.html)
- [Runphi Repository](https://dessert.unina.it:8088/ldesi/runphi)




