#!/bin/bash

#Load configuration options from filename passed in on command line
. $1

################## SAMPLE config file contents ##################
##!/bin/sh
#
#host=`hostname`
##Get date and time of commencement of backup
#datetime=`date +%Y-%m-%d-%H:%M`
#backupmp="/mnt/backup"
#backupdir="virt"
#backupdest="$backupmp/$backupdir"
##Disk Devices to be backed up of the form:
##declare -A backupsrcdev=([/path/to/device/file]=/path/to/dump/filename ...)
#declare -A backupsrcdev=([/dev/disk/by-id/wwn-0x5002538da02cd53c]=bootfs.dump)
##LVM devices to be snapshotted before backup
#declare -A backuplvmsrc=([/dev/vg-os/root]=rootfs.dump)
##Destination device to backup to
#backupdstdev="/dev/disk/by-label/backup"
#

#################################################################

#Backup script commences here

#Make sure destination device is mounted
mount|grep -q "$backupmp" || mount "$backupdstdev" "$backupmp"

#Check if mount succeeded
if [ $? -ne 0 ]
then
  echo "Mounting backup device failed!"
  exit 1
fi

export PATH=/sbin:/usr/sbin:$PATH

cd /

echo "============== Commencing backup on $host - $datetime =============="

#Backup key config files
echo "Backup filesystem config: /etc/fstab /etc/lvm /etc/modprobe.conf"
if [ ! -e "$backupdest/config" ]
then
  echo "Making directory $backupdest/config"
  mkdir -p "$backupdest/config"
fi
echo "Copying /etc/fstab"
cp -f -u /etc/fstab "$backupdest/config/"
/sbin/vgcfgbackup
echo "Copying /etc/lvm"
cp -f -u -r /etc/lvm "$backupdest/config/"
echo "Copying output of vgdisplay -v"
/sbin/vgdisplay -v >"$backupdest/config/vgdisplay.txt"
echo "Copying output of fdisk -l for boot device - $backupsrcdev"
/sbin/fdisk -l "$backupsrcdev" >"$backupdest/config/fdisk.txt"
echo "Copying boot partition layout with sfdisk for boot device - $backupsrcdev"
/sbin/sfdisk -d "$backupsrcdev" >"$backupdest/config/sfdisk.txt"
echo "Copying /etc/modprobe.d directory"
cp -f -r -u /etc/modprobe.d "$backupdest/config/"
echo "Copying /dev/disk symlinks"
cp -f -r -u -P /dev/disk "$backupdest/config/"

#Backup disk devices
for adev in ${!backupsrcdev[*]}
do
  echo "Backup $adev -> ${backupsrcdev[$adev]}"
  /sbin/dump -0f "$backupdest/bootfs.dump" -b 64 $adev
  echo
done

#Backup lvm devices
for adev in ${!backuplvmsrc[*]}
do
  #Snapshot lv for virt
  echo "Creating snapshot of $adev"
  #todo - GOT UP TO HERE WITH THE SCRIPT
  /sbin/lvcreate -s -n root_bak -L 2G /dev/vg-os/root
done


#Dump the virt root filesystem from the snapshot lv 
echo "Dumping /"
/sbin/dump -0f "$backupdest/rootfs.dump" -Q "$backupdest/rootfs.index" -b 64 /dev/vg-os/root_bak

#Remove snapshots 
echo "Removing snapshots"
/sbin/lvremove -f /dev/vg-os/root_bak
echo "Snapshots removed"

#Rsync backup files to nas01
#rsync -rltv --password-file=/usr/local/adm/nas-rsync-password.txt --backup --delete /mnt/barneybak2/barney-backups/ clarkd@nas01::barney/barney-backups/

echo "Backup complete"
date
