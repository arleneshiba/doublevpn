#!/bin/bash

#Tested on ubuntu 18.04

apt update
sudo apt -y install software-properties-common dirmngr apt-transport-https lsb-release ca-certificates
#sudo add-apt-repository 'deb http://deb.debian.org/debian buster-backports main'

sudo apt install --install-recommends linux-generic-hwe-18.04 xserver-xorg-hwe-18.04
apt update
sudo apt-get install linux-image-5.9.0-0.bpo.5-amd64 -y
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sudo sysctl -p
#sysctl net.ipv4.tcp_congestion_control
reboot
