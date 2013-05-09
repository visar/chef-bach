#!/bin/bash

set -e

KEYFILE=bootstrap_chef.id_rsa

if [ ! -f $KEYFILE ]; then
  ssh-keygen -N "" -f $KEYFILE
fi

rsync -avP -e "ssh -i $KEYFILE" --exclude vbox --exclude $KEYFILE . ubuntu@$1:chef-bcpc

ssh -i $KEYFILE ubuntu@$1 "cd chef-bcpc && ./setup_ssh_keys.sh $KEYFILE.pub"
host=`ssh -i $KEYFILE ubuntu@$1 "hostname -f"`
ssh -t -i $KEYFILE ubuntu@$1 "cd chef-bcpc && sudo ./setup_chef_server.sh"
ssh -t -i $KEYFILE ubuntu@$1 "cd chef-bcpc && ./setup_chef_cookbooks.sh"
ssh -t -i $KEYFILE ubuntu@$1 "cd chef-bcpc && knife environment from file environments/*.json && knife role from file roles/*.json && knife cookbook upload -a -o cookbooks"

ssh -t -i $KEYFILE ubuntu@$1 "cd chef-bcpc && knife bootstrap -E Test-Laptop $1 -x ubuntu --sudo"
admin_val=`ssh -i $KEYFILE ubuntu@$1 'cd chef-bcpc && knife client show $(hostname -f) | grep ^admin: | sed "s/admin:[^a-z]*//"'`
if [ "$admin_val" != "true" ]; then
  # Make this client an admin user before proceeding.
  ssh -t -i $KEYFILE ubuntu@$1 'cd chef-bcpc && echo -e "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed knife client edit `hostname -f`'
fi
ssh -t -i $KEYFILE ubuntu@$1 "cd chef-bcpc && knife node run_list add \`hostname -f\` 'role[BCPC-Bootstrap]'"
ssh -t -i $KEYFILE root@$1 "chef-client"

subnet=10.0.100
node=11
for i in bcpc-vm1 bcpc-vm2 bcpc-vm3; do
  MAC=`VBoxManage showvminfo --machinereadable $i | grep macaddress1 | cut -d \" -f 2 | sed 's/.\{2\}/&:/g;s/:$//'`
  echo "Registering $i with $MAC for ${subnet}.${node}"
  ssh -t -i $KEYFILE root@$1 "cobbler system remove --name=$i && cobbler system add --name=$i --hostname=$i --profile=bcpc_host --ip-address=${subnet}.${node} --mac=${MAC}"
  let node=node+1
done
ssh -t -i $KEYFILE root@$1 "cobbler sync"
