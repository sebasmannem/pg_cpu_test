#!/usr/bin/env python
import matplotlib.pyplot as plt
import numpy as np
import re
import sys
import os
import statistics

import argparse

def parse_arg(argname, parsed, choices):
    if parsed == 'all':
        return choices
    invalid = [arg  for arg in parsed.split(',') if arg not in choices]
    if invalid:
        raise Exception(argname, 'has invalid arguments', ', '.format(parsed))
    return choices

PCL_TESTS=[ 'baseline', 'no_fsync', 'tmpfs', 'wal_tmpfs', 'no_fsync_tmpfs' ]
PCL_TYPES=[ 'empty', 'simple', 'temp_read', 'temp_write', 'read', 'write' ]
PCL_MODES=[ 'direct', 'prepared', 'transactional', 'prepared_transactional' ]

parser = argparse.ArgumentParser(description='Summarize results and graph into svg')
parser.add_argument('files', metavar='N', nargs='+', help='the files to proces')
parser.add_argument('-c', '--convolve', type=int, default=1, help='the files to proces')
parser.add_argument('-t', '--tests', default='all', help='The tests to add in summary')
parser.add_argument('-q', '--querytypes', default='all', help='The tests to add in summary')
parser.add_argument('-m', '--modes', default='all', help='The tests to add in summary')
parser.add_argument('-r', '--recreate', action='store_true', help='Recreate all graphs')

args = parser.parse_args()
SUM_TESTS=parse_arg('--tests', args.tests, PCL_TESTS)
SUM_QTYPES=parse_arg('--querytypes', args.querytypes, PCL_TYPES)
SUM_MODES=parse_arg('--modes', args.modes, PCL_MODES)

#2019-06-29 01:45:00.928474        1.088000     3881.492   7762985.000       4609.667            0.000
VALIDATOR_RE=re.compile('^[0-9]{4}(-[0-9]{2}){2} ([0-9]{2}:){2}[0-9]{2}(\.[0-9]+)?([ \t]+[0-9.]+)*$')
SPLITTER_RE=re.compile('[ \t]+')
PCL_PARALLEL_RE=re.compile('PCL_PARALLEL=([0-9]+)')
#logs.default/1561767352/pg_cpu_load_empty_transactional.log

PCL_INFO_RE=re.compile('(logs.(?P<PCL_SYSTEM>[0-9a-zA-Z_]*)/)?logs.(?P<PCL_TEST>[0-9a-zA-Z_]*)/[0-9]+/pg_cpu_load_(?P<PCL_TYPE>{1})_(?P<PCL_MODE>{2}).log$'.format('|'.join(PCL_TESTS), '|'.join(PCL_TYPES), '|'.join(PCL_MODES)))

plots_info = {}

print('system         test           querytype  query_mode             threads  thread_avg  thread_std      pg_avg    pg_stdev')
for filepath in args.files:
    filedir = os.path.dirname(filepath)
    envfile = os.path.join(filedir, 'env')

    if not os.path.exists(envfile):
        sys.stderr.write('{} does not exist. Skipping {}.\n'.format(envfile, filepath))
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
        plot_info.update(m.groupdict())
    else:
        sys.stderr.write('File {} does not match re {}. SKipping...\n'.format(filepath, PCL_INFO_RE))
        continue

    thread_tps_list = []
    pg_tps_list = []

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

    if not thread_tps_list:
        print('{0} does not contain any data'.format(filepath))
        continue
    plot_info['THREAD_AVG'] = sum(thread_tps_list) / len(thread_tps_list)
    plot_info['THREAD_STDEV'] = statistics.stdev(thread_tps_list)
    plot_info['PG_AVG'] = sum(pg_tps_list) / len(pg_tps_list)
    plot_info['PG_STDEV'] = statistics.stdev(pg_tps_list)
    plot_info['PCL_PARALLEL'] = int(plot_info['PCL_PARALLEL'])
    if not plot_info['PCL_SYSTEM']:
        plot_info['PCL_SYSTEM'] = 'unknown'
    print('{PCL_SYSTEM:14s} {PCL_TEST:14s} {PCL_TYPE:10s} {PCL_MODE:22s} {PCL_PARALLEL:7d} {THREAD_AVG:11.3f} {THREAD_STDEV:11.3f} {PG_AVG:11.3f} {PG_STDEV:11.3f}'.format(**plot_info))

    if args.recreate or not os.path.exists(filepath+".svg"):
        # Initialize the graph
        fig = plt.figure()
        subplot_title = '{PCL_TEST}: {PCL_TYPE}, {PCL_MODE} ({PCL_PARALLEL} threads)'.format(**plot_info)
        ax = fig.add_subplot(autoscale_on=True, title=subplot_title)
        ax.plot(thread_tps_list, label='threads_tps')
        ax.plot(pg_tps_list, label='pg_tps')
        ax.set_xlabel('Sec')
        ax.set_ylabel('Tps')
        ax.legend()
        fig.savefig(filepath+".svg")
        plt.close(fig)
