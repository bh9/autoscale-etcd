#!/bin/bash
set -ex
curl https://binaries.cockroachdb.com/cockroach-latest.linux-amd64.tgz > cockroach.tgz
tar xfz cockroach.tgz
cp -i cockroach-latest.linux-amd64/cockroach /usr/local/bin
cockroach version
myip=$(curl -s -m 100 http://169.254.169.254/2009-04-04/meta-data/local-ipv4)
leader=$(curl -k -m 100 $thisisaclientscheme://$myip:$thisisaclientport/v2/stats/leader | jq -r '.[]')
if [ "$leader" = 'not current leader' ]; then
    leaderid=$(curl -k -m 100 $thisisaclientscheme://$myip:$thisisaclientport/v2/stats/self | jq '.leaderInfo.leader')
    leaderip=$(curl -k -m 100 $thisisaclientscheme://$myip:$thisisaclientport/v2/members | jq -r ".members[] | select(.id == $leaderid) | .name")
    while [ -z $connected ]; do
	set +e
	cockroach node ls --insecure --host $leaderip
	if [ $? -eq 0 ]; then
	    set -e
            echo joining cluster, exiting
            x=1
            while [ $x -ne 0 ]; do 
                set +e
                cockroach start --advertise-host $myip --background --insecure --join=$leaderip
                x=$?
                set -e
                if [ $x -ne 0 ]; then 
                    sleep 5 
                else
                    connected='yes' 
                fi 
            done
	else
	    set -e
	    echo failed to join cluster, waiting for leader to come up
	    sleep 5
        fi
    done
else
    x=1
    while [ $x -ne 0 ]; do 
        set +e 
        cockroach start --insecure --advertise-host $myip --background 
        x=$? 
        echo $x
        set -e 
        if [ $x -ne 0 ]; then 
            sleep 5
        else
            connected='yes' 
        fi 
    done
fi
echo connected

