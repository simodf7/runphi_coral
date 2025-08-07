#!/bin/bash

sed -i -e 's/load-module module-udev-detect$/load-module module-udev-detect tsched=0/' /etc/pulse/default.pa

DEFAULT_SINK="set-default-sink alsa_output.platform-sound-rt5645.HiFi__hw_0__sink"
grep -qF -- "$DEFAULT_SINK" "/etc/pulse/default.pa" || echo "$DEFAULT_SINK" >> "/etc/pulse/default.pa"
