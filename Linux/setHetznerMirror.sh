#!/bin/bash

PACKAGE='iputils-ping'
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $PACKAGE|grep "install ok installed")
if [ "" = "$PKG_OK" ]; then
  apt update
  apt --yes install $PACKAGE
fi
apt install ca-certificates -y

SERVER='mirror.hetzner.com'
echo "Testing availability of host $SERVER..."
ping -c1 $SERVER > /dev/null
if [ $? -eq 0 ]; then
  echo "$SERVER available. Setting sources..."
  osID=$(env -i bash -c '. /etc/os-release; echo $ID')
  osCodename=$(env -i bash -c '. /etc/os-release; echo $VERSION_CODENAME')
  echo "OS ID: $osID"
  echo "OS Codename: $osCodename"
  if [ "$osID" = "debian" ]; then
    echo "deb https://mirror.hetzner.com/debian/packages  $osCodename          main contrib non-free" > /etc/apt/sources.list
    echo "deb https://mirror.hetzner.com/debian/packages  $osCodename-updates  main contrib non-free" >> /etc/apt/sources.list
    echo "deb https://mirror.hetzner.com/debian/security  $osCodename-security  main contrib non-free" >> /etc/apt/sources.list
    echo "deb https://mirror.hetzner.com/debian/packages  $osCodename-backports main contrib non-free" >> /etc/apt/sources.list
  fi
  if [ "$osID" = "ubuntu" ]; then
    echo "deb https://mirror.hetzner.com/ubuntu/packages  $osCodename          main restricted universe multiverse" > /etc/apt/sources.list
    echo "deb https://mirror.hetzner.com/ubuntu/packages  $osCodename-updates  main restricted universe multiverse" >> /etc/apt/sources.list
    echo "deb https://mirror.hetzner.com/ubuntu/security  $osCodename-security  main restricted universe multiverse" >> /etc/apt/sources.list
    echo "deb https://mirror.hetzner.com/ubuntu/packages  $osCodename-backports main restricted universe multiverse" >> /etc/apt/sources.list
  fi
else
  echo "$SERVER not available. Using default sources."
fi