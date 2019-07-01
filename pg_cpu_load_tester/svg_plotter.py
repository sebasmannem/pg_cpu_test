#!/usr/bin/env python
import matplotlib.pyplot as plt
import numpy as np
import re
import sys
import os

import argparse

parser = argparse.ArgumentParser(description='Summarize results and graph into svg')
parser.add_argument('files', metavar='N', nargs='+', help='the files to proces')
parser.add_argument('-c', '--convolve', type=int, default=1, help='the files to proces')
args = parser.parse_args()

#2019-06-29 01:45:00.928474        1.088000     3881.492   7762985.000       4609.667            0.000
VALIDATOR_RE=re.compile('^[0-9]{4}(-[0-9]{2}){2} ([0-9]{2}:){2}[0-9]{2}(\.[0-9]+)?([ \t]+[0-9.]+)*$')
SPLITTER_RE=re.compile('[ \t]+')
PCL_PARALLEL_RE=re.compile('PCL_PARALLEL=([0-9]+)')
#logs.default/1561767352/pg_cpu_load_empty_transactional.log
PCL_TESTS='(baseline|no_fsync|tmpfs|wal_tmpfs|no_fsync_tmpfs)'
PCL_TYPES="(empty|simple|temp_read|temp_write|read write)"
PCL_MODES="(direct|prepared|transactional|prepared_transactional)"

PCL_INFO_RE=re.compile('logs.{0}/[0-9]+/pg_cpu_load_{1}_{2}.log$'.format(PCL_TESTS, PCL_TYPES, PCL_MODES))

thread_tps_list = []
pg_tps_list = []

plots_info = {}

for filepath in args.files:
    filedir = os.path.dirname(filepath)
    envfile = os.path.join(filedir, 'env')
    if not os.path.exists(envfile):
        print('{} does not exist. Skipping {}.'.format(envfile, filepath))
        continue
    try:
        plot_info = plots_info[filedir]
    except:
        plot_info = plots_info[filedir] = {}
        with open(envfile) as env:
            for line in env:
                if '=' not in line:
                    continue
                key, value = line.split('=', 1)
                plot_info[key.strip()] = value.strip()

    m = PCL_INFO_RE.search(filepath)
    if m:
        plot_info['PCL_TEST'] = m.group(1)
        plot_info['PCL_TYPE'] = m.group(2)
        plot_info['PCL_MODE'] = m.group(3)
    else:
        print('File {} does not match re {}. SKipping...'.format(filepath, PCL_INFO_RE))
        continue

    with open(filepath) as filelines:
        for line in  filelines:
            line = line.strip()
            if not VALIDATOR_RE.search(line):
                continue
            cols = SPLITTER_RE.split(line)
            try:
                thread_tps_list.append(float(cols[4]))
                pg_tps_list.append(float(cols[5]))
            except ValueError as err:
                print(cols)
                print(cols[4], cols[5])
                raise(err)

    plt.figure()
    plt.title('{PCL_TEST}: {PCL_TYPE}, {PCL_MODE} ({PCL_PARALLEL} threads)'.format(**plot_info))
    plt.plot(np.convolve(thread_tps_list, np.ones((args.convolve,))/args.convolve, mode='valid'), label='threads_tps')
    plt.plot(np.convolve(pg_tps_list, np.ones((args.convolve,))/args.convolve, mode='valid'), label='pg_tps')
    plt.axis('auto')
    plt.legend()
    plt.savefig(filepath+".svg")
