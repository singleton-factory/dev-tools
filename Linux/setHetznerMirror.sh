#!/bin/bash

PACKAGE='iputils-ping'
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $PACKAGE|grep "install ok installed")
apt update
if [ "" = "$PKG_OK" ]; then
  apt --yes install $PACKAGE
fi
apt install ca-certificates -y

SERVER='mirror.hetzner.com'
echo "Testing availability of host $SERVER..."
ping -c1 $SERVER > /dev/null
if [ $? -eq 0 ]; then
  echo "$SERVER available. Setting sources..."
  osID=$(env -i bash -c '. /etc/os-release; echo $ID')
  osVersionID=$(env -i bash -c '. /etc/os-release; echo $VERSION_ID')
  osCodename=$(env -i bash -c '. /etc/os-release; echo $VERSION_CODENAME')
  echo "OS ID: $osID"
  echo "OS Version ID: $osVersionID"
  echo "OS Codename: $osCodename"
  if [ "$osID" = "debian" ]; then
    if [ "$osVersionID" -lt "13" ]; then
      echo "deb https://mirror.hetzner.com/debian/packages  $osCodename          main contrib non-free" > /etc/apt/sources.list
      echo "deb https://mirror.hetzner.com/debian/packages  $osCodename-updates  main contrib non-free" >> /etc/apt/sources.list
      echo "deb https://mirror.hetzner.com/debian/security  $osCodename-security  main contrib non-free" >> /etc/apt/sources.list
      echo "deb https://mirror.hetzner.com/debian/packages  $osCodename-backports main contrib non-free" >> /etc/apt/sources.list
    else
      cat <<EOF > /etc/apt/sources.list.d/hetzner.sources
Types: deb
URIs: https://mirror.hetzner.com/debian/packages
Suites: $osCodename $osCodename-updates $osCodename-backports
Components: main contrib non-free
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://mirror.hetzner.com/debian/security
Suites: $osCodename-security
Components: main contrib non-free
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
    mv /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak
    fi
  fi
  if [ "$osID" = "ubuntu" ]; then
  apt install bc -y
    if [ $(echo "$osVersionID < 26.04" | bc) -eq 1 ]; then
      echo "deb https://mirror.hetzner.com/ubuntu/packages  $osCodename          main restricted universe multiverse" > /etc/apt/sources.list
      echo "deb https://mirror.hetzner.com/ubuntu/packages  $osCodename          main restricted universe multiverse" > /etc/apt/sources.list
      echo "deb https://mirror.hetzner.com/ubuntu/packages  $osCodename-updates  main restricted universe multiverse" >> /etc/apt/sources.list
      echo "deb https://mirror.hetzner.com/ubuntu/security  $osCodename-security  main restricted universe multiverse" >> /etc/apt/sources.list
      echo "deb https://mirror.hetzner.com/ubuntu/packages  $osCodename-backports main restricted universe multiverse" >> /etc/apt/sources.list
    else
      cat <<EOF > /etc/apt/sources.list.d/hetzner.sources
Types: deb
URIs: https://mirror.hetzner.com/ubuntu/packages
Suites: $osCodename $osCodename-updates $osCodename-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirror.hetzner.com/ubuntu/security
Suites: $osCodename-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
    mv /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
    fi
  fi
else
  echo "$SERVER not available. Using default sources."
fi
apt update