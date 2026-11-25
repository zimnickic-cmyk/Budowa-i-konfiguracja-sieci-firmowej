# Projekt i wdrożenie sieci firmowej z segmentacją VLAN, infrastrukturą Wi-Fi (MikroTik) oraz usługą Active Directory

---

## 1\. Założenia i architektura projektu

Celem projektu jest zaprojektowanie, wdrożenie oraz przetestowanie bezpiecznej i skalowalnej infrastruktury sieciowej dla małego przedsiębiorstwa. Środowisko obejmuje:

* **10 stanowisk roboczych** (komputery stacjonarne z systemem Windows 11 Pro),  
* **2 punkty dostępowe Wi-Fi 6** (rozmieszczone na parterze i piętrze, zasilane przez PoE+),  
* **2 drukarki sieciowe** (wydzielone do osobnej podsieci),  
* **Serwerownię** opartą o szafę RACK wyposażoną w router brzegowy, zarządzalny przełącznik PoE, serwer główny z kontrolerem domeny Active Directory / DNS oraz serwer kopii zapasowych NAS.

### Kluczowe mechanizmy bezpieczeństwa i architektury:

1. **Segmentacja ruchu (IEEE 802.1Q VLAN):** rozdzielenie ruchu pracowników, gości, serwerów produkcyjnych, drukarek, dedykowanego ruchu kopii zapasowych (`VLAN 50`), interfejsów zarządzających (`VLAN 99`) oraz nieużywanych portów (`VLAN 999`).  
2. **Dedykowana sieć Backup (`VLAN 50`):** fizyczne i logiczne odseparowanie ruchu kopii zapasowych (Dell R730 ↔ QNAP) w warstwie L2 na przełączniku `CRS328`, bez dostępu ze stacji roboczych (ochrona przed atakami typu ransomware).  
3. **Hardening portów (`VLAN 999` – Parking):** przypisanie wszystkich wolnych portów przełącznika oraz wartości *Native VLAN (PVID)* na portach *Trunk* do odizolowanego `VLAN 999` bez routingu L3 oraz wyłączenie nieużywanych interfejsów fizycznych.  
4. **Łącze szkieletowe 10 Gbps (SFP+):** połączenie routera `RB4011iGS` ze switchem `CRS328-24P-4S+RM` w celu zapewnienia wysokiej przepustowości przy routingu między VLAN-ami (*Inter-VLAN Routing*).  
5. **Centralne zarządzanie siecią bezprzewodową (CAPsMAN):** kontroler Wi-Fi na routerze głównym zarządzający obydwoma punktami dostępowymi `cAP ax` wraz z obsługą szybkiego roamingu (802.11r/k/v).  
6. **Centralne uwierzytelnianie (Active Directory):** zarządzanie tożsamościami użytkowników, komputerami oraz politykami bezpieczeństwa (GPO) z poziomu serwera Windows Server.

---

## 2\. Podział na sieci VLAN i plan adresacji IP

Przyjęto prywatną adresację z klasy C (`192.168.X.0/24`), gdzie trzeci oktet adresu IP odpowiada identyfikatorowi VLAN-u.

| ID VLAN | Nazwa sieci | Podsieć / Maska | Brama domyślna | Zakres DHCP | Serwery DNS (DHCP) | Przeznaczenie i polityka dostępu |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| **VLAN 10** | `PRACOWNICY` | `192.168.10.0/24` | `192.168.10.1` | `.100 – .200` | `192.168.30.10` | Stacje robocze LAN (10x PC) oraz firmowe Wi-Fi |
| **VLAN 20** | `GOSCIE` | `192.168.20.0/24` | `192.168.20.1` | `.50 – .250` | `1.1.1.1`, `8.8.8.8` | Odizolowana sieć Wi-Fi dla gości (wyłącznie dostęp do Internetu) |
| **VLAN 30** | `SERWERY` | `192.168.30.0/24` | `192.168.30.1` | *Wyłączone* | `192.168.30.10` | Kontroler domeny AD/DNS oraz udziały sieciowe |
| **VLAN 40** | `DRUKARKI` | `192.168.40.0/24` | `192.168.40.1` | *Wyłączone* | `192.168.30.10` | Urządzenia drukujące i wielofunkcyjne |
| **VLAN 50** | `BACKUP` | `192.168.50.0/24` | *Brak (izolacja L2)* | *Wyłączone* | *Brak* | Dedykowana sieć kopii zapasowych (Dell NIC2 ↔ QNAP Port 1\) |
| **VLAN 99** | `MANAGEMENT` | `192.168.99.0/24` | `192.168.99.1` | *Wyłączone* | `192.168.30.10` | Interfejsy zarządzające urządzeń sieciowych, iDRAC i NAS |
| **VLAN 999** | `PARKING` | *Brak (Blackhole)* | *Brak* | *Wyłączone* | *Brak* | Nieużywane porty switcha oraz Native VLAN na portach Trunk |

