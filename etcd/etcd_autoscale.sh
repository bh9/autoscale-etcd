#!/bin/bash
set -ex
x=y=1
if [ -f /etc/centos-release ]; then
  PLATFORM=centos
else
  PLATFORM=$(lsb_release --release | sed -e 's/.*14.*/trusty/i' -e 's/.*16.*/xenial/i')
fi
case ${PLATFORM} in
  centos)
#    while [ $((x)) -gt 0 ]; do
#      set +e
#      yum -y update
#      x=$?
#      set -e
#      echo updating
#    done
#    #apt-get update
#    while [ $((y)) -gt 0 ]; do
#      set +e
#      yum -y install epel-release
#      yum -y install libcurl-devel curl etcd jq python2-pip python-devel zlib-devel libuuid-devel libmnl-devel gcc make git autoconf autogen automake pkg-config urllib3 chardet
#      pip install --upgrade python-etcd python-openstackclient python-heatclient pycurl urllib3 chardet
#      y=$?
#      set -e
#    done
  ;;
  xenial)
#    DEBIAN_FRONTEND=noninteractive
 #   x=y=1
  #  while [ $((x)) -gt 0 ]; do
   #   set +e
    #  apt-get update
     # x=$?
      #set -e
#      echo updating
 #   done
    #apt-get update
  #  while [ $((y)) -gt 0 ]; do
   #   set +e
    #  apt-get install -y curl etcd jq python-etcd python-openstackclient python-pip python-psutil python-pycurl zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config
     # pip install --upgrade python-openstackclient python-heatclient
      #y=$?
#      set -e
 #   done
  ;;
esac
#curl -Ls https://github.com/coreos/etcd/releases/download/v3.1.8/etcd-v3.1.8-linux-amd64.tar.gz > etcd.tar.gz
#tar xvf etcd.tar.gz
#systemctl stop etcd
#mv -f etcd-v3.1.8-linux-amd64/etcd /usr/bin/etcd
#if [ -d /etc/sysconfig/ ]; then
#    echo /etc/sysconfig exists, good
#else
#    mkdir /etc/sysconfig
#fi
scriptname=$thisisascriptname
metrics_server=$thisisametricserver
timeout=$thisisatimeout
minimum_machines=$thisisacapacity
ETCD_CLIENT_PORT=$thisisaclientport
ETCD_SERVER_PORT=$thisisapeerport
RETRY_TIMES=$thisisaretrycount
ETCD_CLIENT_SCHEME=$thisisaclientscheme
ETCD_PEER_SCHEME=$thisisapeerscheme
echo $minimum_machines > /etc/sysconfig/etcd-size
export AWS_DEFAULT_REGION=$thisisaregion
export OS_USERNAME=$thisisausername #set some OS variables
export OS_PASSWORD=$thisisapassword
export OS_TENANT_NAME=$thisisatenantname
export no_proxy=,172.27.66.32
export OS_AUTH_URL=$thisisaurl
#export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq --raw-output .region)
if [[ ! $AWS_DEFAULT_REGION ]]; then
    echo "$pkg: failed to get region"
    exit 1
fi
if [ $metrics_server != "None" ]; then
    METRICS_ID=$thisisaninstanceid
    #apt-get install -y zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl
#    git clone https://github.com/firehol/netdata.git --depth=1
#    cd netdata
    # run script with root privileges to build, install, start netdata
#    ./netdata-installer.sh
    cat > /etc/netdata/stream.conf <<EOF
