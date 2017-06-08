This repository contains a template to deploy an autoscaling service. The scale-up is handled by heat and the scale down is handled by the etcd scripts.   
   
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
|metricsserver  |"None"    |The IP address of the metrics server

If metricsserver is None, the netdata security group is not required