---

## 3\. Wykaz osprzętu i przypisana adresacja IP

### 3.1. Infrastruktura sieciowa i serwerownia (RACK)

| Hostname | Urządzenie / Model | Rola w sieci | Lokalizacja | VLAN | Adres IP |
| :---- | :---- | :---- | :---- | :---- | :---- |
| `RTR-GW-01` | MikroTik `RB4011iGS` | Router brzegowy, Firewall, DHCP, CAPsMAN | Szafa RACK | `VLAN 99` | `192.168.99.1` *(+ bramy .1 w VLAN 10, 20, 30, 40\)* |
| `SW-CORE-01` | MikroTik `CRS328-24P-4S+RM` | Przełącznik dystrybucyjny L2/L3 PoE+ | Szafa RACK | `VLAN 99` | `192.168.99.2` |
| `AP-PARTER-01` | MikroTik `cAPGi-5HaxD2HaxD` (cAP ax) | Punkt dostępowy Wi-Fi 6 (PoE+) | Parter | `VLAN 99` | `192.168.99.3` *(rozgłasza VLAN 10 i 20\)* |
| `AP-PIETRO-02` | MikroTik `cAPGi-5HaxD2HaxD` (cAP ax) | Punkt dostępowy Wi-Fi 6 (PoE+) | Piętro | `VLAN 99` | `192.168.99.4` *(rozgłasza VLAN 10 i 20\)* |
| `SRV-DC-01` | Dell PowerEdge R730 *(NIC 1 – LAN)* | Serwer główny: AD DS, DNS, Pliki | Szafa RACK | `VLAN 30` | `192.168.30.10` |
| `SRV-DC-01-BCK` | Dell PowerEdge R730 *(NIC 2 – Backup)* | Dedykowany interfejs kopii zapasowych | Szafa RACK | `VLAN 50` | `192.168.50.10` *(maska /24, bez bramy)* |
| `SRV-DC-01-IDRAC` | Dell iDRAC *(interfejs OOB)* | Zdalne zarządzanie sprzętowe serwerem | Szafa RACK | `VLAN 99` | `192.168.99.5` |
| `NAS-BCK-01` | QNAP TS-464eU-8G *(Port 1 – Backup)* | Serwer kopii zapasowych (SMB/NFS/iSCSI) | Szafa RACK | `VLAN 50` | `192.168.50.20` *(maska /24, bez bramy)* |
| `NAS-BCK-01-MGMT` | QNAP TS-464eU-8G *(Port 2 – Mgmt)* | Panel administracyjny NAS | Szafa RACK | `VLAN 99` | `192.168.99.6` |

### 3.2. Stanowiska robocze i urządzenia peryferyjne

| Hostname | Urządzenie / Model | System operacyjny | Lokalizacja | VLAN | Adres IP |
| :---- | :---- | :---- | :---- | :---- | :---- |
| `DES9801` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9802` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9803` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9804` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9805` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9806` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9807` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9808` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9809` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `DES9810` | Lenovo ThinkCentre neo 50t | Windows 11 Pro | Biuro | `VLAN 10` | DHCP (`192.168.10.100–200`) |
| `LEX9150` | Lexmark MS521 | Sieciowa drukarka laserowa | Biuro | `VLAN 40` | `192.168.40.10` *(statyczny)* |
| `LEX9151` | Lexmark CX922de *(korekta nazwy)* | Sieciowe urządzenie wielofunkcyjne (MFP) | Biuro | `VLAN 40` | `192.168.40.11` *(statyczny)* |

