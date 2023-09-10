#!/bin/bash

$ftype=$1
# Initialize an empty array to store LUNs
luns=()

# Iterate through symbolic links in the directory
for link in /dev/disk/azure/scsi1/lun*; do
    # Use readlink to get the target of the symbolic link (e.g., ../../../sdc)
    target=$(readlink -f "$link")

    # Extract the LUN name (e.g., sdc)
    lun_name=$(basename "$target")

    # Add the LUN name to the array
    luns+=("$lun_name")
done

# Print the array elements (LUN names)
num_disks=${#luns[@]}


for ((i = 0; i < num_disks; i++)); do
    lun="${luns[i]}"
    echo "LUN $i: $lun"
    printf "o\nn\np\n1\n\n\nw\n" |fdisk /dev/$lun
    partprobe /dev/$lun
    mkfs.$1 /dev/${lun}1
    mkdir /data$((i + 1))
    sudo mount /dev/${lun}1 /data$((i + 1))
    diskuuid="$(blkid -s UUID -o value /dev/${lun}1)"
    echo "UUID=${diskuuid} /data$((i + 1)) $1 defaults,nofail 0 0" >> /etc/fstab
done
