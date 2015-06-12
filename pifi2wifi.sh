#!/bin/bash -e

#Created for 2015-05-05-raspbian-wheezy.img
#Reference:
#http://www.maketecheasier.com/set-up-raspberry-pi-as-wireless-access-point/
#http://www.daveconroy.com/turn-your-raspberry-pi-into-a-wifi-hotspot-with-edimax-nano-usb-ew-7811un-rtl8188cus-chipset/

#Install raspbian and boot pi with ethernet and two rtl8188cus wifi cards

#REMOVE JUNK AND UPDATE

#sudo apt-get purge wolfram-engine
#sudo apt-get update
#sudo apt-get upgrade
#sudo apt-get dist-upgrade
#sudo raspi-config
#echo Set the timezone and GPU memory to 16.
#sudo rpi-update 
#sudo reboot

#ADD EDUROAM (REQUIRES VALID LOGIN)

sudo mv /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf.bak
cat <<EOF | sudo tee /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
   ssid="eduroam"
   scan_ssid=1
   key_mgmt=WPA-EAP
   pairwise=CCMP TKIP
   group=CCMP TKIP
   eap=PEAP
   identity="XXX you@youruni.ac.uk XXX"
   password="XXX yourpassword XXX"
   ca_cert="/etc/certs/AddTrustExternalRootCA.pem"
   phase1="peapver=0"
   phase2="auth=MSCHAPV2"
}
EOF
sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf

#ADD EDUROAM CERTIFICATE

sudo mkdir /etc/certs
cat <<EOF | sudo tee /etc/certs/AddTrustExternalRootCA.pem > /dev/null
-----BEGIN CERTIFICATE-----
XXX your institution's eduroam certificate XXX
-----END CERTIFICATE-----
EOF

#CONFIGURE ONE WIFI NETWORKS AND WIRED TO CONNECT TO ACCESS POINT

sudo mv /etc/network/interfaces /etc/network/interfaces.bak
cat <<EOF | sudo tee /etc/network/interfaces > /dev/null
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet static
address 192.168.42.1
netmask 255.255.255.0

auto wlan1
allow-hotplug wlan1
iface wlan1 inet manual
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

pre-up iptables-restore < /etc/iptables.ipv4.nat
EOF

#INSTALL THE DHCP SERVER AND CONFIGURE IT

sudo apt-get install isc-dhcp-server || true

sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
sudo sed -i: 's/^option domain-name/#option domain-name/g' /etc/dhcp/dhcpd.conf
sudo sed -i: 's/^#authoritative;/authoritative;/g' /etc/dhcp/dhcpd.conf

cat <<EOF | sudo tee -a /etc/dhcp/dhcpd.conf > /dev/null
subnet 192.168.42.0 netmask 255.255.255.0 {
range 192.168.42.10 192.168.42.50;
option broadcast-address 192.168.42.255;
option routers 192.168.42.1;
default-lease-time 600;
max-lease-time 7200;
option domain-name "local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF

sudo sed -i: 's/^INTERFACES=""/INTERFACES="eth0"/g' /etc/default/isc-dhcp-server

#ENABLE FORWARDING AND CONFIGURE IPTABLES

sudo sed -i: 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

echo Power off, unplug ethernet cable, cross your fingers, power on.