[stream]
    # Enable this on slaves, to have them send metrics.
    enabled = yes

    # Where is the receiving netdata?
    # A space separated list of:
    #
    #      [PROTOCOL:]HOST[%INTERFACE][:PORT]
    #
    # If many are given, the first available will get the metrics.
    #
    # PROTOCOL  = tcp or udp (only tcp is supported by masters)
    # HOST      = an IPv4, IPv6 IP, or a hostname.
    #             IPv6 IPs should be given with brackets [ip:address]
    # INTERFACE = the network interface to use
    # PORT      = the port number or service name (/etc/services)
    #
    # This communication is not HTTP (cannot be proxied by web proxies).
    destination = $metrics_server:19999

    # The API_KEY to use (as the sender)
    api key = $METRICS_ID

    # The timeout to connect and send metrics
    timeout seconds = 60

    # If the destination line above does not specify a port, use this
    default port = 19999

    # The buffer to use for sending metrics.
    # 1MB is good for 10-20 seconds of data, so increase this
    # if you expect latencies.
    buffer size bytes = 1048576

    # If the connection fails, or it disconnects,
    # retry after that many seconds.
    reconnect delay seconds = 5

    # Attempt to sync the clock the of the master with the clock of the
    # slave for that many iterations, when starting.
    initial clock resync iterations = 60
EOF
    systemctl restart netdata
fi
x=1
while [ $((x)) -gt 0 ]; do
  set +e
  mv /home/etcd/etcd2.service /etc/systemd/system/etcd2.service
  x=$?
  set -e
  echo moving etcd2.service
  if [ $((x)) -gt 0 ]; then
    sleep 5
  fi
done
x=1
while [ $((x)) -gt 0 ]; do
  set +e
  mv /home/etcd/cleanup.sh /var/lib/etcd/cleanup.sh
  x=$?
  set -e
  echo moving cleanup.sh
  if [ $((x)) -gt 0 ]; then
    sleep 5
  fi
done
chmod 744 /var/lib/etcd/cleanup.sh
systemctl daemon-reload	#read the new service files
pkg="etcd-aws-cluster"
version="0.5"
etcd_peers_file_path="/etc/sysconfig/etcd-peers"

# Allow default client/server ports to be changed if necessary
client_port=${ETCD_CLIENT_PORT:-12379}
server_port=${ETCD_SERVER_PORT:-12380}

# ETCD API https://coreos.com/etcd/docs/2.0.11/other_apis.html
add_ok=201
already_added=409
delete_ok=204
delete_gone=410

# Retry N times before giving up
retry_times=${RETRY_TIMES:-10}
# Add a sleep time to allow etcd client requets to finish
wait_time=3

#if the script has already run just exit
if [ -f "$etcd_peers_file_path" ]; then
    echo "$pkg: etcd-peers file $etcd_peers_file_path already created, exiting"
    exit 0
fi

