# RouterOS 7 configuration template
# Review interface names and existing configuration before import.
# Never store real passwords or private keys in this file.
# Intended for a prepared device; do not paste blindly into a live router.

# Device: MikroTik RB4011iGS+RM (RTR-GW-01)
# Assumes ether1 WAN uses DHCP and sfp-sfpplus1 is tagged trunk to CRS328.
# VLAN 50 intentionally has no L3 interface. Replace WAN setup if ISP uses PPPoE/static IP.
# Set unique WiFi/admin passwords before import; reserve 192.168.99.10 for admin host.
# Apply via console/Safe Mode on a prepared device, never blindly on a live router.

# Bridge VLAN-aware: sfp-sfpplus1 trunk; ether10 access port in VLAN 99
/system identity set name=RTR-GW-01
# Porty ether2-ether9 są zaparkowane zgodnie z planem portów
/interface ethernet disable ether2,ether3,ether4,ether5,ether6,ether7,ether8,ether9
/interface bridge
add name=bridge-vlans protocol-mode=rstp vlan-filtering=no
/interface bridge port
add bridge=bridge-vlans interface=sfp-sfpplus1 pvid=999 frame-types=admit-only-vlan-tagged ingress-filtering=yes
add bridge=bridge-vlans interface=ether10 pvid=99 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes
/interface bridge vlan
add bridge=bridge-vlans tagged=bridge-vlans,sfp-sfpplus1 vlan-ids=10,20,30,40
add bridge=bridge-vlans tagged=bridge-vlans,sfp-sfpplus1 untagged=ether10 vlan-ids=99
/interface bridge set bridge-vlans vlan-filtering=yes

# VLAN-y routowane; bazą jest bridge VLAN-aware, a VLAN 50 pozostaje bez L3
/interface vlan
add interface=bridge-vlans name=vlan10-pracownicy vlan-id=10
add interface=bridge-vlans name=vlan20-goscie vlan-id=20
add interface=bridge-vlans name=vlan30-serwery vlan-id=30
add interface=bridge-vlans name=vlan40-drukarki vlan-id=40
add interface=bridge-vlans name=vlan99-management vlan-id=99

/ip address
add address=192.168.10.1/24 interface=vlan10-pracownicy
add address=192.168.20.1/24 interface=vlan20-goscie
add address=192.168.30.1/24 interface=vlan30-serwery
add address=192.168.40.1/24 interface=vlan40-drukarki
add address=192.168.99.1/24 interface=vlan99-management

/interface list
add name=WAN
add name=LAN
/interface list member
add interface=ether1 list=WAN
add interface=vlan10-pracownicy list=LAN
add interface=vlan20-goscie list=LAN
add interface=vlan30-serwery list=LAN
add interface=vlan40-drukarki list=LAN
add interface=vlan99-management list=LAN

# Zmień tę sekcję, jeśli operator używa PPPoE lub IP statycznego
/ip dhcp-client
add add-default-route=yes interface=ether1 use-peer-dns=no disabled=no

/ip pool
add name=pool-vlan10 ranges=192.168.10.100-192.168.10.200
add name=pool-vlan20 ranges=192.168.20.50-192.168.20.250

/ip dhcp-server
add address-pool=pool-vlan10 interface=vlan10-pracownicy name=dhcp-vlan10 disabled=no
add address-pool=pool-vlan20 interface=vlan20-goscie name=dhcp-vlan20 disabled=no

/ip dhcp-server network
add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=192.168.30.10 domain=firma.local
add address=192.168.20.0/24 gateway=192.168.20.1 dns-server=1.1.1.1,8.8.8.8

# Router nie pełni roli DNS dla klientów. DNS firmowe zapewnia kontroler AD.
/ip dns
set allow-remote-requests=no

/ip firewall address-list
add address=192.168.10.0/24 list=INTERNET-DOZWOLONY
add address=192.168.20.0/24 list=INTERNET-DOZWOLONY
add address=192.168.30.0/24 list=INTERNET-DOZWOLONY
add address=192.168.10.0/24 list=SIECI-WEWNETRZNE
add address=192.168.20.0/24 list=SIECI-WEWNETRZNE
add address=192.168.30.0/24 list=SIECI-WEWNETRZNE
add address=192.168.40.0/24 list=SIECI-WEWNETRZNE
add address=192.168.50.0/24 list=SIECI-WEWNETRZNE
add address=192.168.99.0/24 list=SIECI-WEWNETRZNE

# Host administratora: zarezerwuj 192.168.99.10 dla stacji administracyjnej
add address=192.168.99.10/32 list=ADMIN-HOST comment="PAW administratora"
add address=192.168.99.3/32 list=CAPS comment="AP parter"
add address=192.168.99.4/32 list=CAPS comment="AP pietro"

/ip firewall nat
add action=masquerade chain=srcnat out-interface-list=WAN src-address-list=INTERNET-DOZWOLONY comment="NAT dla VLAN 10, 20, 30"

