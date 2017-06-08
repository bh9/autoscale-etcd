#!/usr/bin/env python
import etcd
import time
import psutil
import pycurl
import cStringIO
import sys
import subprocess

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
client = etcd.Client(host=IP, port=12379) #set up the etcd client
lock = etcd.Lock(client, 'bh9testlock') #establish the lock object
time.sleep(20) #wait for other cluster members to recognise your existence
while True:
  try:
    stats = client.members #find the number of members and compare to the minimum
    print len(stats)
    members = len(stats)
    if int(minimum) < members:
      print "over minimum, checking metrics"
      if psutil.cpu_percent() < 10: #if there are more members than the minimum, check cpu_percent
        print "below threshold, acquiring lock"
        try:
          print "lock acquiring"
          lock.acquire(blocking=False, lock_ttl=200, timeout=5) #try to get the lock if you're idle
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
    else:
      print "only " + str(members) + " members, not deleting"
  except etcd.EtcdException:
    print "EtcdException occured, but not in the locking section"
  time.sleep(10) #wait 10 seconds then try again. Agressiveness will be tunable in future

