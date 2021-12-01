#! /bin/bash

#   ILI Mid-semester Assignment 
#   Alexander Polok(xpolok03)
#   1.11.2019
#   version 1.0.0

#################################################################################################
if [ "$1" != "--cleanOnly" ] && [ "$1" != "-co" ]; then
echo "------------------------------------------------------------------------"
printf "+++++Script started+++++\n------------------------------------------------------------------------\n"
echo "+++++1) Creating 4 loop devices (200MB size each)+++++"
for p in {0..3}; do dd if=/dev/urandom of=disk$p bs=10MB count=20;losetup "loop$p" "disk$p"; echo "+++++1) Loop device $p created+++++"; done
echo "------------------------------------------------------------------------"

echo "+++++2) Creating software RAID1 on the first 2 loop devices and RAID0 on the other 2 loop devices.+++++"
yes | mdadm --create /dev/md1 --level=1 --raid-devices=2 /dev/loop0 /dev/loop1
echo "+++++2) RAID1 created+++++" 
yes | mdadm --create /dev/md0 --level=0 --raid-devices=2 /dev/loop2 /dev/loop3
printf "+++++2) RAID0 created+++++\n------------------------------------------------------------------------\n+++++3) Creating volume group on top of 2 RAID devices.+++++\n"
vgcreate FIT_vg /dev/md0 /dev/md1
printf "+++++3) Volume group FIT_vg created+++++\n------------------------------------------------------------------------\n+++++4) In the volume group FIT_vg creating 2 logical volumes of size 100MB each+++++\n------------------------------------------------------------------------\n"
for i in {1..2}; do lvcreate FIT_vg -n FIT_lv$i -L100M; echo "+++++4) Logical volume FIT_lv$i created+++++"; done
echo "------------------------------------------------------------------------"

printf "+++++5) Creating EXT4 filesystems on FIT_lv1 logical volume.+++++\n------------------------------------------------------------------------\n"
mkfs.ext4 /dev/FIT_vg/FIT_lv1
printf "+++++6) Creating XFS filesystems on FIT_lv2 logical volume.+++++\n------------------------------------------------------------------------\n"
mkfs.xfs /dev/FIT_vg/FIT_lv2
echo "+++++7) Mount FIT_lv1 to /mnt/test1 and FIT_lv2 to /mnt/test2 directories.+++++"
for i in {1..2}; do mkdir /mnt/test$i; echo "+++++7) Directory /mnt/test$i created+++++"; mount /dev/FIT_vg/FIT_lv$i /mnt/test$i; echo "+++++7) Logical volume FIT_lv$i mounted on /mnt/test$i+++++"; done
echo "------------------------------------------------------------------------"

echo "+++++8) Resizing filesystem on FIT_lv1 to claim all available space in the volume group.+++++"
echo "+++++8) Checking size of /dev/FIT_vg/FIT_lv1+++++"
df -h /dev/FIT_vg/FIT_lv1
lvextend -l +100%FREE /dev/FIT_vg/FIT_lv1
resize2fs /dev/FIT_vg/FIT_lv1
echo "+++++8) Verifying using df -h command+++++"
df -h /dev/FIT_vg/FIT_lv1
echo "------------------------------------------------------------------------"

echo "+++++9) Creating 300MB file /mnt/test1/big_file and feeding it with data from /dev/urandom device+++++"
dd if=/dev/urandom of=/mnt/test1/big_file bs=10M count=30
echo "+++++9) Creating checksum of /mnt/test1/big_file+++++"
sha512sum /mnt/test1/big_file
echo "------------------------------------------------------------------------"

printf "+++++10) Emulating faulty disk replacement+++++\n+++++10) Creating 5th loop device representing new disk (200MB).+++++\n"
dd if=/dev/urandom of=disk4 bs=10MB count=20
losetup loop4 disk4 
printf "+++++10) Loop device 4 created+++++\n+++++10) Replacing one of the RAID1 loop devices with the new loop device (setting status to failed and removing)+++++\n"
sync
mdadm --manage /dev/md1 --fail /dev/loop1
mdadm --manage /dev/md1 --remove /dev/loop1
echo "+++++10) Adding loop device 4 to raid+++++"
mdadm --manage /dev/md1 --add /dev/loop4
echo "+++++10) Verifying the successful recovery of RAID1+++++"
mdadm --detail /dev/md1

echo "+++++10) Sometimes sync doesn't start immediately, so sleeping for a while and checking once more+++++"
sleep 1
mdadm --detail /dev/md1
printf "+++++End of the script+++++\n------------------------------------------------------------------------\n"
fi

if [ "$1" == "--clean" ] || [ "$1" == "-c" ] || [ "$1" == "--cleanOnly" ] ||  [ "$1" == "-co" ]; then
    echo "+++++Cleaning up+++++"
    for i in {1..2}; do umount /mnt/test$i; yes | rm -r /mnt/test$i; done
    wipefs /dev/FIT_vg/FIT_lv1
    wipefs /dev/FIT_vg/FIT_lv2
    for i in {1..2}; do yes | lvremove /dev/FIT_vg/FIT_lv$i; done
    yes | vgremove FIT_vg
    mdadm --stop /dev/md0
    mdadm --stop /dev/md1
    losetup -D
    printf "+++++Cleaned+++++\n------------------------------------------------------------------------\n"
fi