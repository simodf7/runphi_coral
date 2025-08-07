#!/usr/bin/env python3

"""vitalsd - A vital statistics monitoring tool for embedded systems

This is the main CLI dispatch routine that teases out the command line and runs
the appropriate command.


Copyright 2019 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

import sys
import argparse

from vitalsd.monitor import Monitor


def main():
    parser = argparse.ArgumentParser(
        description='output vital system statistics to a serial console')
    parser.add_argument('--delay', type=int, default=10,
                        help='delay in seconds to wait before outputting another'
                        'set of vitals.')
    parser.add_argument('--speed', type=int, default=115200,
                        help='the bit rate to output at')
    parser.add_argument('--device', type=str, default=None,
                        help='the serial device to output to')
    args = parser.parse_args()

    try:
        monitor = Monitor(delay_secs=args.delay,
                          serial_device=args.device,
                          speed=args.speed)
        monitor.run()
    except KeyboardInterrupt:
        print('Terminating.')
        exit(1)


if __name__ == '__main__':
    main()
