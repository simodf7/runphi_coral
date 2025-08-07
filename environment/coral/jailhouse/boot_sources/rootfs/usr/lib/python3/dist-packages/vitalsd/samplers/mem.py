"""
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


from vitalsd.samplers import sampler


class VmStatSampler(sampler.Sampler):
    def name(self):
        return 'vmstat'

    def sample(self):
        samples = []
        with open('/sys/devices/system/node/node0/vmstat', 'r') as fp:
            while fp.read(1) != '':
                fp.seek(fp.tell() - 1)
                line = fp.readline()[0:-1]
                end_of_file = False
                while not end_of_file:
                    ch = fp.read(1)
                    if ch != '':
                        if ord(ch) == 0x20:
                            line += ' ' + fp.readline()[0:-1]
                        else:
                            fp.seek(fp.tell() - 1)
                            break
                    else:
                         end_of_file = True

                (key, *values) = line.split(' ')
                samples.append('='.join([key, ','.join(values)]))
        return ['|'.join(samples)]
