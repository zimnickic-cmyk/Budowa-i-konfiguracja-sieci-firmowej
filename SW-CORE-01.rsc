# RouterOS 7 configuration template
# Review interface names and existing configuration before import.
# Never store real passwords or private keys in this file.
# Intended for a prepared device; do not paste blindly into a live router.

# Device: MikroTik CRS328-24P-4S+RM (SW-CORE-01)
# VLAN 50 is L2-only; VLAN 999 parking; AP uplinks are ether23/24.
# Configure via console/Safe Mode; the final bridge vlan-filtering=yes can affect access.

# 1. Utworzenie bridge'a
/system identity set name=SW-CORE-01
/interface bridge add name=bridge-lan vlan-filtering=no

# 2. Konfiguracja portów (Access oraz Trunk)
/interface bridge port
# Uplink 10G do RB4011 (tylko ramki tagowane; PVID 999 nie jest native VLAN)
add bridge=bridge-lan interface=sfp-sfpplus1 pvid=999 frame-types=admit-only-vlan-tagged

# Stacje robocze (VLAN 10)
add bridge=bridge-lan interface=ether1 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether2 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether3 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether4 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether5 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether6 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether7 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether8 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether9 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether10 pvid=10 frame-types=admit-only-untagged-and-priority-tagged

# Drukarki (VLAN 40)
add bridge=bridge-lan interface=ether11 pvid=40 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether12 pvid=40 frame-types=admit-only-untagged-and-priority-tagged

# Serwer Dell R730 i QNAP (VLAN 30, 50, 99)
add bridge=bridge-lan interface=ether13 pvid=30 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether14 pvid=50 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether15 pvid=99 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether16 pvid=50 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether17 pvid=99 frame-types=admit-only-untagged-and-priority-tagged

# Nieużywane porty -> VLAN 999 (PARKING)
add bridge=bridge-lan interface=ether18 pvid=999 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether19 pvid=999 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether20 pvid=999 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=ether21 pvid=999 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=sfp-sfpplus2 pvid=999 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=sfp-sfpplus3 pvid=999 frame-types=admit-only-untagged-and-priority-tagged
add bridge=bridge-lan interface=sfp-sfpplus4 pvid=999 frame-types=admit-only-untagged-and-priority-tagged

# Port serwisowy administratora (VLAN 99)
add bridge=bridge-lan interface=ether22 pvid=99 frame-types=admit-only-untagged-and-priority-tagged

# Punkty dostępowe cAP ax (Trunk: untagged VLAN 99 dla Mgmt, tagged VLAN 10 i 20 dla SSID)
add bridge=bridge-lan interface=ether23 pvid=99 frame-types=admit-all ingress-filtering=yes
add bridge=bridge-lan interface=ether24 pvid=99 frame-types=admit-all ingress-filtering=yes

# Zasilanie punktów dostępowych PoE+
/interface ethernet poe
set [find where name=ether23] poe-out=auto-on
set [find where name=ether24] poe-out=auto-on

# 3. Tablica VLAN-ów na przełączniku
/interface bridge vlan
add bridge=bridge-lan tagged=sfp-sfpplus1,ether23,ether24 untagged=ether1,ether2,ether3,ether4,ether5,ether6,ether7,ether8,ether9,ether10 vlan-ids=10
add bridge=bridge-lan tagged=sfp-sfpplus1,ether23,ether24 vlan-ids=20
add bridge=bridge-lan tagged=sfp-sfpplus1 untagged=ether13 vlan-ids=30
add bridge=bridge-lan tagged=sfp-sfpplus1 untagged=ether11,ether12 vlan-ids=40
add bridge=bridge-lan untagged=ether14,ether16 vlan-ids=50
add bridge=bridge-lan tagged=bridge-lan,sfp-sfpplus1 untagged=ether15,ether17,ether22,ether23,ether24 vlan-ids=99
add bridge=bridge-lan untagged=ether18,ether19,ether20,ether21,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 vlan-ids=999

# 4. Wyłączenie administracyjne nieużywanych portów
/interface ethernet disable ether18,ether19,ether20,ether21,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4

# 5. Interfejs zarządzający switcha w VLAN 99
/interface vlan add interface=bridge-lan name=vlan99-mgmt vlan-id=99
/ip address add address=192.168.99.2/24 interface=vlan99-mgmt
/ip route add gateway=192.168.99.1

# 6. Aktywacja VLAN Filtering
/interface bridge set bridge-lan vlan-filtering=yes
# Management access hardening; reserve 192.168.99.10 for the admin workstation.
/user group add name=netadmin policy=ssh,read,write,policy,test,winbox,password
/user add name=operator1 group=netadmin address=192.168.99.10/32 password="REPLACE_WITH_UNIQUE_STRONG_PASSWORD"
/user set [find where name="operator1"] inactivity-timeout=10m inactivity-policy=logout
/ip service disable telnet,ftp,www,www-ssl,api,api-ssl
/ip service set [find where name="ssh"] available-from=192.168.99.10/32
/ip service set [find where name="winbox"] available-from=192.168.99.10/32
/ip ssh set strong-crypto=yes forwarding-enabled=no
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
/tool mac-server ping set enabled=no
/ip neighbor discovery-settings set discover-interface-list=none
/tool bandwidth-server set enabled=no
# After confirming a second login session, run manually (do not import automatically):
# /user disable [find where name="admin"]
