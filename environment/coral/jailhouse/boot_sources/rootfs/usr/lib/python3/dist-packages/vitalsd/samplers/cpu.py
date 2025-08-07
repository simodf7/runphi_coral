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


class UptimeSampler(sampler.Sampler):
    def name(self):
        return 'uptime'

    def sample(self):
        with open('/proc/uptime', 'r') as fp:
            uptime = fp.readline()
            uptime = uptime.split(' ')
            return uptime[0:-1]


class CpuLoadSampler(sampler.Sampler):
    def name(self):
        return 'loadavg'

    def sample(self):
        with open('/proc/loadavg', 'r') as fp:
            loadavg = fp.readline()
            loadavg = loadavg.split(' ')
            return loadavg[0:-1]
