#!/bin/bash

#echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

while true
do

##############################################################################################################

# Banner

f_banner(){
echo ""
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

For debian 12"
echo ""
echo ""

}



IP1=$(nslookup myip.opendns.com resolver1.opendns.com | awk '/^Address: / { print $2 }')



# Если первоначальный источник не доступен, используем запасной вариант

if [ -z "$IP1" ]; then

  IP1=$(curl -s https://api.ipify.org)

fi

INTERFACE=$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')
#IP2=

IP2=ip2replace
SERVER2_FINGERPRINT=server2_fingerprint2replace

install_vpn_only(){
f_banner

apt update && apt upgrade -y

apt install secure-delete -y


cd

#apt install bind9 bind9utils bind9-doc -y

#Установим openvpn:
apt install openvpn easy-rsa iptables -y

#Добавим группу nogroup и пользователя nobody, от имени этого пользователя будет работать openvpn.
addgroup nogroup
adduser nobody
usermod -aG nogroup nobody


#В каталоге /root у нас лежит архив с клиентскими сертификатами, распакуем его в /etc/openvpn
tar -xvf /root/client.tar -C /etc/openvpn/


#И создаем файл конфигурации, чтобы соединить 2 сервера между собой.
#nano /etc/openvpn/client.conf
#С содержимым:

echo -e "dev tun1
remote $IP2
port 843
proto tcp-client
ifconfig 192.168.99.2 192.168.99.1
daemon
script-security 2
<peer-fingerprint>
$SERVER2_FINGERPRINT
</peer-fingerprint>
dh none
cipher AES-256-GCM
ncp-ciphers AES-256-GCM:CHACHA20-POLY1305
fragment 1300
mssfix 1300
persist-key
persist-tun
log /dev/null
verb 0
up /etc/openvpn/client-keys/up.sh
down /etc/openvpn/client-keys/down.sh
script-security 3
compress lz4-v2
tls-version-min 1.2
tun-mtu 1400
user nobody
group nogroup" > /etc/openvpn/client.conf

#Создадим up\down скрипты для настройки маршрутизации трафика.
#nano /etc/openvpn/client-keys/up.sh

echo "#!/bin/sh
ip route add default via 192.168.99.1 dev tun1 table 10
ip rule add from 10.8.0.0/24 lookup 10 pref 10
echo 1 > /proc/sys/net/ipv4/ip_forward" > /etc/openvpn/client-keys/up.sh

#nano /etc/openvpn/client-keys/down.sh

echo "#!/bin/sh
ip route del default via 192.168.99.1 dev tun1 table 10
ip rule del from 10.8.0.0/24 lookup 10 pref 10" > /etc/openvpn/client-keys/down.sh

#Дадим им права на выполнение:
chmod +x /etc/openvpn/client-keys/up.sh
chmod +x /etc/openvpn/client-keys/down.sh

#Добавим в автозагрузку и запустим openvpn
systemctl enable openvpn@client
systemctl start openvpn@client

#Необходимо проверить как у нас поднялся тонель, попингуем внутренний адрес 192.168.1.1
#ping 192.168.99.1

#PING 192.168.1.1 (192.168.99.1) 56(84) bytes of data.
#64 bytes from 192.168.99.1: icmp_seq=1 ttl=64 time=0.741 ms
#64 bytes from 192.168.99.1: icmp_seq=2 ttl=64 time=0.842 ms
#64 bytes from 192.168.99.1: icmp_seq=3 ttl=64 time=1.32 ms

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
#./easyrsa --batch build-client-full client01 nopass

#Генерируем ключ Диффи-Хеллмана:
#./easyrsa --batch gen-dh

#Генерируем ключ для tls авторизации:
openvpn --genkey secret pki/tls.key

#Сертификаты для openvpn готовы. Теперь нам необходимо создать папку /etc/openvpn/keys/, в нее мы поместим серверные сертификаты:
mkdir -p /etc/openvpn/keys
cp -R pki/ca.crt /etc/openvpn/keys/
#cp -R pki/dh.pem /etc/openvpn/keys/
cp -R pki/tls.key /etc/openvpn/keys/
cp -R pki/private/server.key /etc/openvpn/keys/
cp -R pki/issued/server.crt /etc/openvpn/keys/

#Создадим файл для хранения присвоенных внутренних адресов клиентам:
touch /etc/openvpn/keys/ipp.txt

#Созадем конфигурационный файл для openvpn:
#nano /etc/openvpn/server.conf

#С содержимым:

echo -e "port 766
proto tcp
dev tun
sndbuf 524288
rcvbuf 524288
push \"sndbuf 524288\"
push \"rcvbuf 524288\"
ca keys/ca.crt
cert keys/server.crt
key keys/server.key
dh none
auth SHA512
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist keys/ipp.txt
push \"redirect-gateway def1 bypass-dhcp\"
#push \"dhcp-option DNS 8.8.8.8\"
#push \"dhcp-option DNS 8.8.4.4\"
push \"dhcp-option DNS 192.168.99.1\"
keepalive 30 120
push \"block-outside-dns\"
tls-crypt keys/tls.key
cipher AES-256-GCM
ncp-ciphers AES-256-GCM:CHACHA20-POLY1305
tls-version-min 1.2
verify-client-cert require
tun-mtu-extra 32
compress lz4-v2
fragment 1300
mssfix 1300
user nobody
group nogroup
persist-key
persist-tun
tun-mtu 1400
verb 0" > /etc/openvpn/server.conf

server1_fingerprint=$(openssl x509 -fingerprint -sha256 -in /etc/openvpn/keys/server.crt -noout | cut -d= -f2)

#Добавляем сервис openvpn в автозагрузку:
systemctl enable openvpn@server

#И запускаем его:
systemctl start openvpn@server

#Создаем skeleton в который допишем сертификаты
echo -e "client
dev tun0
proto tcp
remote $IP1 766
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-GCM
ncp-ciphers AES-256-GCM:CHACHA20-POLY1305
#ignore-unknown-option block-outside-dns
#block-outside-dns
verb 3
tun-mtu 1400
tls-auth tls.key 1" > /root/client

# Устанавливаем рабочие директории
BASE_CONFIG="/root/client"
OUTPUT_DIR="/root/configs"

# Устанавливаем диапазон клиентов
start=1
end=20

# Создаем директорию для конфигов, если она не существует
mkdir -p "$OUTPUT_DIR"

# Автоматическое подтверждение подписей
export EASYRSA_BATCH=1

# Переключаемся в директорию Easy-RSA
cd /usr/share/easy-rsa || { echo "Ошибка перехода в директорию /usr/share/easy-rsa"; exit 1; }

# Удаляем устаревший DH, если он существует (не обязателен)
rm -f pki/dh.pem

# Генерация клиентских конфигураций
for ((i=start; i<=end; i++))
do
    # Генерация клиентского сертификата без пароля
    ./easyrsa build-client-full client0$i nopass || { echo "Ошибка генерации сертификата для client0$i"; exit 1; }

    # Создание .ovpn-конфига, только с отпечатком сервера и другими нужными параметрами
    cat "$BASE_CONFIG" \
        <(echo -e '<peer-fingerprint>') \
        "$server1_fingerprint" \
        <(echo -e '</peer-fingerprint>\n<tls-auth>') \
        "/usr/share/easy-rsa/pki/ta.key" \
        <(echo -e '</tls-auth>') \
        > "$OUTPUT_DIR/client0${i}.ovpn" || { echo "Ошибка создания конфигурации для client0$i"; exit 1; }

    echo "Конфигурация для client0$i создана"
done

# Проверка созданных конфигураций
cd "$OUTPUT_DIR" || { echo "Ошибка перехода в директорию конфигураций"; exit 1; }
ls -l

}


patch_tcp(){
wget https://raw.githubusercontent.com/arleneshiba/doublevpn/main/patch_tcp_debian.sh
bash patch_tcp_debian.sh
}

f_banner
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo -e "\e[93m[+]\e[00m Выберите требуемую опцию"
echo -e "\e[34m---------------------------------------------------------------------------------------------------------\e[00m"
echo ""
echo "1. Install Simple Double Openvpn (VPN1-VPN2)"
echo "2. Install Simple Double Openvpn (VPN1-VPN2) and patch"
echo "0. Exit"
echo

#read choice2
choice2=1

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
echo "Downloads your vpn configs from /root/configs"
patch_tcp
exit 0
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

