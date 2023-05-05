# ZVDT

#Notes:

##DHCP:
Linux package DNSMASQ is used to "simulate" DHCP for z/OS. When a MACVTAP adapter is created in linux, the dhclient command is executed to request and assign an IP address to the adapter. After the IP address is assigned it is then actually removed because we are not using the IP address for linux but rather are using the IP address in z/OS. The pdsUtil ZVDT command is used to update the z/OS disk volume file containing TCPPARMS to update the IP address that z/OS will use.

##BTRFS (for Ubuntu):
After partitioning linux disks using fdasd, the disks can be used are used to create a BTRFS filesystem, for example:
mkfs -t btrfs /dev/dasda1 /dev/dasdb1 /dev/dasdc1   (this is similar to using LVM to create one large filesystem across multiple disks)

The filesystem is then mounted at /data (or use any directory you want)
mount -t btrfs /dev/dasda1 /data  (can use any of the /dev/dasdx1 devices for mount command)

Multiple subvolumes can be created under Filesystem.
btrfs subvolume create /data/image1
btrfs subvolume create /data/image2

Snapshot at Subvolume level
btrfs subvolume snapshot /data/image1 /data/snapshot/image1
btrfs subvolume snapshot /data/image2 /data/snapshot/image2


##Stratis (for RedHat) is similar to Ubuntu:
###Storage Pools created from block devices, for example:
stratis pool create data_pool /dev/dasda1 /dev/dasdb1 /dev/dasdc1

###Filesystems created from Storage Pools
stratis filesystem create data_pool data_fs
mount /dev/stratis/data_pool/data_fs /data

###Snapshot at Filesystem level
stratis filesystem snapshot data_pool data_fs target

On Z, devices MUST be partitioned first (ie. Using fdasd)

Limitation of at least 1TB sized devices, smaller devices "seem" to work but you may exhaust space in the filesystem before you realize it !!
