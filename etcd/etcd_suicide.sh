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
curl http://$IP:12379/v2/members/$MEMBER_ID -XDELETE | echo couldn't remove myself from the cluster, it'll happen eventually #remove yourself from the cluster before you delete yourself so the cluster responds instantly
echo $ID
openstack server delete --os-region $AWS_DEFAULT_REGION --os-username $OS_USERNAME --os-password $OS_PASSWORD --os-tenant-name $OS_TENANT_NAME --os-auth-url $OS_AUTH_URL $ID #delete yourself

