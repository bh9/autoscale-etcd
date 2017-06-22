#!/usr/bin/env python
import etcd
import time
import psutil
import pycurl
import cStringIO
import sys
import subprocess

METRIC="$thisisametric"
buf=cStringIO.StringIO()
curl = pycurl.Curl()
curl.setopt(curl.URL, "http://169.254.169.254/2009-04-04/meta-data/local-ipv4")
curl.setopt(curl.WRITEFUNCTION, buf.write)
curl.perform()
IP = buf.getvalue() #get the instance's ip
curl.close()
buf.close()
f = open('/etc/sysconfig/etcd-size', 'r')
minimum = f.readline() #get the minimum cluster size
f.close()
client = etcd.Client(host=IP, port=$thisisaclientport) #set up the etcd client
lock = etcd.Lock(client, 'killlock') #establish the lock object
makelock = etcd.Lock(client, 'makelock')
time.sleep(20) #wait for other cluster members to recognise your existence
while True:
  try:
    stats = client.members #find the number of members and compare to the minimum
    print len(stats)
    members = len(stats)
    if int(minimum) < members:
      print "over minimum, checking metrics"
      buf=cStringIO.StringIO()
      curl = pycurl.Curl()
      curl.setopt(curl.URL, "http://localhost:19999/api/v1/allmetrics")
      curl.setopt(curl.WRITEFUNCTION, buf.write)
      curl.perform()
      METRICS = buf.getvalue() #get the instance's ip
      curl.close()
      buf.close()
      FIRSTPOS=METRICS.find(METRIC)
      LENMET=len(METRIC)
      METRICVALUE=METRICS[FIRSTPOS+LENMET:].partition('\"')[0]
      if METRICVALUE $thisisacomparator $thisisathreshold: #if there are more members than the minimum, check cpu_percent
        print "beyond threshold, acquiring lock"
        try:
          print "lock acquiring"
          lock.acquire(blocking=False, lock_ttl=$thisisatimeout, timeout=5) #try to get the lock if you're idle
          print "lock acquiring complete"
        except etcd.EtcdException:
          print "EtcdException occured, I might not be a member of the cluster"
        print "lock play done"
        if lock.is_acquired:
          print "got it" #if the lock is acquired, announce that you will remove yourself
          print "killing myself shortly"
          file1 = open("/var/log/etcd_kill.log", "w")
          subprocess.call(['/var/lib/etcd/suicide.sh'], stdout = file1) #and then remove yourself
          quit()
        else:
          print "didn't get it, joining queue"
          print "someone else is killing themselves so I'll try again later"
      else:
        print "active"
    elif int(minimum) = members:
      print "only " + str(members) + " members, not deleting"
    else:
      print "fewer than " + minimum + " members, attempting creation"
      try:
        print "lock acquiring"
        makelock.acquire(blocking=False, lock_ttl=$thisisatimeout, timeout=5) #try to get the lock if you're idle
        print "lock acquiring complete"
      except etcd.EtcdException:
        print "EtcdException occured, I might not be a member of the cluster"
      print "lock play done"
      if makelock.is_acquired:
        file1 = open("/var/log/etcd_make.log", "w")
        subprocess.call(['/var/lib/etcd/recover.sh'], stdout = file1)
        print "posting to scale up url, expecting instance shortly"
      else:
        print "didn't get the lock, someone else is bringing up an instance"
  except etcd.EtcdException:
    print "EtcdException occured, but not in the locking section"
  time.sleep($thisisanattemptperiod) #wait 10 seconds then try again. Agressiveness will be tunable in future

