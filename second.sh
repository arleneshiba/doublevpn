#!/bin/bash

IP2=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
INTERFACE=$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')

#echo -e "Enter IP of first server: eg 111.111.111.111"; read IP1;
#IP1=111.111.111.111
apt update
apt install sudo -y
apt install wget -y
mkdir -p /root/.ssh && touch /root/.ssh/known_hosts
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
apt update -y && apt upgrade -y

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

#Теперь нам необходимо сгенерировать сертификаты для сервера и клиентов, для этого проверим где находятся утилита для генерации сертификатов:
#whereis easy-rsa
#easy-rsa: /usr/share/easy-rsa

#узнаем путь к easy-rsa
easyrsalocation=$(whereis easy-rsa | cut -d: -f2 | cut -c 2-)

#Перейдем в каталог и приступим к генерации сертификатов для openvpn:
cd $easyrsalocation

#Генерируем CA сертификат.
./easyrsa init-pki
./easyrsa --batch build-ca nopass

#Генерируем сертификат сервера:
./easyrsa --batch build-server-full server nopass

#Генерируем сертификат клиента
./easyrsa --batch build-client-full client nopass

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

#И нам необходимо подготовить клиентские сертификаты для передачи на сервер А.

mkdir client-keys
cp -R pki/ca.crt client-keys/
cp -R pki/dh.pem client-keys/
cp -R pki/tls.key client-keys/
cp -R pki/private/client.key client-keys/
cp -R pki/issued/client.crt client-keys/
tar -cvf client.tar client-keys
mv client.tar /root/

#Теперь нам осталось создать файл конфигурации на сервере B:
# nano /etc/openvpn/server.conf

#С содержимым:

echo "port 443
dev tun0
proto tcp-server
ifconfig 192.168.1.1 192.168.1.2
tls-server
daemon
ca /etc/openvpn/keys/ca.crt
cert /etc/openvpn/keys/server.crt
key /etc/openvpn/keys/server.key
dh /etc/openvpn/keys/dh.pem
tls-auth /etc/openvpn/keys/tls.key 0
cipher AES-256-CBC
max-clients 1
persist-key
persist-tun
script-security 3
keepalive 10 120
log /dev/null
comp-lzo
sndbuf 0
rcvbuf 0
up /etc/openvpn/keys/up.sh
down /etc/openvpn/keys/down.sh
user nobody
group nogroup" > /etc/openvpn/server.conf

#Создадим up\down скрипты для настройки маршрутизации трафика. Необходимо отредактировать параметры -o $INTERFACE и —to-source $IP2
#nano /etc/openvpn/keys/up.sh

echo -e "#!/bin/sh
ip route add 10.8.0.0/24 via 192.168.1.2 dev tun0
iptables -t nat -A POSTROUTING --src 10.8.0.0/24 -o $INTERFACE -j SNAT --to-source $IP2
echo 1 > /proc/sys/net/ipv4/ip_forward" > /etc/openvpn/keys/up.sh

#nano /etc/openvpn/keys/down.sh

echo -e "#!/bin/sh
ip route del 10.8.0.0/24 via 192.168.1.2 dev tun0
iptables -D POSTROUTING -t nat --src 10.8.0.0/24 -o $INTERFACE -j SNAT --to-source $IP2" > /etc/openvpn/keys/down.sh

#

apt install bind9 -y

echo "options {
       directory \"/var/cache/bind\";

       // hide version number from clients for security reasons.
           version \"not currently available\";
       #listen-on port 53 { any; };
            #listen-on-v6 port 53 { any; };
           listen-on { 192.168.1.1; };
           allow-recursion { any; };

           allow-query     { any; };

           recursion yes;
           forwarders {
           208.67.222.222;
           208.67.220.220;
            };
            forward only;

            #dnssec-enable yes;
           auth-nxdomain no;
            dnssec-validation auto;

};" > /etc/bind/named.conf.options

apt install ntp -y
systemctl start ntp
systemctl enable ntp

systemctl enable bind9
systemctl restart bind9

#Дадим им права на выполнение:

chmod +x /etc/openvpn/keys/up.sh
chmod +x /etc/openvpn/keys/down.sh

#Добавим openvpn в автозагрузку:
systemctl enable openvpn@server

#Запустим openvpn:
systemctl start openvpn@server



#Скачиваем скрипт для первого сервера
cd
sed -i -e "s/ip2replace/$IP2/g" run1.sh
wget https://raw.githubusercontent.com/botkee/double/main/patch_tcp_debian.sh
bash patch_tcp_debian.sh
exit

#Отправляем подготовленные сертификаты на сервер А:
#scp client.tar run1.sh root@$IP1:/root/

#rm run1.sh

#
#ssh root@$IP1 << EOF
#  echo "In $IP1"
#  chmod +x run1.sh && bash run1.sh
#EOF