/ip firewall filter
# INPUT — ruch do routera
add action=accept chain=input connection-state=established,related comment="INPUT: ruch nawiazany"
add action=drop chain=input connection-state=invalid comment="INPUT: odrzucenie invalid"
add action=accept chain=input in-interface=vlan99-management src-address-list=ADMIN-HOST protocol=icmp comment="INPUT: ICMP z hosta administratora"
add action=accept chain=input in-interface=vlan10-pracownicy protocol=udp dst-port=67 comment="INPUT: DHCP VLAN 10"
add action=accept chain=input in-interface=vlan20-goscie protocol=udp dst-port=67 comment="INPUT: DHCP VLAN 20"
add action=accept chain=input in-interface=vlan99-management src-address-list=CAPS protocol=udp dst-port=5246,5247 comment="INPUT: CAPsMAN tylko z AP"
add action=accept chain=input in-interface=vlan99-management src-address-list=ADMIN-HOST protocol=tcp dst-port=22,8291 comment="INPUT: SSH i Winbox z hosta administratora"
add action=drop chain=input in-interface-list=WAN comment="INPUT: blokada od WAN"
add action=drop chain=input comment="INPUT: domyslna blokada"

# FORWARD — ruch przechodzący przez router
add action=accept chain=forward connection-state=established,related comment="FORWARD: ruch nawiazany"
add action=drop chain=forward connection-state=invalid comment="FORWARD: odrzucenie invalid"
add action=drop chain=forward in-interface=vlan20-goscie dst-address-list=SIECI-WEWNETRZNE comment="FORWARD: goscie bez dostepu do sieci wewnetrznych"
add action=accept chain=forward in-interface=vlan99-management out-interface-list=LAN comment="FORWARD: administracja do routowanych VLAN-ow"
add action=accept chain=forward in-interface=vlan10-pracownicy dst-address=192.168.30.10 comment="FORWARD: pracownicy do AD DNS i udzialow serwera"
add action=accept chain=forward in-interface=vlan10-pracownicy out-interface=vlan40-drukarki dst-address=192.168.40.0/24 protocol=tcp dst-port=80,443,515,631,9100 comment="FORWARD: drukowanie z VLAN 10"
add action=accept chain=forward in-interface=vlan40-drukarki src-address=192.168.40.11 dst-address=192.168.30.10 protocol=tcp dst-port=445 comment="FORWARD: skany MFP do udzialu SMB"
add action=accept chain=forward src-address-list=INTERNET-DOZWOLONY out-interface-list=WAN comment="FORWARD: wybrane VLAN-y do Internetu"
add action=drop chain=forward comment="FORWARD: domyslna blokada"

# Konto z uprawnieniami do administracji RouterOS, bez API/FTP/WebFig/Telnet
/user group add name=netadmin policy=ssh,read,write,policy,test,winbox,password
/user add name=operator1 group=netadmin address=192.168.99.10/32 password="ZASTAP_UNIKALNYM_HASLEM"
/user set [find where name="operator1"] inactivity-timeout=10m inactivity-policy=logout

# Pozostaw tylko WinBox i SSH, ograniczone także do hosta administratora
/ip service disable telnet,ftp,www,www-ssl,api,api-ssl
/ip service set [find where name="ssh"] available-from=192.168.99.10/32
/ip service set [find where name="winbox"] available-from=192.168.99.10/32
/ip ssh set strong-crypto=yes forwarding-enabled=no

/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
/tool mac-server ping set enabled=no
/ip neighbor discovery-settings set discover-interface-list=none
/tool bandwidth-server set enabled=no


# CAPsMAN WiFi dla dwóch punktów cAP ax; zabezpieczenie Wi-Fi uzupełnij własnym hasłem
/interface wifi security
add name=sec-pracownicy authentication-types=wpa2-psk,wpa3-psk ft=yes ft-over-ds=yes passphrase="USTAW_DLUGIE_UNIKALNE_HASLO_PRACOWNICY"
add name=sec-goscie authentication-types=wpa2-psk,wpa3-psk passphrase="USTAW_DLUGIE_UNIKALNE_HASLO_GOSCIE"
/interface wifi datapath
add name=dp-pracownicy vlan-id=10
add client-isolation=yes name=dp-goscie vlan-id=20
/interface wifi configuration
add country=Poland name=cfg-pracownicy rrm=yes wnm=yes security=sec-pracownicy ssid=FIRMA
add country=Poland name=cfg-goscie rrm=yes wnm=yes security=sec-goscie ssid=FIRMA-GOSCIE
/interface wifi provisioning
add action=create-dynamic-enabled master-configuration=cfg-pracownicy slave-configurations=cfg-goscie supported-bands=2ghz-ax
add action=create-dynamic-enabled master-configuration=cfg-pracownicy slave-configurations=cfg-goscie supported-bands=5ghz-ax
/interface wifi capsman
set ca-certificate=auto enabled=yes interfaces=vlan99-management

# After confirming a second login session, run this manually in a separate session:
# /user disable [find where name="admin"]
