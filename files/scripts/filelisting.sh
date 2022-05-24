#!/bin/bash

mkdir -p /mnt/tank/backups/filelistings/morpheus/$(date +%F)

for i in {1..7}
do
   find /mnt/disk$i -type f > /mnt/tank/backups/filelistings/morpheus/$(date +%F)/disk$i.txt
done