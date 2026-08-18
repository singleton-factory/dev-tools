#!/bin/bash

PACKAGE='iputils-ping'
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $PACKAGE|grep "install ok installed")
sudo apt update
if [ "" = "$PKG_OK" ]; then
  sudo apt --yes install $PACKAGE
fi

SERVER='ai-proxy.lan'
echo "Testing availability of host $SERVER..."
sudo ping -c1 $SERVER > /dev/null
if [ $? -eq 0 ]; then
  echo "$SERVER available. Setting up codex..."
  sudo apt install -y nodejs npm
  sudo npm install -g @openai/codex
  mkdir -p "$HOME/.codex" && curl -o "$HOME/.codex/config.toml" http://ai-proxy.lan/codex/config.toml
else
  echo "$SERVER not available."
fi