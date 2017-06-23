#!/bin/bash
set -ex
IP=$(curl 169.254.169.254/latest/meta-data/local-ipv4)
while true; do
    PEERS=$(curl -s -m 10 $IP:$thisisaclientport/v2/members | jq -r '.[] | .[].clientURLs | .[]')
    for i in $PEERS; do
        set +e
        x=0
        curl -m 10 $i/health
        x=$?
        set -e
        if [ $x != 0 ]; then
            DEADIP=$(echo $i | cut -d/ -f3 | cut -d: -f1)
            MEMBER_ID=$(curl -s $etcd_client_scheme://$IP:$thisisaclientport/v2/members | jq ".members[] | select(.name == \"$DEADIP\") | .id" | sed "s/\"//g")
            curl -XDELETE -s $etcd_client_scheme://$IP:$thisisaclientport/v2/members/$MEMBER_ID
            echo deleting absent member $i
        fi
    done
    sleep $thisisanattemptperiod
done
