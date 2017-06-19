#!/bin/bash
set -e
apt-get update
apt-get install -y zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl
git clone https://github.com/firehol/netdata.git --depth=1
cd netdata
# run script with root privileges to build, install, start netdata
./netdata-installer.sh
cat > /etc/netdata/stream.conf <<EOF
[$thisisaninstanceid]
    # Default settings for the API key

    # You can disable the API key, by setting this to: no
    # The default (for unknown API keys) is: no
    enabled = yes

    # The default history in entries, for all hosts using this API key.
    # You can also set it per host below.
    # If you don't set it here, the history size of the central netdata
    # will be used.
    default history = 3600

    # The default memory mode to be used for all hosts using this API key.
    # You can also set it per host below.
    # If you don't set it here, the memory mode of netdata.conf will be used.
    # Valid modes:
    #    save    save on exit, load on start
    #    map     like swap (continuously syncing to disks)
    #    ram     keep it in RAM, don't touch the disk
    #    none    no database at all (use this on headless proxies)
    default memory mode = ram

    # Shall we enable health monitoring for the hosts using this API key?
    # 3 possible values:
    #    yes     enable alarms
    #    no      do not enable alarms
    #    auto    enable alarms, only when the sending netdata is connected
    # You can also set it per host, below.
    # The default is the same as to netdata.conf
    health enabled by default = auto

    # postpone alarms for a short period after the sender is connected
    default postpone alarms on connect seconds = 60

    # need to route metrics differently? set these.
    # the defaults are the ones at the [stream] section
    #default proxy enabled = yes | no
    #default proxy destination = IP:PORT IP:PORT ...
    #default proxy api key = API_KEY
EOF
systemctl restart netdata