---

## 4\. Mapowanie portów fizycznych

### 4.1. Router główny: MikroTik `RB4011iGS` (`RTR-GW-01`)

| Port | Tryb portu | PVID | Tagowane VLAN-y | Podłączone urządzenie | Uwagi |
| :---- | :---- | :---- | :---- | :---- | :---- |
| `ether1` | WAN | — | — | Modem / Router ISP | Wyjście na Internet (DHCP Client / Static IP \+ NAT) |
| `sfp-sfpplus1` | **Trunk** | `999` | `10, 20, 30, 40, 99` | `SW-CORE-01` (`sfp-sfpplus1`) | Główne łącze szkieletowe 10 Gbps (kabel DAC). Brak `VLAN 50` (ruch backupu izolowany na switchu) |
| `ether2 – ether9` | Access | `999` | — | *Nieużywane (Parking)* | Porty wyłączone administracyjnie (`disabled=yes`) |
| `ether10` | Access | `99` | — | Port awaryjny administratora | Lokalny dostęp serwisowy do zarządzania |

### 4.2. Przełącznik dystrybucyjny: MikroTik `CRS328-24P-4S+RM` (`SW-CORE-01`)

| Port(y) | Tryb portu | PVID | Tagowane VLAN-y | PoE | Podłączone urządzenie | Uwagi |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| `sfp-sfpplus1` | **Trunk** | `999` | `10, 20, 30, 40, 99` | Nie | `RTR-GW-01` (`sfp-sfpplus1`) | Uplink 10 Gbps do routera (`VLAN 999` jako Native) |
| `sfp-sfpplus2 – 4` | Access | `999` | — | Nie | *Nieużywane (Parking)* | Wyłączone administracyjnie (`disabled=yes`) |
| `ether1 – ether10` | Access | `10` | — | Wył. | `DES9801` – `DES9810` | 10 stanowisk stacjonarnych (`PRACOWNICY`) |
| `ether11 – ether12` | Access | `40` | — | Wył. | `LEX9150`, `LEX9151` | Drukarki sieciowe (`DRUKARKI`) |
| `ether13` | Access | `30` | — | Wył. | `SRV-DC-01` (NIC 1\) | Serwer Dell PowerEdge R730 – ruch produkcyjny AD/DNS |
| `ether14` | Access | `50` | — | Wył. | `SRV-DC-01-BCK` (NIC 2\) | Serwer Dell PowerEdge R730 – dedykowany ruch backupu |
| `ether15` | Access | `99` | — | Wył. | `SRV-DC-01-IDRAC` | Zdalne zarządzanie Dell iDRAC |
| `ether16` | Access | `50` | — | Wył. | `NAS-BCK-01` (Port 1\) | QNAP – dedykowany ruch kopii zapasowych (`BACKUP`) |
| `ether17` | Access | `99` | — | Wył. | `NAS-BCK-01-MGMT` (Port 2\) | QNAP – interfejs administracyjny (`MANAGEMENT`) |
| `ether18 – ether21` | Access | `999` | — | Wył. | *Nieużywane (Parking)* | Przypisane do `VLAN 999` i wyłączone (`disabled=yes`) |
| `ether22` | Access | `99` | — | Wył. | Port serwisowy | Awaryjne podłączenie laptopa administratora |
| `ether23` | **Trunk** | `99` | `10, 20` | **Auto-On (PoE+)** | `AP-PARTER-01` (`cAP ax`) | Zasilanie PoE+ \+ zarządzanie (PVID 99\) \+ Wi-Fi (10, 20\) |
| `ether24` | **Trunk** | `99` | `10, 20` | **Auto-On (PoE+)** | `AP-PIETRO-02` (`cAP ax`) | Zasilanie PoE+ \+ zarządzanie (PVID 99\) \+ Wi-Fi (10, 20\) |
