#!/usr/bin/env python
import time
import psycopg2
import datetime
import sys

def lsn_to_walbyte(lsn):
    """Convert a LSN to a integer pointing to an exact byte in the wal stream."""
    # Split by '/' character
    try:
        walid, xrecoff = lsn.split('/')
    except AttributeError:
        return 0

    # Convert both from hex to int
    walid = int(walid, 16)
    xrecoff = int(xrecoff, 16)

    # multiply wal file nr to offset by multiplying with 2**32, and add offset
    # in file to come to absolute int position of lsn and return result
    return walid * 2**32 + xrecoff

cn = psycopg2.connect('')
cur = cn.cursor()
lastdt = lastval = lasttact = None
while True:
    cur.execute('BEGIN')
    cur.execute("SELECT now(), pg_current_wal_lsn(), (select sum(xact_commit+xact_rollback) FROM pg_stat_database)")
    currow = cur.next()
    curdt, curlsn, curtact = currow
    curlsn = lsn_to_walbyte(curlsn)
    if lastdt and lasttact and lastlsn:
         dtdiff = (curdt - lastdt).total_seconds()
         tactps = float(curtact-lasttact)/dtdiff
         lsnps = (curlsn-lastlsn)/dtdiff
         print('DT: {0}, TPS: {1}, WAL: {2}'.format(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'), tactps, lsnps))
         sys.stdout.flush()
    cur.execute('ROLLBACK')
    lastdt, lasttact, lastlsn = curdt, curtact, curlsn
    time.sleep(1)
