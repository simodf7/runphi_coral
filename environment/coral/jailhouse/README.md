# Flash Guide for Coral Dev Board

These steps are required to flash the Google Coral Dev Board. After this process, you will be able to run Mendel Linux and Jailhouse on a fresh board. 


## 1. Gather Requirements

> **Note:** Before doing these steps, it's mandatory to have built a bootable image in the RunPHI directory. To create a bootable image, follow the instruction shown in the section **Setup for Google Coral Dev Board** in the main README.md 

Requirements: 

1. **Host computer** running Linux.    
2. **microSD card** (≥ 8 GB) + adapter to connect it to your host computer.
3. **USB‑C power supply** (5 V, 2–3 A), such as a phone charger. 



## 2. Flash the `flashcard_custom.img` file to your microSD card 


Before flashing, connect the adapter to your host computer. Proceed now to identify the microSD card. To do so, open a terminal and execute this command: 

```
$ lsblk
```

All your memory storages will be printed and you'll likely find something like `sdX`, for example `sdA`. This is your microSD card. 

Now we recommend to delete any partitions on your microSD card:

```
$ sudo fdisk /dev/sdX 
> type o
> type w
``` 

> **Note:** we are not anymore in RunPHI container

At this point, we are ready to flash the microSD card with the obtained booting image. In order to do so, run this command (replacing sdX with the correct letter): 

```
$ sudo dd if=flashcard_custom.img of=/dev/sdX bs=4M status=progress
$ sync
``` 

This process will be a bit slow, but don't worry, everything is fine. 


## 3. Setting the boot mode switches 

Once the previous process is ended, now we're ready to insert our SD card into the Board. 
Before doing so, we need to configure the board to boot from the SD card. In the Google Coral Dev Board, this is realized by setting the boot mode switches as shown below:

| Boot mode | Switch 1 | Switch 2 | Switch 3 | Switch 4 |
|-----------|----------|----------|----------|----------|
| SD card   | ON       | OFF      | ON       | ON       |


> **Note:** DO NOT connect the board to power until we do not have set properly the boot mode switches and inserted out SD card into the board. If we connect the board to power, flashing process will begin. 


## 4. (Optional) Set up Serial Console 

If you'd like to see the bootloader logs while the board is being flashed, either connect a monitor to the board's HDMI port or connect to the board's serial console. Nothing will appear until you power the board in the next step.

To connect to the board's serial console, you'll need a **USB-A to USB-micro-B cable** (USB data cable). Follow these steps:

### Linux 

1. Make sure your Linux user account is in the `plugdev` and `dialout` system groups by running this command:

```
$ sudo usermod -aG plugdev,dialout <username>
```
Then reboot your computer for the new groups to take effect. 

2. Connect your computer to the board with the micro-B USB cable. 
3. Determine the device filename for the serial connection by running this command on your Linux computer:
```
$ dmesg | grep ttyUSB
```
You should see two results such as this: 

```
[ 6437.706335] usb 2-13.1: cp210x converter now attached to ttyUSB0
[ 6437.708049] usb 2-13.1: cp210x converter now attached to ttyUSB1
```
If you don't see results like this, double-check your USB cable.

4. Then connect with this command (using the name of the first device listed as "cp210x converter"): 

```
$ screen /dev/ttyUSB0 115200
```

5. When the screen terminal opens, it will probably be blank. When you're about to begin flashing process for the first time, the screen will be blank and it will start to show something when the board will be connected to power (Refer to next step). 

### Windows 

1. Connect your computer to the board with the micro-B USB cable, and connect the board to power. 

2. On your Windows computer, open Device Manager and find the board's COM port.

    Within a minute of connecting the USB cable, Windows should automatically install the necessary driver. If you expand Ports (COM & LPT), you should see two devices with the name "Silicon Labs Dual CP2105 USB to UART Bridge".

    Take note of the COM port for the device named "Enhanced COM Port" (such as "COM3"). You'll use it in the next step.

    If Windows cannot identify the device, it should instead be listed under Other devices. If the driver has not been installed by Windows, you could download it manually at the following link: https://www.silabs.com/developer-tools/usb-to-uart-bridge-vcp-drivers?tab=downloads. Right-click on Enhanced Com Port and select Update driver to find the appropriate device driver.

3. Open PuTTY or another serial console app and start a serial console connection with the above COM port, using a baud rate of 115200. For example, if using PuTTY:

        - Select Session in the left pane.

        - For the Connection type, select Serial.

        - Enter the COM port ("COM3") for Serial line, and enter "115200" for Speed.

        - Then click Open.

4. Again when the screen terminal opens, it will probably be blank. Read point 5 (Linux). 

## 5. Insert SD card into the board 


After setting properly the boot mode, we can insert the SD Card into the board and then power up the board. If you completed the optional serial console setup, right after powering the board, the bootloader logs will start showing up on the console. This action will start eMMC flashing.
As we do this, the board's red LED should turn on. 

The process should finish after 5-10 minutes, depending on the speed of your microSD card. You'll know it's done when the board shuts down and the red LED turns off. 


## 6. Change boot mode switches to eMMC mode. 

When the red LED turns off, unplug the power and remove the microSD card. 
Change the boot mode switches so the board boots from eMMC on next power up. Impose this configuration: 


| Boot mode | Switch 1 | Switch 2 | Switch 3 | Switch 4 |
|-----------|----------|----------|----------|----------|
| SD card   | ON       | OFF      | OFF      | OFF      |



## 7. Final step 

After setting up the boot switches, connect the board to power and it should now boot up Mendel Linux.
Booting up for the first time after flashing takes about 3 minutes (subsequent boot times are much faster). 

When flashing is done, you can click `Enter` on the serial console and it will ask you 
username and password. 

> **Default username**: **mendel** \
> **Default password**: **mendel**

At this point, process is completely done. You can now use **Mendel Linux** and **Jailhouse** as you wish. To ensure Jailhouse is correctly installed, type this command: 

```
$ jailhouse 
```

If everything is going as it should, it should show this: 

```
Usage: jailhouse { COMMAND | --help | --version }

Available commands:
   enable SYSCONFIG
   disable
   console [-f | --follow]
   cell create CELLCONFIG
   cell list
   cell load { ID | [--name] NAME } { IMAGE | { -s | --string } "STRING" }
             [-a | --address ADDRESS] ...
   cell start { ID | [--name] NAME }
   cell shutdown { ID | [--name] NAME }
   cell destroy { ID | [--name] NAME }

``` 


> **Reference:** https://coral.ai/docs/dev-board/get-started/#flash-the-board  




