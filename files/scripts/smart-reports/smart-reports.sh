#!/bin/bash
# creates one file per smart device and dumps out the 
# latest -a output
# expects to be run inside smart-reports folder

mkdir -p $(date +%F)

for i in {a..l}
do
  model=$(smartctl -a /dev/sd$i | grep "Device Model" | awk '{ print $NF }')
  serial=$(smartctl -a /dev/sd$i | grep "Serial Number" | awk '{ print $NF }')

  #echo $(date +%F)_${model}_${serial}.txt

  smartctl -a /dev/sd$i > $(date +%F)/$(date +%F)_${model}_${serial}.txt
done