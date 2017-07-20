This repository contains a template to deploy an autoscaling service. The scale-up is handled by heat and the scale down is handled by the etcd scripts.   

Before using, you should replace the configscript with your own script, see doc/writing_a_configscript.md for help   
To use this repo (credentials should be valid for the deploy location and should probably be a service account):
```
git clone git@gitlab.internal.sanger.ac.uk/bh9/autoscale-etcd.git
cd autoscale-etcd
openstack stack create -t template.yaml\ 
--parameter OS_USERNAME=my_OS_USERNAME\  
--parameter OS_TENANT_NAME=my_OS_TENANT_NAME\
--parameter OS_PASSWORD=my_OS_PASSWORD\
--parameter net_name="my_network"\
--parameter image="Ubuntu Xenial"\
--parameter sec_grps=["cloudforms_ssh_in","internal_etcd","netdata","my_service_sec_grp"]
--parameter insance_type="m1.small"\
--parameter key_name=my_key_name\
--parameter configscript="my_remote_script_name.sh"\
my_stack_name
```
internal_etcd should open ports 12379 and 12380 and netdata should open 19999. These can both be open to just the private network (assuming the metrics server is in the same private network).  
Other (optional) parameters:  
 
|name           |default   |description 
|---------------|----------|---------------------------------------
|OS_REGION      |regionOne |the nova region it should be deployed to (delta only has regionOne)
|capacity       |3         |The target capacity that the cluster should aim to be when load is low
|scaledownperiod|200       |The minimum time between scale down operations
|etcdclientport |12379     |The tcp port which etcd uses to handle client requests
|etcdpeerport   |12380     |The tcp port which etcd uses to communicate internally
|retries        |10        |The number of attemtps to join the cluster before failure
|lockattemptperiod |10     |The minimum time between a single host's lock acquire attempts
|min_cluster    |3         |minimum cluster size (the point at which heat will autoreplace failed nodes). Note that the scale down scripts will only scale down to capacity, not min_cluster
|max_cluster    |5         |The maximum size of the cluster
|scaleupcooldown|240       |The minimum time between scale up operations, note that ceilometer applies a minimum of 10 minutes due to it's gathering period
|etcdclientscheme |http    |The protocol used to serve client requests (Note: https uses auto-tls. Since VMs have low entropy, this step can take 5 minutes)
|etcdpeerscheme |http      |The protocol used for peer-to-peer communications (Note: https uses auto-tls. Since VMs have low entropy, this step can take 5 minutes)
|proxies        |0         |The number of proxies in front of the etcd cluster (use proxyconfig.sh to configure them to also act as e.g. a mongos)
|downmetric     |NETDATA_SYSTEM_CPU_IDLE |the netdata metric to use for scaling down (e.g. `NETDATA_SYSTEM_CPU_IDLE` or `NETDATA_SYSTEM_LIAD_LOAD1` or `NETDATA_SYSTEM_IO_IN, see doc/all_metrics for more options). Currently, this is only as it would be returned, however, I plan to add rate of change
|threshold      |10        |the scaledown threshold of the chosen metric (default is NETDATA_SYSTEM_CPU_IDLE)
|comparator     |'<'       |the comparator between the metric and the threshold (options are '>' '<' '==' '<=' '>=')
|upmetric       |cpu_util  |the heat metric to scale up for
|metrics_server |0         |whether or not a metrics server should be deployed, 1 or 0
|failtolerance  |20        |every lockattemptperiod seconds, an etcd communication is made. If this fails, the failmarker goes up by 5, but if it succeeds, the marker goes down by 1. If this marker exceeds failtolerance, the machine is removed

Supplied with this is a pair of packer templates. Using the images produced by these templates has dropped the maximum time the cluster is down a member from ~200s to ~70s however they are not compulsory. Note: to use other images, add the commands in the relevant template to the top of etcd/etcd_autoscale
