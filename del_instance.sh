#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please run as root or via sudo"
    exit
fi

echo 'Stoping Instance '$1
runuser -l $1 -c 'export PATH=/usr/z1090/bin;export LD_LIBRARY_PATH=/usr/z1090/bin;awsstop'
stoprc=$?
if [ $stoprc -gt 2 ]
then
	echo 'Awsstop Failed .. will kill process instead'
	awspid=$(ps -u $1 | grep awsstart | awk '{print $1}')
        echo 'Killing process '$awspid
        kill $awspid	
fi
sleep 6
echo 'Deleting subvolume /data/users/'$1'/zos'
btrfs subvolume delete /data/users/$1/zos
echo $?

inst_ip=$(ip link show mvtap_$1 | grep alias | awk '{print $2}')
echo 'Instance found using alias '$inst_ip
if [[ "$inst_ip" == *"9.114.209"* ]]; then
        dhclient -pf /var/run/dhclient_mvtap_$1.pid -p 3068 -r mvtap_$1
	echo $?
fi
if [[ "$inst_ip" == *"172.26.1"* ]]; then
        dhclient -pf /var/run/dhclient_mvtap_$1.pid -p 2068 -r mvtap_$1
	echo $?
fi
echo 'Deleting mvtap_'$1
ip link del 'mvtap'_$1 
echo $?
echo 'Deleting user '$1
userdel -r -f $1
echo $?
