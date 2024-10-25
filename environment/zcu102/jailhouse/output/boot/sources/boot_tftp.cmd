# This is a boot script for U-Boot.
# Generate boot.scr:
# mkimage -c none -A arm -T script -d boot.cmd boot.scr
#

kernel_path="/zcu102_3/Image"
dtb_path="/zcu102_3/system.dtb"
# dhcp ${script_addr} "/zcu102_3/boot.scr" ; source ${script_addr}

additional_bootargs="mem=256M"

# Addresses from https://www.kernel.org/doc/Documentation/arm/Booting
setenv script_addr 0x00100000
setenv kernel_addr 0x01000000 #0x02000000
setenv dtb_addr    0x05000000 #0x08000000
setenv last_addr   0x10000000 # You are leaving the DDR
setexpr max_kernel_size ${dtb_addr} - ${kernel_addr}
setexpr max_dtb_size ${last_addr} - ${dtb_addr}

echo "======================"
echo "=== Loading kernel ==="
echo "======================"
dhcp ${kernel_addr} ${kernel_path};
if itest "${filesize}" > "${max_kernel_size}" ; then
	echo "Kernel too large!";
	echo "May have 0x${max_kernel_size} byte, has 0x${filesize} byte."
	exit;
fi

echo "======================"
echo "===  Loading dtb   ==="
echo "======================"
dhcp ${dtb_addr} ${dtb_path};
if itest "${filesize}" > "${max_dtb_size}" ; then
	echo "Device tree blob too large!";
	echo "May have 0x${max_dtb_size} byte, has 0x${filesize} byte."
	exit;
fi

# NFS
setenv bootargs "earlycon root=/dev/nfs nfsroot=/tftpboot/%s,vers=3,sec=sys  ip=dhcp rw rootwait console=ttyPS0,115200n8 clk_ignore_unused ${additional_bootargs}"
# Ubuntu rootfs
#setenv bootargs "earlycon clk_ignore_unused earlyprintk root=/dev/mmcblk0p2 rw rootwait"
booti ${kernel_addr} - ${dtb_addr};

