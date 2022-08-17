#!/bin/sh
# Switch to Adguard setup
# Grab packages for AGH and updates.
opkg update
opkg install sudo ca-certificates ca-bundle curl wget wget-ssl tar unzip bind-tools

#grab and install AGH
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -c edge

# 1. Disable dnsmasq from needlessly looking at the /etc/resolv.conf file.
# 2. Reduce dnsmasq cache size as it will only provide PTR/rDNS info.
# 3. Disable rebind protection. Filtered DNS service responses from blocked domains are 0.0.0.0 which causes dnsmasq to fill the system log with possible DNS-rebind attack detected messages.
# 4. Move dnsmasq to port 5353.
# 5. Set Ipv4 DNS advertised by option 6 DHCP 
# 6. Set Ipv6 DNS advertised by DHCP
# 7. Set 24hr DHCP Leases
# Get the first IPv4 and IPv6 Address of router and store them in following variables for use during the script.
NET_ADDR=$(/sbin/ip -o -4 addr list br-lan | awk 'NR==1{ split($4, ip_addr, "/"); print ip_addr[1] }')
NET_ADDR6=$(/sbin/ip -o -6 addr list br-lan scope global | awk 'NR==1{ split($4, ip_addr, "/"); print ip_addr[1] }')
 
echo "Router IPv4 : ""${NET_ADDR}"
echo "Router IPv6 : ""${NET_ADDR6}"

uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].cachesize='1000'
uci set dhcp.@dnsmasq[0].rebind_protection='0'
uci set dhcp.@dnsmasq[0].port='5353'
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server="${NET_ADDR}"
uci set dhcp.lan.leasetime='24h' 

#Delete existing config ready to install new options.
uci -q delete dhcp.lan.dhcp_option
uci -q delete dhcp.lan.dns

# DHCP option 6: which DNS (Domain Name Server) to include in the IP configuration for name resolution
uci add_list dhcp.lan.dhcp_option='6,'"${NET_ADDR}" 

#DHCP option 3: default router or last resort gateway for this interface
uci add_list dhcp.lan.dhcp_option='3,'"${NET_ADDR}"

#Set IPv6 Announced DNS
for OUTPUT in $(ip -o -6 addr list br-lan scope global | awk '{ split($4, ip_addr, "/"); print ip_addr[1] }')
do
	echo "Adding $OUTPUT to IPV6 DNS"
	uci add_list dhcp.lan.dns=$OUTPUT
done

# Save changes
uci commit dhcp

# Restart dnsmasq service to reflect changes
/etc/init.d/dnsmasq restart

echo 'Goto http://'"${NET_ADDR}"':3000 and configure AdGuardHome.'