ec2_instance_id=$(curl -s http://169.254.169.254/2009-04-04/meta-data/instance-id) #get the id and ip from the meta-data server
if [[ ! $ec2_instance_id ]]; then
    echo "$pkg: failed to get instance id from instance metadata"
    exit 2
fi

ec2_instance_ip=$(curl -s http://169.254.169.254/2009-04-04/meta-data/local-ipv4)
if [[ ! $ec2_instance_ip ]]; then
    echo "$pkg: failed to get instance IP address"
    exit 3
fi
echo $ec2_instance_ip $(hostname) >> /etc/hosts
# If we're in proxy mode we don't have to look this up and expect an env var
if [[ ! $PROXY_ASG ]]; then
    etcd_proxy=off
#    asg_name=$(aws autoscaling describe-auto-scaling-groups | jq --raw-output ".[] | map(select(.Instances[].InstanceId | contains(\"$ec2_instance_id\"))) | .[].AutoScalingGroupName")
     asg_name=$(hostname | gawk '/-/ {match ($0,/([0-9]|[a-z]|[A-Z])+-/);print substr($0,RSTART,RLENGTH-1)}') #get the autoscale group's name (the machine's hostname up to the first '-')
    if [[ ! "$asg_name" ]]; then
        echo "$pkg: failed to get the auto scaling group name"
        exit 4
    fi
else
    etcd_proxy=on
    if [[ -n $ASG_BY_TAG ]]; then
        #asg_name=$(aws autoscaling describe-auto-scaling-groups | jq --raw-output ".[] | map(select(.Tags[].Value == \"$PROXY_ASG\")) | .[].AutoScalingGroupName")
         asg_name=$(hostname | gawk '/-/ {match ($0,/([0-9]|[a-z]|[A-Z])+-/);print substr($0,RSTART,RLENGTH-1)}') #get the autoscale group's name (the machine's hostname up to the first '-')
    else
        asg_name=$PROXY_ASG
    fi
fi

etcd_client_scheme=${ETCD_CLIENT_SCHEME:-http}
echo "client_client_scheme=$etcd_client_scheme"

etcd_peer_scheme=${ETCD_PEER_SCHEME:-http}
echo "peer_peer_scheme=$etcd_peer_scheme"

etcd_peers=$(openstack server list -c Networks -c Name | gawk "/$asg_name/"' {match($0,/((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/); ip = substr($0,RSTART,RLENGTH); print ip}') #find all machines which match the group's name
for i in $etcd_peers; do
    etcd_peer_urls="$etcd_peer_urls $etcd_client_scheme://$i:$client_port" 
done
#etcd_peer_urls=$(aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "$asg_name" | jq '.AutoScalingGroups[0].Instances[] | select(.LifecycleState  == "InService") | .InstanceId' | xargs) | jq -r ".Reservations[].Instances | map(\"$etcd_client_scheme://\" + .NetworkInterfaces[].PrivateIpAddress + \":$client_port\")[]")
if [[ ! $etcd_peer_urls ]]; then
    echo "$pkg: unable to find members of auto scaling group"
    exit 5
fi

echo "etcd_peer_urls=$etcd_peer_urls"

etcd_existing_peer_urls=
etcd_existing_peer_names=
etcd_good_member_urls=
etcd_last_good_member_url=

for url in $etcd_peer_urls; do
    case "$url" in
        # If we're in proxy mode this is an error, but unlikely to happen?
        *$ec2_instance_ip*) continue;;
    esac

    etcd_members="$(curl $ETCD_CURLOPTS -m 10 -f -s $url/v2/members)" || true
    echo "etcd_members=$etcd_members"
    if [ -n "$etcd_members" ]; then
        etcd_last_good_member_url="$url"
        etcd_good_member_urls="$etcd_good_member_urls $etcd_last_good_member_url"
                echo "etcd_members=$etcd_members"
        etcd_existing_peer_urls="$etcd_existing_peer_urls $(echo "$etcd_members" | jq --raw-output .[][].peerURLs[0])"
                etcd_existing_peer_names="$etcd_existing_peer_names $(echo "$etcd_members" | jq --raw-output .[][].name)"
        #break
    fi
done

echo "etcd_last_good_member_url=$etcd_last_good_member_url"
echo "etcd_good_member_urls=$etcd_good_member_urls"
echo "etcd_existing_peer_urls=$etcd_existing_peer_urls"
echo "etcd_existing_peer_names=$etcd_existing_peer_names"

# if I am not listed as a member of the cluster assume that this is a existing cluster
# this will also be the case for a proxy situation
if [[ $etcd_existing_peer_urls && $etcd_existing_peer_names != *"$ec2_instance_ip"* ]]; then
    echo "joining existing cluster"

    # eject bad members from cluster - Note: currently removes all but most recent, needs work
#    peer_regexp=$(echo "$etcd_peer_urls" | sed 's/^.*https\{0,1\}:\/\/\([0-9.]*\):[0-9]*.*$/contains(\\"\/\/\1:\\")/' | xargs | sed 's/  */ or /g')
#    if [[ ! $peer_regexp ]]; then
#        echo "$pkg: failed to create peer regular expression"
#        exit 6
#    fi

 #   echo "peer_regexp=$peer_regexp"
 #   bad_peer=$(echo "$etcd_members" | jq --raw-output ".[] | map(select(.peerURLs[] | $peer_regexp | not )) | .[].id")
 #   echo "bad_peer=$bad_peer"

#    if [[ $bad_peer ]]; then
#        for bp in $bad_peer; do
#            status=0
#            retry=1
#            until [[ $status = $delete_ok || $status =  $delete_gone || $retry = $retry_times ]]; do
#                status=$(curl $ETCD_CURLOPTS -f -s -w %{http_code} "$etcd_good_member_url/v2/members/$bp" -XDELETE)
#                echo "$pkg: removing bad peer $bp, retry $((retry++)), return code $status."
#                sleep $wait_time
#            done
#            if [[ $status != $delete_ok && $status != $delete_gone ]]; then
#                echo "$pkg: ERROR: failed to remove bad peer: $bad_peer, return code $status."
#                exit 7
#            else
#                echo "$pkg: removed bad peer: $bad_peer, return code $status."
#            fi
#        done
#    fi

    # If we're not a proxy we add ourselves as a member to the cluster
    if [[ ! $PROXY_ASG ]]; then
        peer_url="$etcd_peer_scheme://$ec2_instance_ip:$server_port"
        curl -s $ETCD_CURLOPTS "$etcd_last_good_member_url/v2/keys/bh9testlock" -XPUT -d value=lock
        etcd_initial_cluster=$(curl $ETCD_CURLOPTS -s -f "$etcd_last_good_member_url/v2/members" | jq --raw-output '.[] | map(.name + "=" + .peerURLs[0]) | .[]' | xargs | sed 's/  */,/g')$(echo ",$ec2_instance_ip=$peer_url")
        echo "etcd_initial_cluster=$etcd_initial_cluster"
        if [[ ! $etcd_initial_cluster ]]; then
            echo "$pkg: docker command to get etcd peers failed"
            exit 8
        fi

        # join an existing cluster
        status=0
        retry=1
        until [[ $status = $add_ok || $status = $already_added || $retry = $retry_times ]]; do
            status=$(curl $ETCD_CURLOPTS -f -s -w %{http_code} -o /dev/null -XPOST "$etcd_last_good_member_url/v2/members" -H "Content-Type: application/json" -d "{\"peerURLs\": [\"$peer_url\"], \"name\": \"$ec2_instance_ip\"}")
            echo "$pkg: adding instance ID $ec2_instance_id with peer URL $peer_url, retry $((retry++)), return code $status."
            joined=
            all_in='success'
            cluster_size=$(echo $etcd_initial_cluster | sed 's/,/ /g' | wc -w)  
            while [ -z $joined ]; do
                for url in $etcd_peer_urls; do
                    url_cluster_size=$(curl $ETCD_CURLOPTS -s -f "$url/v2/members" | jq --raw-output '.[] | map(.name) | .[]' | wc -l)
                    if [ $url_cluster_size -ne $cluster_size]; then
			all_in='fail'
                    fi
                done
                if [ $all_in != 'success'];then 
                    sleep $wait_time
                else
                    joined=true
                fi
            done
        done
        if [[ $status != $add_ok && $status != $already_added ]]; then
            echo "$pkg: unable to add $peer_url to the cluster: return code $status."
            exit 9
        else
            echo "$pkg: added $peer_url to existing cluster, return code $status"
        fi
    # If we are a proxy we just want the list for the actual cluster
    else
        etcd_initial_cluster=$(curl $ETCD_CURLOPTS -s -f "$etcd_last_good_member_url/v2/members" | jq --raw-output '.[] | map(.name + "=" + .peerURLs[0]) | .[]' | xargs | sed 's/  */,/g')
        echo "etcd_initial_cluster=$etcd_initial_cluster"
        if [[ ! $etcd_initial_cluster ]]; then
            echo "$pkg: docker command to get etcd peers failed"
            exit 8
        fi
    fi
#write the config file for an existing etcd cluster
    cat > "$etcd_peers_file_path" <<EOF
{
    initial-cluster-state: existing,
    name: $ec2_instance_ip,
    data-dir: /var/lib/etcd/default,
    initial-cluster: "$etcd_initial_cluster",
    initial-advertise-peer-urls: "$etcd_peer_scheme://$ec2_instance_ip:$server_port",
    advertise-client-urls: "$etcd_client_scheme://$ec2_instance_ip:$client_port",
    proxy: "$etcd_proxy",
    listen-peer-urls: "$etcd_peer_scheme://$ec2_instance_ip:$server_port",
    listen-client-urls: "$etcd_client_scheme://$ec2_instance_ip:$client_port",
    client-transport-security: {
EOF
    if [ $ETCD_CLIENT_SCHEME = "https" ]; then
        echo "        auto-tls=true" >> "$etcd_peers_file_path"
    fi
    echo "    }," >> "$etcd_peers_file_path"
    echo "    peer-transport-security: {" >> "$etcd_peers_file_path"
    if [ $ETCD_PEER_SCHEME = "https" ]; then
        echo auto-tls=true >> "$etcd_peers_file_path"
    fi
    echo "    }" >> "$etcd_peers_file_path"
    echo "}" >> "$etcd_peers_file_path"
    rm -rf /var/lib/etcd/default/
#    systemctl stop etcd #restart etcd now it is configured correctly so the config takes hold
    systemctl start etcd2
    curl -s $ETCD_CURLOPTS "$etcd_last_good_member_url/v2/keys/bh9testlock" -XDELETE
# otherwise I was already listed as a member so assume that this is a new cluster
else
    # create a new cluster
    echo "creating new cluster"

    for i in $etcd_peers; do
        etcd_initial_cluster="$etcd_initial_cluster,$i=$etcd_peer_scheme://$i:$server_port"
    done
    #etcd_initial_cluster=$(aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "$asg_name" | jq .AutoScalingGroups[0].Instances[].InstanceId | xargs) | jq -r ".Reservations[].Instances | map(.InstanceId + \"=$etcd_peer_scheme://\" + .NetworkInterfaces[].PrivateIpAddress + \":$server_port\")[]" | xargs | sed 's/  */,/g')
    echo "etcd_initial_cluster=$etcd_initial_cluster"
    if [[ ! $etcd_initial_cluster ]]; then
        echo "$pkg: unable to get peers from auto scaling group"
        exit 10
    fi
#write the config file for a new etcd cluster
    cat > "$etcd_peers_file_path" <<EOF
{
    initial-cluster-state: new,
    name: $ec2_instance_ip,
    data-dir: /var/lib/etcd/default,
    initial-advertise-peer-urls: "$etcd_peer_scheme://$ec2_instance_ip:$server_port",
    advertise-client-urls: "$etcd_client_scheme://$ec2_instance_ip:$client_port",
    initial-cluster: "$etcd_initial_cluster",
    listen-peer-urls: "$etcd_peer_scheme://$ec2_instance_ip:$server_port",
    listen-client-urls: "$etcd_client_scheme://$ec2_instance_ip:$client_port",
    client-transport-security: {
EOF
    if [ $ETCD_CLIENT_SCHEME = "https" ]; then
        echo auto-tls=true >> "$etcd_peers_file_path"
    fi
    echo "    }," >> "$etcd_peers_file_path"
    echo "    peer-transport-security: {" >> "$etcd_peers_file_path"
    if [ $ETCD_PEER_SCHEME = "https" ]; then
        echo auto-tls=true >> "$etcd_peers_file_path"
    fi
    echo "    }" >> "$etcd_peers_file_path"
    echo "}" >> "$etcd_peers_file_path"
    rm -rf /var/lib/etcd/default/
 #   systemctl stop etcd #restart etcd now it is configured correctly so the config takes hold
    systemctl stop etcd
    systemctl stop etcd2
    systemctl start etcd2
fi
x=1
while [ $((x)) -gt 0 ]; do
  set +e
  mv /home/etcd/locking.py /var/lib/etcd/locking.py
  x=$?
  set -e
  echo moving locking.py
  if [ $((x)) -gt 0 ]; then
    sleep 5
  fi
done
IP=$(curl -s http://169.254.169.254/2009-04-04/meta-data/local-ipv4)
MEMBER_ID=$(curl -s $etcd_client_scheme://$IP:$ETCD_CLIENT_PORT/v2/members | jq ".members[] | select(.name == \"$IP\") | .id" | sed "s/\"//g")
ID=$(openstack server list | awk "/$IP/"' {print $2}')
cat > /var/lib/etcd/suicide.sh <<EOF
#!/bin/bash
set -e
OS_REGION=$AWS_DEFAULT_REGION
OS_USERNAME=$OS_USERNAME
OS_PASSWORD=$OS_PASSWORD
OS_TENANT_NAME=$OS_TENANT_NAME
no_proxy=$no_proxy
OS_AUTH_URL=$OS_AUTH_URL
echo $IP
echo $MEMBER_ID
curl -s $etcd_client_scheme://$IP:$ETCD_CLIENT_PORT/v2/members/$MEMBER_ID -XDELETE | echo couldn't remove myself from the cluster, it'll happen eventually #remove yourself from the cluster before you delete yourself so the cluster responds instantly
echo $ID
/var/lib/etcd/cleanup.sh
sleep 5
openstack server delete --os-region $AWS_DEFAULT_REGION --os-username $OS_USERNAME --os-password $OS_PASSWORD --os-tenant-name $OS_TENANT_NAME --os-auth-url $OS_AUTH_URL $ID #delete yourself
EOF
openstack stack show -c outputs -f json $asg_name
SCALE_URL=$(openstack stack show -c outputs -f json $asg_name | jq '.outputs | select(.[].output_key=="scale_up_url") | .[0].output_value')
cat > /var/lib/etcd/recover.sh <<-EOF 
#!/bin/bash 
set -e 
export OS_REGION=$AWS_DEFAULT_REGION 
export OS_USERNAME=$OS_USERNAME 
export OS_PASSWORD=$OS_PASSWORD 
export OS_TENANT_NAME=$OS_TENANT_NAME 
export no_proxy=$no_proxy 
export OS_AUTH_URL=$OS_AUTH_URL 
curl -XPOST $SCALE_URL 
EOF
while [ $((x)) -gt 0 ]; do
  set +e
  mv /home/etcd/recover.sh /var/lib/etcd/recover.sh
  x=$?
  set -e
  echo moving $scriptname
  if [ $((x)) -gt 0 ]; then
    sleep 5
  fi
done
cat > /etc/systemd/system/suicide.service <<-EOF
[Unit]
Description=the killer cleanup service
After=etcd2.service
Wants=network-online.target

[Service]
Type=idle
User=root
ExecStart=/usr/bin/python /var/lib/etcd/locking.py

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/healthcheck.service <<-EOF
[Unit]
Description=the etcd recovery service
After=etcd2.service
Wants=network-online.target

[Service]
Type=idle
User=root
ExecStart=/bin/bash /var/lib/etcd/healthcheck.sh

[Install]
WantedBy=multi-user.target
EOF
x=1
while [ $((x)) -gt 0 ]; do
  set +e
  mv /home/etcd/configscript.sh /var/lib/etcd/$scriptname
  x=$?
  set -e
  echo moving $scriptname
  if [ $((x)) -gt 0 ]; then
    sleep 5
  fi
done
x=1
while [ $((x)) -gt 0 ]; do
  set +e
  mv /home/etcd/healthcheck.sh /var/lib/etcd/healthcheck.sh
  x=$?
  set -e
  echo moving healthcheck.sh
  if [ $((x)) -gt 0 ]; then
    sleep 5
  fi
done
chmod 744 /var/lib/etcd/healthcheck.sh
chmod 744 /var/lib/etcd/recover.sh
systemctl start healthcheck.service
chmod 744 /var/lib/etcd/$scriptname
/var/lib/etcd/$scriptname
chmod 744 /var/lib/etcd/suicide.sh
systemctl disable etcd
#systemctl enable etcd2 #set both etcd and the suicide script to start on boot
systemctl start suicide.service
#systemctl enable suicide.service #start the suicide script
exit 0

