# ☁️ Déploiement d'une Infrastructure Cloud Hybride, Data & Automatisation CI/CD

> Projet de référence pour la certification **Microsoft Azure Administrator (AZ-104)**, enrichi des notions **AZ-700 / AZ-500 / AZ-800-801 / AZ-400**.
> Construction de A à Z d'une infrastructure **hybride** (On-Premise ↔ Azure), présentée comme un **tutoriel pas-à-pas reproductible** : chaque action est illustrée et expliquée pour qu'un débutant puisse **refaire l'ensemble**.

![Azure](https://img.shields.io/badge/Cloud-Microsoft%20Azure-0078D4)
![Region](https://img.shields.io/badge/R%C3%A9gion-Germany%20West%20Central-informational)
![Hybrid](https://img.shields.io/badge/Topologie-Hub--Spoke%20Hybride-16A085)
![IaC](https://img.shields.io/badge/IaC-Bicep%20%7C%20Azure%20CLI-8E44AD)

---

## 📑 Sommaire

- [Contexte & objectifs](#-contexte--objectifs)
- [Architecture cible](#️-architecture-cible)
- [Plan d'adressage IP](#-plan-dadressage-ip)
- [Conventions](#-conventions)
- **Tutoriel pas-à-pas :**
  - [Étape 01 — Prérequis & outillage](#-étape-01--prérequis--outillage)
  - [Étape 02 — Machine virtuelle & Windows Server](#-étape-02--machine-virtuelle--windows-server)
  - [Étape 03 — Contrôleur de domaine (AD DS · DNS · DHCP)](#-étape-03--contrôleur-de-domaine-ad-ds--dns--dhcp)
  - [Étape 04 — Réseau Azure Hub-Spoke](#-étape-04--réseau-azure-hub-spoke)
  - [Étape 05 — Fondations partagées](#-étape-05--fondations-partagées)
  - [Étape 06 — Azure File Sync](#-étape-06--hybridation-des-fichiers-azure-file-sync)
  - [Étape 07 — Annuaire AD](#-étape-07--structuration-de-lannuaire-ad)
  - [Étape 08 — Identité hybride (Entra Connect)](#-étape-08--identité-hybride-entra-connect-cloud-sync)
  - [Étape 09 — Site web (Static Web Apps)](#-étape-09--premier-site-web-azure-static-web-apps)
  - [Étape 10 — Compute IaaS (Azure VM)](#-étape-10--compute-iaas-machine-virtuelle-ubuntu)
  - [Étape 11 — Conteneurs (ACR → ACI → ACA)](#-étape-11--conteneurs-acr--aci--aca)
  - [Étape 12 — Migration On-Premise → Azure (Azure Migrate)](#-étape-12--migration-on-premise--azure-azure-migrate)
  - [Étape 13 — CI/CD DevSecOps (GitHub Actions)](#-étape-13--cicd-devsecops-github-actions)
  - [Étape 14 — Gestion du stockage (Storage Explorer)](#️-étape-14--gestion-du-stockage-azure-storage-explorer)
  - [Étape 15 — Supervision & SIEM (Sentinel + KQL)](#️-étape-15--supervision--siem-microsoft-sentinel--kql)
  - [Étape 16 — Sauvegarde (Recovery Services Vault)](#-étape-16--sauvegarde-recovery-services-vault)
- [Journal de troubleshooting](#️-journal-de-troubleshooting-err--fix)
- [Roadmap](#️-roadmap)
- [Stack technique](#-stack-technique)

---

## 🎯 Contexte & objectifs

Simulation de l'infrastructure d'une PME fictive, **4SKY Group**, adoptant une architecture **cloud hybride** tout en conservant un datacenter local. Chaque décision technique (région, topologie, protocole, tier…) est **justifiée**, et chaque manipulation est **illustrée** pour être reproductible.

---

## 🏗️ Architecture cible

**Vue globale de l'infrastructure hybride :**

![Architecture cible](Screenshots/Architecture-01-Cible-Hybride.png)

**Chaîne DevSecOps (CI/CD sécurisé) :**

![Architecture DevSecOps](Screenshots/Architecture-02-DevSecOps.png)

> Sources éditables : `Architecture_Cible.drawio` et `Architecture_DevSecOps.drawio` ([draw.io](https://app.diagrams.net)).

---

## 🌐 Plan d'adressage IP

| Réseau | CIDR | Rôle |
|---|---|---|
| LAN On-Premise (VMware) | `192.168.10.0/24` | Serveur `.10`, passerelle NAT `.2`, DHCP `.50`–`.200` |
| **Hub VNet** | `10.0.0.0/16` | GatewaySubnet `/27`, AzureFirewallSubnet `/26`, AzureBastionSubnet `/26` |
| **Spoke VNet** | `10.1.0.0/16` | snet-appgw `.1.0/24`, appsvc `.2.0/24`, vm `.3.0/24`, aca `.4.0/23`, aci `.6.0/24`, data `.7.0/24`, pep `.8.0/24` |

---

## 📏 Conventions

**Domaine AD** : `4skygroup.local` (`4SKYGROUP`) · **Région** : `Germany West Central`
**Nommage** : `rg-4sky-*`, `vnet-4sky-*`, `snet-*`, `nsg-snet-*`, `st4sky*`, `kv-4sky-*`
**Tags obligatoires** (via Azure Policy) : `project=4sky-hybrid-lab` · `env=lab` · `owner=daryl` · `costCenter=IT`
**Captures** : `EtapeXX-Tache.png` · erreurs `EtapeXX-ERR_*.png` · corrections `EtapeXX-FIX_*.png`

---
---

# 📘 Tutoriel pas-à-pas

---

## 🧰 Étape 01 — Prérequis & outillage

**But :** préparer les comptes, les outils et le poste de virtualisation avant tout déploiement.
**Choix justifiés :** VMware Workstation Pro (pro, gratuit perso) plutôt que VirtualBox ; Azure CLI + Bicep (reproductibilité/IaC) plutôt que le portail seul ; alerte de budget créée **en premier** pour protéger le crédit.

### 1. Installer la chaîne d'outils
Dans **PowerShell** :
```powershell
winget install Microsoft.AzureCLI      # Azure CLI
winget install OpenJS.NodeJS.LTS        # Node.js
winget install Docker.DockerDesktop     # Docker
winget install Git.Git                  # Git
```
Puis **rouvrir le terminal** et vérifier les versions :
```powershell
git --version ; node --version ; docker --version
```
![Vérification des outils](Screenshots/Etape01-OutilsVersions.png)
> ✅ *Git, Node et Docker répondent : la base est installée. (Le « docker non reconnu » au 1ᵉʳ essai est normal — voir Étape 06 du troubleshooting : il faut rouvrir le terminal.)*

### 2. Installer Bicep et vérifier Azure CLI
```powershell
az bicep install
az version ; az bicep version
```
![Azure CLI et Bicep](Screenshots/Etape01-AzCliVersion.png)
> ✅ *Azure CLI 2.87 et Bicep sont opérationnels. Bicep est intégré à la CLI (`az bicep`), il n'existe pas en commande autonome.*

### 3. Se connecter à Azure
```powershell
az login
az account show --output table
```
![Connexion Azure](Screenshots/Etape01-AzLogin.png)
> ✅ *Connexion réussie et abonnement actif affiché. Si tu obtiens une erreur MFA `AADSTS50076`, utilise `az login --tenant <id>` (voir troubleshooting).*

### 4. Tester Docker
```powershell
docker run hello-world
```
![Docker Hello World](Screenshots/Etape01-DockerHelloWorld.png)
> ✅ *« Hello from Docker! » confirme que le moteur tourne.*

### 5. Installer VMware Workstation Pro
Télécharger **gratuitement** depuis le portail **Broadcom** (section *Free Software Downloads*), version **Windows 26H1**, puis installer (options par défaut, licence « Personal Use »).
![VMware installé](Screenshots/Etape01-VMwareInstalle.png)
> ✅ *VMware Workstation Pro installé — il jouera le rôle d'hyperviseur du datacenter On-Premise.*

### 6. Récupérer l'ISO Windows Server 2025
Depuis le **Centre Éducation Azure** (ou l'Evaluation Center) → **Windows Server 2025 Standard — Français — 64 bits**.
![ISO Windows Server](Screenshots/Etape01-ISO_WindowsServer.png)
> ✅ *ISO téléchargée. On y ajoutera la clé de produit à l'installation.*

---

## 🖥️ Étape 02 — Machine virtuelle & Windows Server

**But :** créer la VM `SRV-DC01` (le datacenter local).
**Choix justifiés :** réseau **NAT** (et non *bridged*) pour **isoler** le futur DHCP du réseau maison et garder un adressage stable ; édition **Desktop Experience** (interface graphique) pour l'apprentissage ; « installer l'OS plus tard » pour **maîtriser chaque écran**.

### 1. Configurer le matériel de la VM
Dans VMware : **New Virtual Machine → Typical → I will install the OS later**. Réglages : **4 vCPU · 8 Go RAM · 80 Go · UEFI · carte réseau NAT**, et monter l'ISO Windows Server dans le lecteur CD/DVD.
![Configuration matérielle de la VM](Screenshots/Etape02-ConfigMaterielleVM.png)
> ✅ *La VM est dimensionnée et prête à démarrer sur l'ISO.*

### 2. Installer Windows Server et se connecter
Démarrer la VM → installer **Windows Server 2025 Standard (Expérience de bureau)** → définir le mot de passe Administrateur → installer **VMware Tools**.
![Serveur opérationnel](Screenshots/Etape02-ServeurPret.png)
> ✅ *Bureau de Windows Server 2025 + Gestionnaire de serveur : l'OS est installé et fonctionnel.*

---

## 🧭 Étape 03 — Contrôleur de domaine (AD DS · DNS · DHCP)

**But :** faire de `SRV-DC01` le cœur d'identité de l'entreprise.
**Choix justifiés :** **IP statique** (un DC doit être joignable à une adresse fixe) ; **DNS pointant vers lui-même** (AD repose sur le DNS) ; **redirecteurs DNS** pour résoudre Internet ; **autorisation DHCP dans AD** (sécurité anti-DHCP pirate).

### 1. Aligner le réseau NAT sur 192.168.10.0/24
Dans VMware : **Éditeur de réseau virtuel → VMnet8 (NAT)** → sous-réseau `192.168.10.0/24`, passerelle `192.168.10.2`.
![Réseau NAT](Screenshots/Etape03-ReseauNAT.png)
> ✅ *Le réseau virtuel correspond désormais à notre plan d'adressage.*

### 2. Attribuer une IP statique au serveur
Dans la VM : `ncpa.cpl` → Ethernet0 → IPv4 : IP `192.168.10.10`, masque `255.255.255.0`, passerelle `192.168.10.2`, **DNS préféré = 192.168.10.10** (lui-même).
![IP statique](Screenshots/Etape03-IPStatique.png)
> ✅ *Le serveur a une adresse fixe et se pointe vers son propre DNS (prérequis d'un DC).*

### 3. Renommer le serveur
**Gestionnaire de serveur → Serveur local → Nom d'ordinateur → `SRV-DC01`** → redémarrer.
![Renommage](Screenshots/Etape03-RenommagePC.png)
> ✅ *Nom clair et cohérent avant la promotion en DC.*

### 4. Installer le rôle AD DS
**Gérer → Ajouter des rôles → Services AD DS**.
![Rôle AD DS](Screenshots/Etape03-AjoutRoleADDS.png)
> ✅ *Le rôle Active Directory Domain Services est installé.*

### 5. Promouvoir en nouvelle forêt
Bannière ⚠️ → **Promouvoir ce serveur en contrôleur de domaine → Ajouter une nouvelle forêt** → nom `4skygroup.local`.
![Nouvelle forêt](Screenshots/Etape03-NouvelleForet.png)
> ✅ *Création de la forêt `4skygroup.local` (NetBIOS `4SKYGROUP`).*

### 6. Définir le mot de passe DSRM
Niveaux fonctionnels **Windows Server 2025**, **Serveur DNS** coché, mot de passe **DSRM** (mode restauration) à conserver.
![Mot de passe DSRM](Screenshots/Etape03-MotDePasseDSRM.png)
> ✅ *Le DSRM sert à réparer l'annuaire en cas de sinistre — à ne pas perdre.*

### 7. Lancer la promotion
Vérification des prérequis → **Installer** (le serveur redémarre automatiquement).
![Installation de la promotion](Screenshots/Etape03-PromotionInstall.png)
> ✅ *La configuration s'installe ; les avertissements affichés sont normaux.*

### 8. Se connecter au domaine
Après reboot, connexion en **`4SKYGROUP\Administrateur`**.
![Connexion au domaine](Screenshots/Etape03-ConnexionDomaine.png)
> ✅ *Ton compte est devenu un compte **de domaine** : AD DS est actif (`DomainMode = Windows2025Domain`).*

### 9. ⚠️ Incident : plus d'accès Internet
En pointant le DNS vers lui-même, le serveur ne résout plus les noms externes.
![ERR — plus d'Internet](Screenshots/Etape03-ERR_PasInternet.png)
> ❌ *Symptôme normal : le DNS local ne connaît que `4skygroup.local`, pas `google.com`.*

### 10. FIX : ajouter des redirecteurs DNS
```powershell
Set-DnsServerForwarder -IPAddress 8.8.8.8, 1.1.1.1
```
![Redirecteurs DNS](Screenshots/Etape03-RedirecteursDNS.png)
> 🔧 *On dit au DNS : « si tu ne connais pas un nom, demande à un annuaire public ».*

### 11. FIX confirmé : Internet rétabli
```powershell
Resolve-DnsName www.google.com
```
![FIX — Internet rétabli](Screenshots/Etape03-FIX_Internet.png)
> ✅ *La résolution externe refonctionne, proprement, via notre propre DNS.*

### 12. ⚠️ Incident : erreurs dcdiag après promotion
```powershell
dcdiag /q
```
![ERR — dcdiag](Screenshots/Etape03-ERR_dcdiag.png)
> ❌ *Erreurs transitoires d'un DC tout neuf (SYSVOL/DNS) + Secure Boot cosmétique.*

### 13. FIX : forcer l'enregistrement et vérifier les partages
```powershell
ipconfig /registerdns ; nltest /dsregdns ; Restart-Service Netlogon
net share
```
![Vérification des partages](Screenshots/Etape03-VerifPartages.png)
> 🔧 *Les partages `SYSVOL` et `NETLOGON` sont présents → l'annuaire est fonctionnel.*

### 14. Installer le rôle DHCP
**Gérer → Ajouter des rôles → Serveur DHCP**.
![Rôle DHCP](Screenshots/Etape03-AjoutRoleDHCP.png)
> ✅ *Le rôle DHCP est ajouté (la « réceptionniste » qui distribue les adresses).*

### 15. Autoriser le DHCP dans Active Directory
Bannière ⚠️ → **Terminer la configuration DHCP**.
![Autorisation DHCP](Screenshots/Etape03-AutorisationDHCP.png)
> ✅ *Étape obligatoire : un DHCP non autorisé refuse de distribuer des adresses.*

### 16. Créer l'étendue d'adresses
**Outils → DHCP → IPv4 → Nouvelle étendue** : `LAN-OnPrem`, plage `192.168.10.50`–`.200`, passerelle `192.168.10.2`, DNS `192.168.10.10`.
![Étendue DHCP](Screenshots/Etape03-EtendueDHCP.png)
> ✅ *Plage `.50`–`.200` (on réserve les basses/hautes adresses pour l'infra).*

### 17. Vérifier le DHCP
```powershell
Get-DhcpServerInDC ; Get-DhcpServerv4Scope
```
![Vérification DHCP](Screenshots/Etape03-VerifDHCP.png)
> ✅ *Serveur **autorisé** et étendue `LAN-OnPrem` **active** → On-Premise complet (AD DS + DNS + DHCP).*

---

## 🌐 Étape 04 — Réseau Azure Hub-Spoke

**But :** bâtir le réseau cloud, gouverné et segmenté.
**Choix justifiés :** **Hub-Spoke** (standard entreprise, aligné AZ-700) ; **Germany West Central** (région mature, dispo SKU, UE/RGPD — après le blocage de West Europe et le souci SKU de France Central) ; **Azure Policy** pour imposer région et tags ; **un NSG par subnet** (moindre privilège).

### 1. Vérifier le contexte Azure
```powershell
az account show --output table
```
![Contexte Azure](Screenshots/Etape04-Contexte%20Azure.png)
> ✅ *On confirme le bon abonnement avant de créer des ressources.*

### 2. Créer le Resource Group réseau (avec tags)
Portail → **Groupes de ressources → Créer** : `rg-4sky-network`, région **Germany West Central**, 4 tags.
![RG réseau](Screenshots/Etape04-RGReseau.png)
> ✅ *Conteneur logique du réseau, correctement étiqueté.*

### 3. Appliquer les Azure Policy
**Policy → Assignments** : `Allowed locations` = Germany West Central, et `Require a tag on resources` = `project`.
![Azure Policy](Screenshots/Etape04-Policies.png)
> ✅ *Gouvernance active : impossible de déployer hors région, ni sans le tag `project`.*

### 4. Créer le Hub VNet
**Réseaux virtuels → Créer** : `vnet-4sky-hub` `10.0.0.0/16` + `GatewaySubnet`, `AzureFirewallSubnet`, `AzureBastionSubnet` (noms imposés par Azure).
![Hub VNet](Screenshots/Etape04-HubVNet.png)
> ✅ *Le Hub héberge les services centraux (VPN, pare-feu, Bastion).*

### 5. Créer le Spoke VNet
`vnet-4sky-spoke` `10.1.0.0/16` + subnets applicatifs (`snet-appgw`, `snet-vm`, `snet-aca`…).
![Spoke VNet](Screenshots/Etape04-SpokeVNet.png)
> ✅ *Le Spoke accueille les charges applicatives.*

### 6. Appairer Hub et Spoke (peering)
**Hub → Appairages → Ajouter** (crée les deux sens).
![Peering](Screenshots/Etape04-Peering.png)
> ✅ *Une « route privée » relie les deux VNets sans passer par Internet.*

### 7. Vérifier le peering
![Vérification du peering](Screenshots/Etape04-VerifPeering.png)
> ✅ *État « Connecté » des deux côtés.*

### 8. Créer un NSG avec une règle (subnet VM)
`nsg-snet-vm` + règle **Allow-RDP-from-OnPrem** (source `192.168.10.0/24`, port 3389), associée à `snet-vm`.
![NSG VM](Screenshots/Etape04-NSG-vm.png)
> ✅ *Seul le LAN On-Prem peut faire du RDP — pas Internet.*

### 9. Automatiser les autres NSG (script Bash)
Script [`create-nsg-spoke.sh`](create-nsg-spoke.sh) → crée et associe `nsg-snet-aci/data/pep`.
![NSG via script](Screenshots/Etape04-NSG-script.png)
> ✅ *Première brique d'Infrastructure as Code (boucle + tags + association).*

### 10. Vérifier les NSG
![Vérification des NSG](Screenshots/Etape04-VerifNSG.png)
> ✅ *Chaque subnet est protégé par son NSG → réseau segmenté et gouverné.*

---

## 🧱 Étape 05 — Fondations partagées

**But :** poser les services de plateforme (sécurité, monitoring, stockage).
**Choix justifiés :** RG partagé dédié (cycles de vie séparés) ; Key Vault en **RBAC** (moderne) ; Storage en **StorageV2** (gère Blob **et** Files, requis pour File Sync) ; redondance **LRS** (économique).

### 1. Créer le RG partagé
`rg-4sky-shared`, Germany West Central, 4 tags.
![RG partagé](Screenshots/Etape05-RGShared.png)
> ✅ *Conteneur des services communs.*

### 2. Log Analytics
`law-4sky` — collecte centralisée des journaux/métriques.
![Log Analytics](Screenshots/Etape05-LogAnalytics.png)
> ✅ *La « tour de contrôle » du monitoring.*

### 3. Key Vault (modèle RBAC)
`kv-4sky-daryl01` — coffre-fort des secrets et certificats.
![Key Vault](Screenshots/Etape05-KeyVault.png)
> ✅ *Modèle RBAC choisi (plus granulaire que les access policies).*

### 4. Storage Account (StorageV2, LRS)
`st4skyshared01` — Blob + Files.
![Storage](Screenshots/Etape05-Storage.png)
> ✅ *StorageV2 confirmé : « Partages de fichiers » disponible → prêt pour Azure File Sync.*

---

## 🔄 Étape 06 — Hybridation des fichiers (Azure File Sync)

**But :** synchroniser un dossier du serveur local avec le cloud, en bidirectionnel.
**Choix justifiés :** File Sync (synchro continue + cloud tiering) plutôt qu'une copie ; **fonctionne en HTTPS → aucun VPN requis**.

### 1. Créer le partage Azure Files
`st4skyshared01 → Partages de fichiers → partage-4sky`.
![Partage Azure Files](Screenshots/Etape06-FileShare.png)
> ✅ *Le « côté cloud » du dossier partagé.*

### 2. Créer le Storage Sync Service
Recherche **Azure File Sync → Créer** : `sss-4sky`.
![Storage Sync Service](Screenshots/Etape06-StorageSyncService.png)
> ✅ *Le service qui orchestre la synchronisation.*

### 3. Créer le groupe de synchronisation
`sss-4sky → Groupes de synchronisation → sg-partage-4sky` (relié au partage).
![Groupe de synchronisation](Screenshots/Etape06-SyncGroup.png)
> ✅ *Le « cloud endpoint » (ancre côté Azure) est défini.*

### 4. Préparer le dossier local (serveur)
```powershell
New-Item -Path "C:\Partages\Entreprise" -ItemType Directory -Force
Install-WindowsFeature FS-FileServer -IncludeManagementTools
New-SmbShare -Name "Entreprise" -Path "C:\Partages\Entreprise" -FullAccess "4SKYGROUP\Administrateur"
```
![Dossier local](Screenshots/Etape06-DossierPartage.png)
> ✅ *Le dossier `C:\Partages\Entreprise` sera synchronisé.*

### 5. Installer l'agent Azure File Sync
Télécharger `StorageSyncAgent_WS2025.msi` (Microsoft Download Center) et l'installer.
![Agent installé](Screenshots/Etape06-AgentInstalle.png)
> ✅ *Le « robot de synchro » est en place sur le serveur.*

### 6. Enregistrer le serveur
À la fin de l'install, **Server Registration** → connexion Azure + choix de `sss-4sky`.
![Enregistrement du serveur](Screenshots/Etape06-EnregistrementServeur.png)
> ✅ *Le serveur est lié au service de synchronisation.*

### 7. Créer le server endpoint
`sg-partage-4sky → Ajouter un point de terminaison de serveur` : `SRV-DC01`, chemin `C:\Partages\Entreprise`.
![Server endpoint](Screenshots/Etape06-ServerEndpoint.png)
> ✅ *On déclare : « ce dossier local = copie du partage cloud ».*

### 8. Tester la synchronisation (serveur → cloud)
Créer un fichier dans `C:\Partages\Entreprise`, forcer si besoin `Restart-Service FileSyncSvc`, puis vérifier dans le partage Azure.
![Test de synchronisation](Screenshots/Etape06-Sync-OnPrem-vers-Azure.png)
> ✅ *Le fichier créé en local **remonte dans Azure** → 1er flux hybride réel validé.*

---

## 👥 Étape 07 — Structuration de l'annuaire AD

**But :** peupler l'AD avant la synchro hybride.
**Choix justifiés :** OU pour ranger/déléguer/cibler les GPO ; groupes de sécurité pour gérer les accès **par rôle** ; création **par script** (reproductible).

### 1. Créer OU, groupes et utilisateurs
```powershell
Import-Module ActiveDirectory
$base = "DC=4skygroup,DC=local"
New-ADOrganizationalUnit -Name "4SKY" -Path $base
$ou = "OU=4SKY,$base"
"Utilisateurs","Groupes","Serveurs","Postes" | % { New-ADOrganizationalUnit -Name $_ -Path $ou }
"GG_IT","GG_RH","GG_Marketing" | % { New-ADGroup -Name $_ -GroupScope Global -Path "OU=Groupes,$ou" }
$pwd = ConvertTo-SecureString "P@ssw0rd2026!" -AsPlainText -Force
New-ADUser -Name "Daryl Ngassa" -SamAccountName "d.ngassa" -UserPrincipalName "d.ngassa@4skygroup.local" -Path "OU=Utilisateurs,$ou" -AccountPassword $pwd -Enabled $true
New-ADUser -Name "Thierno Ibrahima" -SamAccountName "t.ibrahima" -UserPrincipalName "t.ibrahima@4skygroup.local" -Path "OU=Utilisateurs,$ou" -AccountPassword $pwd -Enabled $true
```
![Structure AD](Screenshots/Etape07-StructureAD.png)
> ✅ *OU, groupes et utilisateurs de test créés → l'annuaire a du contenu à synchroniser.*

---

## 🔐 Étape 08 — Identité hybride (Entra Connect Cloud Sync)

**But :** synchroniser l'AD local vers Microsoft Entra ID.
**Choix justifiés :** **Cloud Sync** (agent léger, cloud-managé, recommandé pour forêt unique) plutôt que Connect Sync ; **PHS** (même mot de passe local/cloud) ; **suffixe UPN routable** (obligatoire, `.local` ne l'est pas) ; **filtrage sur l'OU 4SKY**.

### 1. Ajouter un suffixe UPN routable et mettre à jour les UPN
Ajouter le suffixe `...onmicrosoft.com` (Domaines et approbations AD, nœud racine), puis :
```powershell
$suffix = "armelngassa730gmail.onmicrosoft.com"
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,OU=4SKY,DC=4skygroup,DC=local" |
  ForEach-Object { Set-ADUser $_ -UserPrincipalName ("$($_.SamAccountName)@$suffix") }
```
![Suffixe UPN](Screenshots/Etape08-SuffixeUPN.png)
> ✅ *Les UPN deviennent routables → synchronisables vers Entra ID.*

### 2. Installer l'agent d'approvisionnement Cloud Sync
Depuis **entra.microsoft.com → Microsoft Entra Connect → Cloud Sync**, télécharger l'agent, l'installer, créer le **gMSA** (compte `4SKYGROUP\Administrateur`) et connecter la forêt `4skygroup.local`.
![Agent Cloud Sync](Screenshots/Etape08-AgentCloudSyncOK.png)
> ✅ *Agent installé et forêt connectée (statut « active »).*

### 3. Créer la configuration de synchronisation
**Nouvelle configuration → Synchronisation d'AD sur Microsoft Entra ID** → domaine `4skygroup.local`, **PHS activé**.
![Configuration Cloud Sync](Screenshots/Etape08-ConfigCloudSync.png)
> ✅ *Sens AD → Entra ID, avec synchronisation des mots de passe.*

### 4. Cibler l'OU 4SKY (filtre d'étendue)
**Filtres d'étendue** → OU `OU=4SKY,DC=4skygroup,DC=local`.
![Filtre OU](Screenshots/Etape08-FiltreOU.png)
> ✅ *Seuls les objets de l'OU 4SKY remontent (pas les comptes système).*

### 5. Activer la configuration
**Vérifier et activer**.
![Configuration activée](Screenshots/Etape08-ConfigActivee.png)
> ✅ *La synchronisation démarre — **USER 2 / GROUP 3** provisionnés.*

### 6. Vérifier dans Entra ID
**Entra ID → Utilisateurs**.
![Vérification Entra ID](Screenshots/Etape08-VerifSyncEntra.png)
> ✅ *Les utilisateurs apparaissent dans le cloud.*

![Utilisateurs synchronisés](Screenshots/Etape08-VerifSyncEntra02.png)
> ✅ *`d.ngassa` et `t.ibrahima` avec UPN `...onmicrosoft.com`.*

![Détail de synchronisation](Screenshots/Etape08-VerifSyncEntra03.png)
> ✅ *« Synchronisation locale : Oui » → identité hybride opérationnelle.*

---

## 🌐 Étape 09 — Premier site web (Azure Static Web Apps)

**But :** déployer un site statique sur Azure, gratuitement.
**Choix justifiés :** après inspection, les sites compilent tous en **statique** (Vite `dist/`, Next.js `output: 'export'`) → **Static Web Apps** (tier **gratuit**, CDN global, HTTPS inclus) est le bon service. Déploiement via **jeton** (méthode « Other »), donc **sans modifier le dépôt de production**.

### 1. Resource Group compute + build local
```powershell
cd cybersky ; npm install ; npm run build   # produit dist/
```
| RG compute | Build local |
|---|---|
| ![RG compute](Screenshots/Etape09-RGCompute.png) | ![Build](Screenshots/Etape09-BuildLocal.png) |

### 2. Créer la Static Web App (bataille de gouvernance & région)
Trois obstacles enchaînés, résolus l'un après l'autre :

| ❌ Policy bloque la région | 🔧 Élargir la policy | ❌ West Europe saturée | 🔧 West US 2 |
|---|---|---|---|
| ![ERR policy](Screenshots/Etape09-ERR_PolicyLocation.png) | ![FIX policy](Screenshots/Etape09-FIX_PolicyRegionSWA.png) | ![ERR WE](Screenshots/Etape09-ERR_WestEuropeBloquee.png) | ![FIX WUS2](Screenshots/Etape09-FIX_RegionWestUS2.png) |

> 💡 **Static Web Apps n'existe pas en Germany West Central** → conflit avec la policy « région autorisée ». Comme SWA est un **service global à CDN**, la région de rattachement n'a aucun impact sur la latence → on autorise **West US 2**.

### 3. Déployer le contenu via jeton
```powershell
npm install -g @azure/static-web-apps-cli
swa deploy ./dist --deployment-token "<JETON>" --env production
```
| Jeton de déploiement | Déploiement | Site en ligne |
|---|---|---|
| ![Jeton](Screenshots/Etape09-JetonDeploiement.png) | ![Deploy](Screenshots/Etape09-Deploiement.png) | ![Site](Screenshots/Etape09-SiteEnLigne.png) |
> ✅ *Site `cybersky` en ligne sur `*.azurestaticapps.net`, en HTTPS, gratuit.*

---

## 🖥️ Étape 10 — Compute IaaS (machine virtuelle Ubuntu)

**But :** héberger un **vrai site** sur une VM (modèle IaaS).
**Choix justifiés :** **Ubuntu** plutôt que Windows (moins cher — pas de licence, natif Node) ; VM dans le **spoke** protégée par NSG ; **nginx** pour servir le site ; **suppression après test** (facturé tant qu'elle tourne).

### 1. Créer la VM + accès SSH
| Création VM | Règle NSG (SSH) | Connexion SSH |
|---|---|---|
| ![VM](Screenshots/Etape10-CreationVM.png) | ![NSG SSH](Screenshots/Etape10-InboundNsgVMssh.png) | ![SSH](Screenshots/Etape10-ConnexionSSH.png) |

### 2. Installer nginx et déployer le site (build local → scp)
```bash
sudo apt install -y nginx
# (sur la machine) scp -r ./dist azureuser@<IP>:~/site
sudo cp -r ~/site/* /var/www/html/ ; sudo systemctl reload nginx
```
| nginx | Build play-to-sky | Transfert scp | Déploiement |
|---|---|---|---|
| ![nginx](Screenshots/Etape10-InstallNginx.png) | ![build](Screenshots/Etape10-BuildPlayToSky.png) | ![scp](Screenshots/Etape10-TransfertScp.png) | ![deploy](Screenshots/Etape10-DeploiementNginx.png) |

### 3. Ouvrir le port 80 et tester
| Règle NSG (HTTP) | ❌ Site inaccessible | ✅ Le vrai site sur la VM |
|---|---|---|
| ![NSG HTTP](Screenshots/Etape10-NSG-HTTP.png) | ![ERR](Screenshots/Etape10-ERR_SiteInaccessible.png) | ![Site VM](Screenshots/Etape10-SiteReelSurVM.png) |
> 💡 Timeout dû au **filtrage NSG sur une IP résidentielle dynamique** + au **port dans l'URL** — bon rappel : le port doit correspondre entre l'app, la ressource et l'URL.
>
> 🧹 **Après captures : suppression complète** de la VM (+ disque, NIC, IP publique) pour stopper la facturation.

---

## 🐳 Étape 11 — Conteneurs (ACR → ACI → ACA)

**But :** parcourir toute la chaîne conteneur avec une app dédiée, **`leads-hub`** (Node/Express).
**Choix justifiés :** **ACR** = registre privé ; **ACI** = conteneur unique dev/test (HTTP) ; **ACA** = production (ingress **HTTPS**, autoscale, *scale-to-zero*). Une 6ᵉ app créée exprès pour ne pas toucher aux 5 vrais sites.

### 1. Enregistrer les providers + créer l'ACR
| Providers | ACR (Basic) |
|---|---|
| ![Providers](Screenshots/Etape11-Providers.png) | ![ACR](Screenshots/Etape11-ACR.png) |

### 2. Construire l'image (ACR Tasks bloqué → build local)
| ❌ ACR Tasks interdits | 🔧 Build local Docker + push |
|---|---|
| ![ERR ACR Tasks](Screenshots/Etape11-ERR_ACRTasks.png) | ![FIX Docker](Screenshots/Etape11-FIX_DockerBuildPush.png) |
> 💡 Les **ACR Tasks** (build cloud) sont **bloqués sur les abonnements gratuits/étudiants** → on **build en local avec Docker** puis on `push`.

### 3. Déployer en ACI puis en ACA
| ACI (création) | ACI en ligne (HTTP:3000) | ACA (création) | ACA en ligne (HTTPS) |
|---|---|---|---|
| ![ACI](Screenshots/Etape11-ACI-Creation.png) | ![ACI live](Screenshots/Etape11-ACI-EnLigne.png) | ![ACA](Screenshots/Etape11-ACA-Creation.png) | ![ACA live](Screenshots/Etape11-ACA-EnLigne.png) |
> 💡 **ACI** = HTTP, port `:3000` dans l'URL. **ACA** = **HTTPS automatique** via ingress (aucun port dans l'URL). Illustration parfaite du passage dev/test → production.

---

## 🚚 Étape 12 — Migration On-Premise → Azure (Azure Migrate)

**But :** découvrir et évaluer une charge de travail locale en vue de sa migration vers Azure, avec **Azure Migrate**.
**Choix justifiés :** hôte **Hyper-V natif** (Windows Education) plutôt que virtualisation imbriquée VMware (fragile) ; on déploie un **vrai site** (`drox360`) pour une démo réaliste, en **copiant uniquement** le `dist/` (le dépôt de production n'est jamais modifié) ; **appliance Azure Migrate** pour une découverte continue ; évaluation **« Localement »** pour un résultat immédiat (les compteurs de perf ne sont pas encore collectés).

> ⚠️ **Portée de cette étape.** Ce bloc couvre **découverte + évaluation** — le cœur pédagogique d'Azure Migrate. L'**exécution de la migration** (réplication + bascule) est **reportée à un projet dédié** : elle bute sur une limite d'infrastructure documentée plus bas (Hyper-V **client** non supporté pour la migration sans agent).

### 1. Activer Hyper-V sur l'hôte + commutateur virtuel
Hôte en **Windows Education** → rôle Hyper-V activé, puis création d'un commutateur (externe sur la carte, puis **Commutateur par défaut / vSwitch-Externe** pour la fiabilité).
| Gestionnaire Hyper-V | Commutateur virtuel |
|---|---|
| ![Hyper-V hôte](Screenshots/Etape12-01-GestionnaireHyperV-Hote.png) | ![Commutateur](Screenshots/Etape12-02-CommutateurVirtuel-Externe.png) |
> ✅ *Plateforme de virtualisation locale opérationnelle — elle jouera le rôle de datacenter source pour la migration.*

### 2. Créer la VM de charge + déployer un vrai site (drox360)
VM **Ubuntu Server 24.04** (Génération 2, Secure Boot = *UEFI CA*), puis **Nginx** et déploiement du `dist/` de **drox360** (build Vite copié via `scp`, **sans toucher au dépôt**).
| Ubuntu installé | drox360 servi On-Prem |
|---|---|
| ![Ubuntu](Screenshots/Etape12-05-Ubuntu-Installe.png) | ![drox360 on-prem](Screenshots/Etape12-11-Drox360-OnPrem.png) |
> ✅ *Un vrai site de production tourne sur la VM locale (`192.168.1.23`) → charge de travail crédible à migrer.*

### 3. Créer le projet Azure Migrate + déployer l'appliance Hyper-V
Projet `migrate-4sky` (RG `rg-4sky-migrate`), puis import du **VHD de l'appliance** dans Hyper-V, enregistrement via **clé de projet** + connexion Azure.
| Projet Azure Migrate | Appliance démarrée | Appliance enregistrée |
|---|---|---|
| ![Projet](Screenshots/Etape12-12-ProjetAzureMigrate.png) | ![Appliance](Screenshots/Etape12-15-Appliance-Demarree.png) | ![Enregistrée](Screenshots/Etape12-17-Appliance-Enregistree.png) |
> 💡 *L'erreur rouge « NSX Manager » est **bénigne** : NSX est spécifique à VMware, sans objet en Hyper-V.*

### 4. Préparer l'hôte (WinRM) + découverte
Activation **WinRM** sur l'hôte (`Enable-PSRemoting`, profil réseau **Privé**), création d'un **compte local admin** dédié (`migadmin`), puis ajout de l'hôte `192.168.1.12` dans l'appliance → **découverte**.
| Validation WinRM de l'hôte | Découverte lancée |
|---|---|
| ![Validation](Screenshots/Etape12-23-Validation-WinRM.png) | ![Découverte](Screenshots/Etape12-25-Decouverte-Lancee.png) |
> ✅ *L'appliance interroge l'hôte Hyper-V en WinRM et remonte les VMs vers Azure. (Les alertes « inventaire logiciel 0% » sont bénignes : elles ne concernent que la découverte **invité**, pas la migration.)*

### 5. Évaluation (readiness + dimensionnement + coût)
Évaluation `eval-drox360` (**Azure VM**, dimensionnement **Localement**, cible **Germany West Central**).
![Résultat évaluation](Screenshots/Etape12-29-Resultat-Evaluation.png)
> ✅ *Rapport généré : **coût mensuel estimé ~233 $**, empreinte ~8 KgCO2e. La **préparation « Inconnu »** vient de l'inventaire invité incomplet (pas d'accès SSH certifiant l'OS) — **non bloquant** : les moteurs d'évaluation et de migration sont distincts.*

### 6. ⚠️ Limite : Hyper-V client non supporté pour la migration sans agent
L'installation du **fournisseur de réplication** (Azure Site Recovery) échoue sur l'hôte.
![ERR — Provider Hyper-V client](Screenshots/Etape12-ERR_ProviderHyperVClient.png)
> ❌ *« Setup cannot proceed… Hyper-V **role** enabled » : l'ASR Provider exige un hôte **Windows Server** (rôle Hyper-V), or l'hôte est **Windows 11** (Hyper-V y est une **fonctionnalité client**). Azure Migrate ne supporte pas le Hyper-V client pour la migration agentless.*
>
> 🔀 **Décision projet** : la migration réelle se fera en **agent-based** (traiter drox360 comme un serveur physique : *Mobility Service* + appliance de réplication) dans un **projet dédié**, mieux dimensionné en ressources. La partie découverte + évaluation reste acquise ici.
>
> 🧹 **Nettoyage budget** : éteindre/supprimer l'appliance de découverte et les ressources du projet `rg-4sky-migrate` (Key Vault + compte de stockage auto-créés) après captures.

---

## 🔐 Étape 13 — CI/CD DevSecOps (GitHub Actions)

**But :** automatiser **build → scan sécurité → déploiement** à chaque push, **sans aucun secret** (OIDC).
**Choix justifiés :** **OIDC** (identité fédérée, zéro mot de passe stocké) ; **pipeline en 3 jobs** liés par `needs` (graphe lisible, gates) ; **Trivy** comme gate de sécurité *shift-left*.

### 1. Identité fédérée + RBAC + secrets GitHub
| Identité fédérée | RBAC | Secrets GitHub |
|---|---|---|
| ![Fed cred](Screenshots/Etape13-IdentiteFederee.png) | ![RBAC](Screenshots/Etape13-IdentiteFedereeRole.png) | ![Secrets](Screenshots/Etape13-GitHubSecrets.png) |

### 2. Le grand troubleshooting OIDC
| ❌ AADSTS700213 | 🔧 Subject personnalisé |
|---|---|
| ![ERR OIDC](Screenshots/Etape13-ERR_OIDC.png) | ![FIX subject](Screenshots/Etape13-FIX_SubjectCustom.png) |

> 💡 **Le piège le plus subtil du projet** : le compte GitHub émet un subject OIDC **personnalisé** contenant les **IDs numériques** :
> `repo:nsid2003@119935744/D-ploiement-...-CI-CD@1308113981:ref:refs/heads/main`.
> Une identité fédérée « branche » standard ne matche **jamais**. Diagnostic par **décodage du token OIDC** dans le pipeline, puis identité fédérée **« Autre émetteur »** avec le subject exact.

### 3. Pipeline vert
![Pipeline vert](Screenshots/Etape13-PipelineVert.png)
> ✅ *3 jobs enchaînés (**Build & Push → Scan Trivy → Déploiement ACA**), en OIDC, déploiement automatique sur ACA. CI/CD DevSecOps de bout en bout opérationnelle.*

---

## 🗄️ Étape 14 — Gestion du stockage (Azure Storage Explorer)

**But :** administrer les comptes de stockage depuis l'**application de bureau**, plus confortable que le portail pour naviguer, téléverser et partager.
**Choix justifiés :** **Storage Explorer** (client officiel) pour gérer visuellement **Blob + Files** dans une seule interface ; génération d'un **SAS** (jeton d'accès délégué à durée limitée) plutôt que de diffuser la clé de compte.

### 1. Installer et connecter Storage Explorer
Télécharger **Microsoft Azure Storage Explorer**, l'installer, puis se connecter avec le compte Azure (ou attacher le compte de stockage).
| Application installée | Connexion au compte | Compte attaché |
|---|---|---|
| ![Storage Explorer](Screenshots/Etape14-StorageExplorerInstalle.png) | ![Connexion](Screenshots/Etape14-ConnexionCompte.png) | ![Compte attaché](Screenshots/Etape14-CompteAttache.png) |
> ✅ *`st4skyshared01` apparaît dans l'arborescence : Blob Containers, File Shares, Queues, Tables — tout est accessible depuis le bureau.*

### 2. Téléverser un blob et parcourir le partage Files
Upload d'un fichier (télémétrie web `telemetrie-4sky.csv`) dans un conteneur Blob, et navigation du partage **`partage-4sky`** (le même que celui synchronisé par Azure File Sync).
| Upload d'un blob | Partage Azure Files (File Sync) |
|---|---|
| ![Upload blob](Screenshots/Etape14-UploadBlob.png) | ![Partage Files](Screenshots/Etape14-PartageFileSync.png) |
> ✅ *On retrouve côté cloud les fichiers remontés par File Sync (Étape 06) → cohérence de bout en bout de la couche stockage.*

### 3. Générer un jeton SAS
Clic droit sur le conteneur/fichier → **Get Shared Access Signature** : droits et fenêtre de validité limités.
![SAS](Screenshots/Etape14-SAS.png)
> ✅ *Accès temporaire et restreint distribué **sans jamais exposer la clé du compte** — bonne pratique de moindre privilège.*

---

## 🛰️ Étape 15 — Supervision & SIEM (Microsoft Sentinel + KQL)

**But :** centraliser les journaux et activer un **SIEM** pour détecter et alerter sur l'activité de l'abonnement.
**Choix justifiés :** **Microsoft Sentinel** posé sur l'espace **Log Analytics `law-4sky`** (réutilisation des fondations) ; connecteur **Azure Activity** pour ingérer les opérations de gestion ; **KQL** pour requêter ; **alerte** pour la détection proactive.

### 1. Activer Microsoft Sentinel
Rechercher **Microsoft Sentinel → Ajouter** → sélectionner l'espace de travail **`law-4sky`**.
![Sentinel activé](Screenshots/Etape15-SentinelActive.png)
> ✅ *Sentinel est branché sur le Log Analytics existant : aucune donnée dupliquée, une seule « tour de contrôle ».*

### 2. Connecter la source Azure Activity
**Connecteurs de données → Azure Activity → Connecter** (via Diagnostic Settings) : les journaux d'activité de l'abonnement remontent dans Sentinel.
![Connecteur Azure Activity](Screenshots/Etape15-ConnecteurActivity.png)
> ✅ *Toutes les opérations de gestion (créations, suppressions, changements de rôle…) sont désormais collectées et analysables.*

### 3. Interroger en KQL
Requête **Kusto (KQL)** sur la table `AzureActivity` (ex. opérations récentes, par appelant/ressource).
![KQL Azure Activity](Screenshots/Etape15-KQL-Activity.png)
> ✅ *Le KQL permet de filtrer, agréger et corréler les événements — le langage central de la supervision Azure.*

### 4. Créer une règle d'alerte
Création d'une **alerte** (Azure Monitor / règle analytique) déclenchée sur un motif d'activité.
![Alerte](Screenshots/Etape15-Alerte.png)
> ✅ *La supervision devient **proactive** : au lieu de consulter les journaux, on est **notifié** quand un événement suspect survient.*

---

## 💾 Étape 16 — Sauvegarde (Recovery Services Vault)

**But :** protéger les données du partage de fichiers avec **Azure Backup**.
**Choix justifiés :** **Recovery Services Vault** dans la même région que le compte (`Germany West Central`) ; **Azure Files Backup** (sauvegarde par instantanés, sans agent) ; **stratégie quotidienne** avec rétention 30 jours.

### 1. Créer le coffre Recovery Services
`rsv-4sky` dans `rg-4sky-shared`, **Germany West Central** (impératif : coffre et compte de stockage doivent être **dans la même région**).
![Coffre Recovery Services](Screenshots/Etape16-Coffre.png)
> ✅ *Le coffre centralise les points de récupération et la gouvernance des sauvegardes.*

### 2. ⚠️ Incident : « Aucun compte de stockage » à la sélection
En configurant la sauvegarde Azure Files depuis le coffre, le compte `st4skyshared01` **n'apparaît pas**.
![ERR — aucun compte découvert](Screenshots/Etape16-ERR_AucunCompte.png)
> ❌ *Cause : le partage `partage-4sky` est **déjà protégé par un autre coffre**. Un compte/partage ne peut être associé qu'à **un seul coffre à la fois** — d'où la liste vide (« non enregistrés auprès d'un autre coffre »).*

### 3. FIX : piloter la sauvegarde depuis le partage
En passant par **`st4skyshared01 → Partage de fichiers → partage-4sky → Sauvegarde`**, on retrouve la protection **active** et ses points de récupération.
![Sauvegarde active + points de récupération](Screenshots/Etape16-SauvegardeAzureFiles-PointsRecuperation.png)
> ✅ *Sauvegarde **Réussie**, stratégie quotidienne (rétention 30 j), plusieurs **points de récupération** disponibles → le partage est protégé et restaurable.*
>
> 💡 *Leçon : pour vérifier/gérer la sauvegarde d'un partage, entrer **par le compte de stockage** est plus fiable que la découverte depuis le coffre.*

---

## 🛠️ Journal de troubleshooting (ERR → FIX)

Ce projet met l'accent sur la **résolution de problèmes réels**. Chaque obstacle est documenté avec sa cause et sa solution.

| # | Étape | Problème | Cause | Solution |
|---|---|---|---|---|
| 1 | 01 | `az login` — `AADSTS50076` | MFA activée, jeton sans « tampon MFA » | `az login --tenant <id>` avec MFA |
| 2 | 01 | `docker` non reconnu | PATH non rechargé + credential helper | Rouvrir terminal / redémarrer + PATH |
| 3 | 01 | Broadcom « No data found » (VMware) | Compte non habilité | Section *Free Software Downloads* |
| 4 | 03 | Plus d'accès Internet | DNS pointant vers lui-même | **Redirecteurs DNS** (`8.8.8.8`) |
| 5 | 03 | `dcdiag` en erreur | Réplication SYSVOL / DNS transitoires | `registerdns` + `Restart-Service Netlogon` |
| 6 | 04 | VNet refusé — `RequestDisallowedByAzure` | West Europe n'accepte plus de clients | Bascule **Germany West Central** |
| 7 | 06 | Fichier cloud non répliqué | Détection différée (jusqu'à 24 h) | `Invoke-AzStorageSyncChangeDetection` |
| 8 | 08 | Entra Connect introuvable | Déplacé par Microsoft | **Entra Admin Center** |
| 9 | 09 | SWA refusée par la policy | GWC n'existe pas pour SWA | Élargir la policy à **West US 2** |
| 10 | 09 | West Europe saturée (SWA) | Capacité région | Région **West US 2** (service global) |
| 11 | 11 | `TasksOperationsNotAllowed` | ACR Tasks bloqués (abonnement) | **Build local Docker** + push |
| 12 | 11 | Conteneur inaccessible | Port `:3000` manquant / HTTPS forcé | ACI = `http://…:3000`, ACA = `https://…` |
| 13 | 10 | Site VM en timeout | NSG sur IP dynamique + port | Règle NSG (IP courante) + `http://…` |
| 14 | 13 | OIDC `AADSTS700213` | Subject GitHub **personnalisé** (IDs) | Identité fédérée **« Autre émetteur »** |
| 15 | 12 | Virtualisation imbriquée VMware→Hyper-V KO | Nesting fragile (Device/Credential Guard) | Passer l'hôte en **Windows Education** (Hyper-V natif) |
| 16 | 12 | VM sans IP (`eth0` non connecté) | Commutateur externe Wi-Fi (traduction MAC) | **Commutateur par défaut** / `vSwitch-Externe` |
| 17 | 12 | `Set-WSManQuickConfig` échoue | Réseau classé **Public** | Passer le profil réseau en **Privé** |
| 18 | 12 | ASR Provider — « no compatible product » | Hyper-V **client** non supporté (Windows 11) | Migration **agent-based** (projet dédié) |
| 19 | 16 | Aucun compte de stockage découvert (Backup) | Partage déjà protégé par un autre coffre | Un partage = **un seul coffre** → piloter depuis le partage |

---
---

## 🗺️ Roadmap

- [x] Prérequis & outillage
- [x] On-Premise : AD DS, DNS, DHCP
- [x] Réseau Azure Hub-Spoke + NSG + Policy
- [x] Fondations : Log Analytics, Key Vault, Storage
- [x] Hybridation fichiers (Azure File Sync)
- [x] Structuration AD
- [x] Identité hybride (Entra Connect)
- [x] Compute PaaS/IaaS : Static Web Apps + Azure VM (nginx)
- [x] Conteneurs : ACR → ACI → ACA (`leads-hub`)
- [x] Migration On-Premise → Azure : **découverte + évaluation** (Azure Migrate) — *exécution reportée à un projet dédié (agent-based)*
- [x] Gestion du stockage : Azure Storage Explorer (Blob, Files, SAS)
- [x] DevSecOps : CI/CD GitHub Actions (OIDC + *shift-left*)
- [x] Supervision & SIEM : Azure Monitor + **Microsoft Sentinel** (KQL)
- [x] Sauvegarde : Recovery Services Vault (**Azure Files Backup**)
- [ ] VPN Gateway (Site-to-Site)
- [ ] Data : Azure Data Explorer + Event Hubs
- [ ] Edge & WAF : Front Door + Application Gateway
- [ ] Document d'Architecture Technique (DAT)

---

## 🧰 Stack technique

**Cloud** : Microsoft Azure (Germany West Central) · Microsoft Entra ID
**On-Premise** : VMware Workstation Pro · Windows Server 2025 (AD DS, DNS, DHCP, Fichiers)
**Hybridation & migration** : Azure File Sync · Entra Connect Cloud Sync · Azure Migrate
**IaC & outils** : Azure CLI · Bicep · Docker · Node.js · Git · PowerShell · VS Code
**DevSecOps & supervision** : GitHub Actions (OIDC) · Trivy · Microsoft Sentinel (KQL) · Azure Monitor — *à venir : CodeQL · Checkov · SonarQube · OWASP ZAP · Defender*

---

## 👤 Auteur

**Daryl Ngassa** — Préparation à la certification **Microsoft Azure Administrator (AZ-104)**.

> 📌 *Tutoriel maintenu en temps réel : chaque action est illustrée dans l'ordre, expliquée et justifiée, pour être reproductible par un débutant.*
