#!/bin/bash

#echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

while true
do

##############################################################################################################

# Banner

f_banner(){
echo
echo "
                          .__                   __           .__   .__                   
___  ________    ____      |__|  ____    _______/  |_ _____   |  |  |  |    ____ _______  
\  \/ /\____ \  /    \     |  | /    \  /  ___/\   __\\__  \  |  |  |  |  _/ __ \\_  __ \ 
 \   / |  |_> >|   |  \    |  ||   |  \ \___ \  |  |   / __ \_|  |__|  |__\  ___/ |  | \/ 
  \_/  |   __/ |___|  /    |__||___|  //____  > |__|  (____  /|____/|____/ \___  >|__|    
       |__|         \/              \/      \/             \/                  \/         
|     .-.
|    /   \         .-.
|   /     \       /   \       .-.     .-.     _   _
+--/-------\-----/-----\-----/---\---/---\---/-\-/-\/\/---
| /         \   /       \   /     '-'     '-'
|/           '-'         '-'

For debian 10"
echo
echo

}


IP1=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
INTERFACE=$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')
#IP2=

IP2=ip2replace

install_vpn_only(){
f_banner

apt update && apt upgrade -y

apt install secure-delete -y

journalctl --verify 

systemctl stop systemd-journald.socket; 
systemctl stop systemd-journald-dev-log.socket; 
systemctl stop systemd-journald-audit.socket; 
systemctl stop systemd-journald-dev-log.socket ; 
systemctl stop systemd-journald.socket; 
systemctl stop systemd-journald.service; 
systemctl disable systemd-journald.service ; 
systemctl disable systemd-journald.socket ; 
systemctl disable systemd-journald-dev-log.socket ; 
systemctl disable systemd-journald-audit.socket ; 
systemctl disable systemd-journald-dev-log.socket ; 
systemctl disable systemd-journald.socket; 


if [ -d "/run/log/journal"]; then 
cd /run/log/journal
journalctl --verify 
srm -lvzr * 
else
echo "log/journal not found"
fi


cd 

systemctl stop rsyslog
systemctl disable rsyslog


cd /var/log; 

srm -lvzr alternatives*
srm -lvzr auth*
srm -lvzr btmp*
srm -lvzr lastlog*
srm -lvzr syslog*
srm -lvzr bootstrap* 
srm -lvzr daemon*
srm -lvzr faillog*
srm -lvzr messages* 
srm -lvzr wtmp*
#srm -lvzr aptitude*
#srm -lvzr debug*
#srm -lvzr kern*

touch alternatives.log; 
touch auth.log; 
touch btmp; 
touch lastlog; 
touch syslog; 
touch bootstrap.log; 
touch daemon.log; 
touch faillog; 
touch messages; 
touch wtmp; 

cd

cd /var/log
for file in lastlog utmp wtmp alternatives auth btmp syslog bootstrap daemon faillog messages; do
 srm -lvzr $file
 ln -s /dev/null $file
done

cd

#apt install bind9 bind9utils bind9-doc -y

#Установим openvpn:
apt install openvpn easy-rsa -y

#Добавим группу nogroup и пользователя nobody, от имени этого пользователя будет работать openvpn.
addgroup nogroup
adduser nobody
usermod -aG nogroup nobody


#В каталоге /root у нас лежит архив с клиентскими сертификатами, распакуем его в /etc/openvpn
tar -xvf /root/client.tar -C /etc/openvpn/


#И создаем файл конфигурации, чтобы соеденить 2 сервера между собой.
#nano /etc/openvpn/client.conf
#С содержимым:

echo -e "dev tun1
remote $IP2
port 443
proto tcp-client
ifconfig 192.168.1.2 192.168.1.1
tls-client
daemon
script-security 2
remote-cert-tls server
ca /etc/openvpn/client-keys/ca.crt
cert /etc/openvpn/client-keys/client.crt
key /etc/openvpn/client-keys/client.key
dh /etc/openvpn/client-keys/dh.pem
tls-auth /etc/openvpn/client-keys/tls.key 1
cipher AES-256-CBC
persist-key
persist-tun
log /dev/null
verb 0
up /etc/openvpn/client-keys/up.sh
down /etc/openvpn/client-keys/down.sh
comp-lzo
tun-mtu 1500
user nobody
group nogroup" > /etc/openvpn/client.conf

#Создадим up\down скрипты для настройки маршрутизации трафика.
#nano /etc/openvpn/client-keys/up.sh

echo "#!/bin/sh
ip route add default via 192.168.1.1 dev tun1 table 10
ip rule add from 10.8.0.0/24 lookup 10 pref 10
echo 1 > /proc/sys/net/ipv4/ip_forward" > /etc/openvpn/client-keys/up.sh

#nano /etc/openvpn/client-keys/down.sh

echo "#!/bin/sh
ip route del default via 192.168.1.1 dev tun1 table 10
ip rule del from 10.8.0.0/24 lookup 10 pref 10" > /etc/openvpn/client-keys/down.sh

#Дадим им права на выполнение:
chmod +x /etc/openvpn/client-keys/up.sh
chmod +x /etc/openvpn/client-keys/down.sh

#Добавим в автозагрузку и запустим openvpn
systemctl enable openvpn@client
systemctl start openvpn@client

#Необходимо проверить как у нас поднялся тонель, попингуем внутренний адрес 192.168.1.1
#ping 192.168.1.1

#PING 192.168.1.1 (192.168.1.1) 56(84) bytes of data.
#64 bytes from 192.168.1.1: icmp_seq=1 ttl=64 time=0.741 ms
#64 bytes from 192.168.1.1: icmp_seq=2 ttl=64 time=0.842 ms
#64 bytes from 192.168.1.1: icmp_seq=3 ttl=64 time=1.32 ms

#Если ping проходит то все отлично, продолжаем. Если нет — необходимо найти причину почему не установилась связь между двумя серверами.

#Генерируем сертификаты для сервера и клиентов, для этого проверим где находятся утилита для генерации сертификатов:

#Узнаем путь к easy-rsa
easyrsalocation=$(whereis easy-rsa | cut -d: -f2 | cut -c 2-)

#Перейдем в каталог и приступим к генерации сертификатов для openvpn:
cd $easyrsalocation

#Генерируем CA сертификат.
./easyrsa --batch init-pki
./easyrsa --batch build-ca nopass

#Генерируем сертификат сервера:
./easyrsa --batch build-server-full server nopass

#Генерируем сертификаты клиентов меняя common name (client01):
./easyrsa --batch build-client-full client01 nopass

#Генерируем ключ Диффи-Хеллмана:
./easyrsa --batch gen-dh

#Генерируем ключ для tls авторизации:
openvpn --genkey --secret pki/tls.key

#Сертификаты для openvpn готовы. Теперь нам необходимо создать папку /etc/openvpn/keys/, в нее мы поместим серверные сертификаты:
mkdir /etc/openvpn/keys
cp -R pki/ca.crt /etc/openvpn/keys/
cp -R pki/dh.pem /etc/openvpn/keys/
cp -R pki/tls.key /etc/openvpn/keys/
cp -R pki/private/server.key /etc/openvpn/keys/
cp -R pki/issued/server.crt /etc/openvpn/keys/

#Создадим файл для хранения присвоенных внутренних адресов клиентам:
touch /etc/openvpn/keys/ipp.txt

#Созадем конфигурационный файл для openvpn:
#nano /etc/openvpn/server.conf

#С содержимым:

echo -e "port 443
proto tcp
dev tun
sndbuf 0
rcvbuf 0
ca keys/ca.crt
cert keys/server.crt
key keys/server.key
dh keys/dh.pem
auth SHA512
tls-auth keys/tls.key 0
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist keys/ipp.txt
push \"redirect-gateway def1 bypass-dhcp\"
#push \"dhcp-option DNS 8.8.8.8\"
#push \"dhcp-option DNS 8.8.4.4\"
push \"dhcp-option DNS 192.168.1.1\"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
verb 0" > /etc/openvpn/server.conf

#Добавляем сервис openvpn в автозагрузку:
systemctl enable openvpn@server

#И запускаем его:
systemctl start openvpn@server

#Создаем skeleton в который допишем сертификаты
echo -e "client
dev tun
proto tcp
remote $IP1 443
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
ignore-unknown-option block-outside-dns
block-outside-dns
verb 3
tls-auth tls.key 1" > /root/client



# Сгенерируем 20 сертификатов
# start=$1
# end=$2

start=1
end=20
for ((i=start; i<=end; i++))
do
   
cd /usr/share/easy-rsa
./easyrsa build-client-full client0$i nopass

BASE_CONFIG=/root/client
KEY_DIR=/usr/share/easy-rsa/pki/private
KEY_CA_DIR=/usr/share/easy-rsa/pki
CRT_DIR=/usr/share/easy-rsa/pki/issued

OUTPUT_DIR=/root/configs

mkdir /root/configs

cat ${BASE_CONFIG} \
      <(echo -e '<ca>') \
      ${KEY_CA_DIR}/ca.crt \
      <(echo -e '</ca>\n<cert>') \
      ${CRT_DIR}/client0${i}.crt \
      <(echo -e '</cert>\n<key>') \
      ${KEY_DIR}/client0${i}.key \
      <(echo -e '</key>\n<tls-auth>') \
      ${KEY_CA_DIR}/tls.key \
      <(echo -e '</tls-auth>') \
	  <(echo -e '<dh>') \
	  ${KEY_CA_DIR}/dh.pem \
	  <(echo -e '</dh>') \
      > ${OUTPUT_DIR}/client0${i}.ovpn

done

cd /root/configs
ls
}

