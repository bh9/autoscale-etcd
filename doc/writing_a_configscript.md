# Writing a configscript
The configscript is a bash script which should be replaced by a script which installs and configures your chosen service.  
Since the script is run on all nodes, in different scenarios it may be necessary to differentiate between hosts that need slightly different configuration or need starting slightly differently. 
The example has a few useful tricks for configuration of distributed services.  
For services which need 1 node to start it and the others to join, it easiest to have the etcd leader start and the followers join.  
This is how the example does it but it is worth noting that the leader may not have been elected yet so certain cases have to be handled (i.e. don't try to if the master hasn't started it yet)

