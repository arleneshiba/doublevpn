#!/bin/bash
#
#Usage login to first server and run this script: 
#
# wget https://raw.githubusercontent.com/arleneshiba/doublevpn/main/start.sh && chmod +x start.sh && bash start.sh
#

NORMAL=`echo "\033[m"`
BRED=`printf "\e[1;31m"`
BGREEN=`printf "\e[1;32m"`
BYELLOW=`printf "\e[1;33m"`

KNOWNHOSTS=/root/.ssh/known_hosts

if [ -f "$KNOWNHOSTS" ]; then
    echo "$KNOWNHOSTS exists."
else 
    echo "$KNOWNHOSTS does not exist."
    echo "creating $KNOWNHOSTS"
    mkdir -p /root/.ssh && touch /root/.ssh/known_hosts
fi


apt update
apt install sudo -y
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

apt update -y && apt upgrade -y
apt install tmux -y
#apt install tor -y

apt install sshpass -y

wget https://raw.githubusercontent.com/arleneshiba/doublevpn/main/second.sh
wget -O run1.sh https://raw.githubusercontent.com/arleneshiba/doublevpn/master/first.sh

echo ""
echo -e "${BYELLOW}Enter IP:PASSWORD of second server: eg 222.222.222.222:passw0rd2 ${NORMAL} : "; IFS=":" read -s IP2 SSHPASS;

ssh-keyscan $IP2 >> ~/.ssh/known_hosts

export SSHPASS

sshpass -e scp /root/run1.sh root@$IP2:
rm /root/run1.sh
#sshpass -e torsocks scp /root/second.sh root@$IP2:
#rm /root/second.sh
#sshpass -e torsocks ssh -o PasswordAuthentication=yes root@$IP2 "chmod +x second.sh; bash -s second.sh"


sshpass -e ssh -o PasswordAuthentication=yes root@$IP2 'bash -s' < ~/./second.sh

#torsocks ssh root@$IP2

sshpass -e scp -T root@$IP2:/root/client.tar /root/
sshpass -e scp -T root@$IP2:/root/run1.sh /root/

bash /root/run1.sh

CLIENT_FOR_SERVER2_FINGERPRINT=$(openssl x509 -fingerprint -sha256 -noout -in /etc/openvpn/client-keys/client.crt)
cat << EOF > /root/enable_second.sh
sed -i -e 's/client_for_server2_fingerprint_replace/$CLIENT_FOR_SERVER2_FINGERPRINT/g' /etc/openvpn/server.conf
systemctl enable --now openvpn@server.service
EOF
chmod +x /root/enable_second.sh
sshpass -e ssh -o PasswordAuthentication=yes root@$IP2 'bash -s' < ~/./enable_second.sh