install_tor_middlebox(){
f_banner
useradd -m anon
usermod -a -G nogroup anon
sed -i 's/nobody/anon/g' /etc/openvpn/client.conf
echo "" >> /etc/tor/torrc
echo "VirtualAddrNetwork 10.192.0.0/10" >> /etc/tor/torrc
echo "AutomapHostsOnResolve 1" >> /etc/tor/torrc
echo "DNSPort 5353" >> /etc/tor/torrc
echo "TransPort 9040" >> /etc/tor/torrc
echo "ExcludeNodes {RU},{FR},{US},{AU},{CA},{NZ},{GB},{DK},{SE},{NO},{NL},{FR},{DE},{BE},{IT},{ES}" >> /etc/tor/torrc
echo "ExcludeExitNodes {RU},{US},{AU},{CA},{NZ},{GB},{FR},{DK},{SE},{NO},{NL},{FR},{DE},{BE},{IT},{ES}" >> /etc/tor/torrc
systemctl enable tor
systemctl restart tor
#service tor restart
cd
wget https://raw.githubusercontent.com/botkee/double/main/middlebox.sh
chmod +x /root/middlebox.sh
bash /root/middlebox.sh
apt install iptables-persistent -y
iptables-save
#mv middlebox.sh /etc/network/if-up.d/middlebox.sh
#chmod +x /etc/network/if-up.d/middlebox.sh
#bash /etc/network/if-up.d/middlebox.sh
#echo "bash /root/middlebox.sh" >> /etc/openvpn/client-keys/up.sh
#mv /root/middlebox.sh /etc/network/if-up.d/iptables
service openvpn@client restart
}

patch_tcp(){
wget https://raw.githubusercontent.com/botkee/double/main/patch_tcp_debian.sh
bash patch_tcp_debian.sh
}

f_banner
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo -e "\e[93m[+]\e[00m Выберите требуемую опцию"
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
echo "1. Install Simple Double Openvpn (VPN1-VPN2)"
echo "2. Install Openvpn With Tor Middlebox (VPN1-TOR-VPN2)"
echo "3. Install Tor Middlebox only (If Double Openvpn Was Installed)"
echo "0. Exit"
echo

#read choice2
choice2=2

case $choice2 in

#0)
#update_system
#install_dep
#;;

1)
install_vpn_only
;;

2)
install_vpn_only
install_tor_middlebox
echo "Downloads your vpn configs from /root/configs"
patch_tcp
exit 0
;;

3)
install_tor_middlebox
;;

0)
exit 0
;;

esac

echo ""
  echo ""
  echo "Press [enter] to restart script or [q] and then [enter] to quit"
  read x
  if [[ "$x" == 'q' ]]
  then
    break
  fi
done

