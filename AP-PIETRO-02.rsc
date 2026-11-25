# RouterOS 7 configuration template
# Review interface names and existing configuration before import.
# Never store real passwords or private keys in this file.
# Intended for a prepared device; do not paste blindly into a live router.

# Device: MikroTik cAP ax (AP-PIETRO-02)
# Management VLAN 99 untagged, SSIDs mapped by CAPsMAN to tagged VLANs 10 and 20.
# Assumes a prepared device without conflicting default bridge/DHCP/WiFi settings.
# Configure via console; replace the admin password before import.

# Na pierwszym AP:
/system identity set name=AP-PIETRO-02

/interface bridge
add name=bridge-cap protocol-mode=rstp vlan-filtering=no
/interface bridge port
add bridge=bridge-cap interface=ether1

# Uplink ether1 odbiera VLAN 99 bez tagu i tagowane VLAN-y WLAN 10/20
/interface wifi datapath
add bridge=bridge-cap name=dp-cap
/interface wifi
set [find default-name=wifi1] configuration.manager=capsman datapath=dp-cap disabled=no
set [find default-name=wifi2] configuration.manager=capsman datapath=dp-cap disabled=no
/interface wifi cap
set caps-man-addresses=192.168.99.1 discovery-interfaces=bridge-cap enabled=yes slaves-datapath=dp-cap

/ip address
add address=192.168.99.4/24 interface=bridge-cap
/ip route
add dst-address=0.0.0.0/0 gateway=192.168.99.1

# Management access hardening; reserve 192.168.99.10 for the admin workstation.
/user group add name=netadmin policy=ssh,read,write,policy,test,winbox,password
/user add name=operator1 group=netadmin address=192.168.99.10/32 password="ZASTAP_UNIKALNYM_HASLEM"
/user set [find where name="operator1"] inactivity-timeout=10m inactivity-policy=logout

# Najpierw otwórz drugą sesję i sprawdź login operator1.
# Dopiero po potwierdzeniu dostępu uruchom osobno:
# /user disable [find where name="admin"]

/ip service disable telnet,ftp,www,www-ssl,api,api-ssl
/ip service set [find where name="ssh"] available-from=192.168.99.10/32
/ip service set [find where name="winbox"] available-from=192.168.99.10/32
/ip ssh set strong-crypto=yes forwarding-enabled=no

/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
/tool mac-server ping set enabled=no
/ip neighbor discovery-settings set discover-interface-list=none
/tool bandwidth-server set enabled=no