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


import glob
import os
import time


class Sampler(object):
    def sample(self):
        return 'unknown'

    def name(self):
        return 'unknown'

    def __str__(self):
        result = [self.name()]
        result.extend(self.sample())
        return '\t'.join(result)


class SysPathSampler(Sampler):
    def __init__(self, sys_dir):
        print(f'Monitoring path {sys_dir}')
        self.dir = sys_dir

    def name(self):
        return self.dir

    def sample(self):
        samples = []
        for node in os.scandir(self.dir):
            if node.is_dir():
                continue
            try:
                with open(node.path, 'r') as fp:
                    samples.append('='.join([node.name, fp.readline()[0:-1]]))
            except BaseException as e:
                samples.append('='.join([node.name, str(e)]))
        return ['|'.join(samples)]


def MakeSamplersFromSysPath(sys_dir_path):
    return [SysPathSampler(dir) for dir in glob.glob(sys_dir_path)]


class IterationSampler(Sampler):
    def __init__(self):
        self.iteration = 0

    def name(self):
        return 'iteration'

    def sample(self):
        self.iteration = self.iteration + 1
        return [str(self.iteration)]


class TimeSampler(Sampler):
    def name(self):
        return 'time'

    def sample(self):
        return [str(time.time())]
