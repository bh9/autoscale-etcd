#!/bin/bash
set -ex
set pipefail
etcd_hosts=$(openstack server list -c Networks -c Name | gawk "/a$CI_BUILD_ID/"' {match($0,/((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/); ip = substr($0,RSTART,RLENGTH); print ip}')
first_host=$(echo "$etcd_hosts" | head -n 1)
x=1
while [ $((x)) -gt 0 ];do
    set +e 
    wget -qO- --timeout 30 http://$first_host:12379/v2/members 
    x=$?
    set -e
    sleep 5
done
for i in ${etcd_hosts}; do
    newtotal=$(wget -qO- --timeout 30 http://${i}:12379/v2/members | jq '.[] | length')
    if [ -n "$lasttotal" ]; then
        if [ $((newtotal)) -eq $((lasttotal)) ]; then
            echo "$i" agrees
            lasttotal="$newtotal"
        else
            echo "$i" doesnt agree
            exit 1
        fi
    else
        if [ -z "$first" ]; then
            echo first node
            lasttotal="$newtotal"
            first="nope"
        else
            echo this is not the first node, the previous node returned 0 members
            exit 2
        fi
    fi
done
x=1
while [ $((x)) -gt 0 ];do
    set +e 
    wget -qO- --timeout 30 http://$first_host:8080/_status/nodes
    x=$?
    set -e
    sleep 5
done
crnodes=$(wget -qO- --timeout 30 ${first_host}:8080/_status/nodes | jq '.[]|length')
echo "$crnodes"
if [ $((crnodes)) -eq $((lasttotal)) ]; then
    echo cockroach agrees on cluster size with etcd
    exit 0
else
    echo cockroach disagrees with etcd
    exit 3
fi

