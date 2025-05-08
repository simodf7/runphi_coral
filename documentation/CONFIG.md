The configuration file includes settings for TO-BUILD components, allowing you to specify the desired configuration for each. 
Each component has a `<component>_CONFIG` setting in the configuration file. This setting determines which specific configuration to use. 
Below is an explanation of how these settings work and how to use them effectively.

### Linux Configuration
- If `LINUX_CONFIG=""` (empty), the default configuration `<target>_<backend>_kernel_defconfig` will be used.
- If `LINUX_CONFIG="isolcpu"`, the configuration `<target>_<backend>_isolcpu_kernel_defconfig` will be used.

#### Saving a New Configuration
After modifying and testing a Linux configuration, you can save it under a new name. For example:
1. Set `LINUX_CONFIG="test"`.
2. Run the script `linux_save_defconfig.sh`.

This will save the configuration as `<target>_<backend>_test_kernel_defconfig`.

### Boot Sources Configuration
The same approach applies to boot sources, such as `boot.cmd` and `system.dts`. 
The relevant compile scripts will use the specified configuration:

#### Boot Command (`bootcmd`)
- If `BOOTCMD_CONFIG=""` (empty), the default `config.h` will be compiled.
- If `BOOTCMD_CONFIG="nfs"`, the script will compile `config_nfs.h`.

To compile the boot command, use the script `bootcmd_compile.sh`.

#### Device Tree (`devicetree`)
The same logic applies to device tree configurations. Use the script `dts_compile.sh` to compile the specified configuration.

### Summary
- Use `<component>_CONFIG` to specify the desired configuration.
- Save new configurations by setting the appropriate variable and running the corresponding save script.
- Compile boot sources and device trees using their respective compile scripts, based on the configuration specified.