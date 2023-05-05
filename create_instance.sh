#!/bin/bash

# $1 is user
# $2 is IP type (pub or priv)
# $3 is Image 

memoryav=$( free -b | grep Mem: | awk '{print $4}') 
buffcach=$( free -b | grep Mem: | awk '{print $7}')
memavail=$(($memoryav + $buffcach))
echo $memavail $memoryav $buffcach
#if [ "$memavail" -lt '20737418240' ]; then
if [ "$memavail" -lt '18737418240' ]; then
	echo "Not enough free Memory" 
	exit
fi

if (( $EUID != 0 )); then
    echo "Please run as root or with sudo"
    exit
fi

if [ -z "$1" ]; then
	echo "Choose Instance Name (Linux user id):"
	read inst_name
else
	inst_name=$1
fi

if [ -z "$2" ]; then
	echo "Choose IP type (1 or 2):"
	echo "1 - Public IP"
	echo "2 - Private IP"
	read iptypeno
	if [ "$iptypeno" == '1' ]; then
		iptype='pub'
	elif [ "$iptypeno" == '2' ]; then
		iptype='priv'
	else
		echo 'Invalid IP Type .. choose 1 or 2'
		exit
	fi
else
	iptype=$2
fi

if [ -z "$3" ]; then
        echo "Choose Image (enter number):"
        echo "  1 - Stock Dev/Test Image"
        echo "  2 - ADCD 2.5 - RSU2209"
        echo "  3 - DEMO 2.5"

        read imageno
        if [ "$imageno" == '1' ]; then
                image='stock'
        elif [ "$imageno" == '3' ]; then
                image='demo25'
        elif [ "$imageno" == '2' ]; then
                image='adcd_rsu2209_drop1'
        else
                echo 'Invalid Image, specify Image number'
                exit
        fi
else
        image=$3
fi

if [ ! -d /data/$image ]; then
	echo 'Image does not exist.. terminating.. who wrote this script anyway'
	exit
fi

echo 'Proceeding to provision Image: '$image

export PATH=$PATH:/usr/z1090/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/z1090/bin

if [ $(grep $inst_name /etc/passwd) ]; then
	echo $inst_name "User already exists, exiting"
	exit
fi	

if [ -d /data/users/$inst_name ]; then
	echo $inst_name "User directory already exists, exiting"
	exit
fi
if [ -f /data/users/$inst_name ]; then
        echo $inst_name "Duplicate name in /data/users directory, exiting"
        exit
fi

if [ ! -z "$(ip link | grep 'mvtap_'$inst_name)" ]; then
        echo "MACVTAP adapter with requested name already exists, exiting"
        exit
fi


if [ $iptype == "pub" ]
then
	vtapdev='enc7243'
	echo 'Adding MACVTAP 'mvtap_$inst_name
        ip link add link $vtapdev mvtap_$inst_name type macvtap mode bridge
	if [ $? -ne 0 ]; then
		echo 'Failed to add MACVTAP device, exiting'
	        exit
	fi	
	echo 'About to obtain IP address'
	inst_ipaddr=$(dhclient -pf /var/run/dhclient_mvtap_$inst_name.pid -p 3068 -4 -v mvtap_$inst_name 2>&1 | grep bound | awk '{print $3}')
	echo $inst_ipaddr' has been assigned'
	inst_ipaddr2='172.26.1.98'
	inst_ipaddr3='172.26.1.99'
	inst_gw='9.114.209.254'
elif [ $iptype == "priv" ]
then
	vtapdev='enc7246'
	echo 'Adding MACVTAP 'mvtap_$inst_name
        ip link add link $vtapdev mvtap_$inst_name type macvtap mode bridge
        if [ $? -ne 0 ]; then
                echo 'Failed to add MACVTAP device, exiting'
                exit
        fi	
	echo 'About to obtain IP address'
	inst_ipaddr=$(dhclient -pf /var/run/dhclient_mvtap_$inst_name.pid -p 2068 -4 -v mvtap_$inst_name 2>&1 | grep bound | awk '{print $3}')
	echo $inst_ipaddr' has been assigned'
	inst_ipaddr2='172.26.2.'$newoct1
	inst_ipaddr3='172.26.2.'$newoct2
	inst_gw='172.26.1.1'
else
	echo 'Invalid IP Type, must be pub or priv'
	exit
fi

osapath="$( printf '%x' "$(cut -d'.' -f4 <<<"$inst_ipaddr")")"
 

if [[ ! -z "$inst_ipaddr" ]]; then
  useradd -b /data/users/$inst_name -d /data/users/$inst_name -G kvm,users,sudo -s /bin/bash -m $inst_name
  if [ $? -ne 0 ]; then
	  echo 'Failed to add new user '$inst_name
	  exit
  fi
  echo $inst_name":some_random_password!@#$%!" | chpasswd

  btrfs subvolume snapshot /data/$image /data/users/$inst_name/zos
  if [ $? -ne 0 ]; then
	  echo 'btrfs snapshot failed, exiting .. cleanup may be required'
	  exit
  fi
			  
  chmod 770 -R /data/users/$inst_name/zos
  cd /data/users/$inst_name/zos
  ip link set mvtap_$inst_name alias mvtap_$inst_name_$inst_ipaddr
  ip addr del $inst_ipaddr/24 dev mvtap_$inst_name
  ip link set mvtap_$inst_name up

  chown -R $inst_name:ubuadm /data/users/$inst_name/zos

  sed -i 's/path?/'$osapath'/g' /data/users/$inst_name/zos/devmap.txt
  sed -i 's/intf?/mvtap_'$inst_name'/g' /data/users/$inst_name/zos/devmap.txt
  echo 'export PATH=$PATH:/usr/z1090/bin:/data/zPDT_Pub' >> /data/users/$inst_name/.bashrc
  echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/z1090/bin' >> /data/users/$inst_name/.bashrc
  echo 'ulimit -c unlimited' >> /data/users/$inst_name/.bashrc
  echo 'ulimit -d unlimited' >> /data/users/$inst_name/.bashrc
  echo 'ulimit -m unlimited' >> /data/users/$inst_name/.bashrc
  echo 'ulimit -v unlimited' >> /data/users/$inst_name/.bashrc

  echo '**** '$inst_ipaddr' has been assigned ****'
  echo '**** '$inst_ipaddr' has been assigned ****'
  echo '**** '$inst_ipaddr' has been assigned ****'
  echo '**** '$inst_ipaddr' has been assigned ****'
  echo '**** '$inst_ipaddr' has been assigned ****'
else
	echo 'No IP Address found. Exiting, cleanup may be required'
	exit
fi
 
mkdir /data/users/$inst_name/.hasplm
echo 'serveraddr = your_license_server_address' > /data/users/$inst_name/.hasplm/hasp_97252.ini
chown -R $inst_name:$inst_name /data/users/$inst_name/.hasplm

sudo -i -u $inst_name bash << EOF
export PATH=$PATH:/usr/z1090/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/z1090/bin
cd zos;./pdsinit.sh $inst_ipaddr $inst_ipaddr2 $inst_ipaddr3 $inst_gw;awsstart --clean 
ln -s /home/ubuadm/netadcd.sh netadcd.sh
ln -s /home/ubuadm/netstock.sh netstock.sh
EOF


