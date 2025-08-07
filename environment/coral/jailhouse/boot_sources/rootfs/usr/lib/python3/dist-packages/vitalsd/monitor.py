import serial
import sys
import time

from vitalsd.samplers import sampler
from vitalsd.samplers import cpu
from vitalsd.samplers import mem

DEFAULT_SAMPLERS = [
    sampler.IterationSampler(),
    sampler.TimeSampler(),
    cpu.UptimeSampler(),
    cpu.CpuLoadSampler(),
    mem.VmStatSampler(),
]

DEFAULT_SAMPLERS.extend(sampler.MakeSamplersFromSysPath('/sys/class/thermal/thermal_zone*'))
DEFAULT_SAMPLERS.extend(sampler.MakeSamplersFromSysPath('/sys/class/thermal/cooling_device*'))
DEFAULT_SAMPLERS.extend(sampler.MakeSamplersFromSysPath('/sys/class/regulator/regulator.*'))
DEFAULT_SAMPLERS.extend(sampler.MakeSamplersFromSysPath('/sys/kernel/irq/*'))
DEFAULT_SAMPLERS.extend(sampler.MakeSamplersFromSysPath('/sys/devices/system/cpu'))


class FakeSerial(object):
    def write(self, bytes):
        print(str(bytes, 'utf-8'))

    def flush(self):
        sys.stdout.flush()


class Monitor(object):
    def __init__(self, delay_secs=10, serial_device=None, speed=115200):
        self.delay_secs = delay_secs
        self.serial_device = serial_device
        self.speed = speed
        self.samplers = DEFAULT_SAMPLERS

        if serial_device is None:
            print('No serial device specified: samples going to stdout!')
            self.port = FakeSerial()
            self.is_serial_port = False
        else:
            self.is_serial_port = True
            self.port = serial.Serial(port=self.serial_device, baudrate=self.speed)
            print(f'Writing to port {self.port.name}')

    def run(self):
        iteration = 0
        port = self.port

        while True:
            iteration = iteration + 1
            print(f'Sending iteration {iteration}')

            for sampler in self.samplers:
                if self.is_serial_port:
                    sample = '{0}\r\n'.format(str(sampler))
                else:
                    sample = '{0}'.format(str(sampler))

                port.write(bytes(sample, 'utf-8'))
                port.flush()

            time.sleep(self.delay_secs)
