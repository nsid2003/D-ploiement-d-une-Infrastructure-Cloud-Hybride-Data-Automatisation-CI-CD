# ☁️ Déploiement d'une Infrastructure Cloud Hybride, Data & Automatisation CI/CD

> Projet de référence conçu comme une **révision opérationnelle transversale** pour la certification **Microsoft Azure Administrator (AZ-104)**, enrichie des notions **AZ-700 (Réseau)**, **AZ-500 (Sécurité)**, **AZ-800/801 (Hybridation)** et **AZ-400 (DevSecOps)**.
>
> L'objectif : construire de A à Z une architecture d'entreprise **hybride** (On-Premise ↔ Azure), en **documentant et justifiant chaque choix technique**, avec un accent fort sur le **diagnostic et la résolution de problèmes réels**.

![Azure](https://img.shields.io/badge/Cloud-Microsoft%20Azure-0078D4)
![Region](https://img.shields.io/badge/R%C3%A9gion-Germany%20West%20Central-informational)
![Hybrid](https://img.shields.io/badge/Topologie-Hub--Spoke%20Hybride-16A085)
![IaC](https://img.shields.io/badge/IaC-Bicep%20%7C%20Azure%20CLI-8E44AD)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions%20(OIDC)-2C3E50)

---

## 📑 Sommaire

1. [Contexte & objectifs](#-contexte--objectifs)
2. [Architecture cible](#️-architecture-cible)
3. [Périmètre technique](#-périmètre-technique)
4. [Plan d'adressage IP](#-plan-dadressage-ip)
5. [Conventions du projet](#-conventions-du-projet)
6. [Prérequis](#-prérequis)
7. [Guide de déploiement détaillé & justifié](#-guide-de-déploiement-détaillé--justifié)
8. [Journal de troubleshooting](#️-journal-de-troubleshooting-err--fix)
9. [Roadmap](#️-roadmap)
10. [Stack technique](#-stack-technique)

---

## 🎯 Contexte & objectifs

Ce projet simule l'infrastructure d'une PME fictive, **4SKY Group**, qui adopte une architecture **cloud hybride** tout en conservant un datacenter local. Il démontre une maîtrise complète de l'écosystème Microsoft Azure : hybridation réseau et identité, gouvernance, sécurité, compute, data et automatisation DevSecOps.

**Fil conducteur** : chaque décision (région, topologie, tier, protocole…) est **explicitement justifiée**, comme le ferait un architecte cloud dans un dossier de conception.

---

## 🏗️ Architecture cible

### Vue globale de l'infrastructure hybride

![Architecture cible](Screenshots/Architecture-01-Cible-Hybride.png)

### Chaîne DevSecOps (CI/CD sécurisé)

![Architecture DevSecOps](Screenshots/Architecture-02-DevSecOps.png)

> Sources éditables : `Architecture_Cible.drawio` et `Architecture_DevSecOps.drawio` (ouvrables sur [draw.io](https://app.diagrams.net)).

---

## 🧩 Périmètre technique

| Domaine | Composants |
|---|---|
| **On-Premise (VMware)** | Windows Server 2025 · AD DS · DNS · DHCP · Serveur de fichiers · Agent Azure File Sync · Agent Entra provisioning |
| **Réseau Azure** | Hub VNet · Spoke VNet · VNet Peering · NSG · Azure Policy · (VPN Gateway, Firewall, Bastion — à venir) |
| **Identité** | Microsoft Entra ID · Entra Connect **Cloud Sync** (PHS) |
| **Fondations** | Log Analytics · Key Vault · Storage Account (Blob + Files) |
| **Compute** | App Service · Static Web Apps · Azure VM · ACR / ACI / ACA *(à venir)* |
| **Data** | Azure Data Explorer · Event Hubs *(à venir)* |
| **Edge / Sécurité** | Front Door + WAF · Application Gateway *(à venir)* |
| **DevSecOps** | GitHub Actions (OIDC) · CodeQL · Trivy · Checkov · SonarQube · OWASP ZAP · Defender · Sentinel *(à venir)* |

### Applications & mapping compute

| Application | Techno | Cible Azure | Justification |
|---|---|---|---|
| cybersky | Vite / React | App Service | Site statique PaaS |
| pulse-x-agency | Next.js | App Service | App Node serveur → PaaS natif |
| visuance | Vite / React | Static Web Apps | Hébergement statique + CI/CD natif |
| drox360 | Vite / React | Static Web Apps | Idem |
| play-to-sky-production | Next.js | Azure VM (IaaS) | Démontrer le compute IaaS |
| **leads-hub** *(app dédiée créée)* | Conteneur + BDD | ACR → ACI → ACA | Démontrer la chaîne conteneur complète |

> **Pourquoi une 6ᵉ application ?** Les 5 sites sont réels (production) : pour illustrer **ACI** et **ACA** sans y toucher, une application conteneurisée dédiée `leads-hub` est créée. Elle suit le parcours pédagogique **ACR (registre) → ACI (dev/test) → ACA (prod, autoscale)**.

---

## 🌐 Plan d'adressage IP

| Réseau | CIDR | Rôle & justification |
|---|---|---|
| LAN On-Premise (VMware) | `192.168.10.0/24` | Réseau local privé, adressage stable et portable |
| **Hub VNet** | `10.0.0.0/16` | Zone centrale (passerelles, sécurité) |
| — GatewaySubnet | `10.0.0.0/27` | Nom **imposé** par Azure ; /27 = taille minimale pour la VPN Gateway |
| — AzureFirewallSubnet | `10.0.1.0/26` | Nom & taille /26 **imposés** par Azure Firewall |
| — AzureBastionSubnet | `10.0.2.0/26` | Nom & taille /26 **imposés** par Bastion |
| **Spoke VNet** | `10.1.0.0/16` | Zone des charges applicatives |
| — snet-appgw | `10.1.1.0/24` | Application Gateway |
| — snet-appsvc | `10.1.2.0/24` | App Service (intégration VNet) |
| — snet-vm | `10.1.3.0/24` | Machines virtuelles |
| — snet-aca | `10.1.4.0/23` | Container Apps (besoin d'un /23 minimum) |
| — snet-aci | `10.1.6.0/24` | Container Instances |
| — snet-data | `10.1.7.0/24` | PostgreSQL (subnet délégué) |
| — snet-pep | `10.1.8.0/24` | Private Endpoints |

---

## 📏 Conventions du projet

**Domaine AD** : `4skygroup.local` (NetBIOS `4SKYGROUP`) · **Région Azure** : `Germany West Central`

**Nommage (style Cloud Adoption Framework)** :
`rg-4sky-<rôle>` · `vnet-4sky-<zone>` · `snet-<usage>` · `nsg-snet-<usage>` · `st4sky<usage>` · `kv-4sky-<id>` · `app-4sky-<app>`

**Étiquettes obligatoires** (imposées par Azure Policy) :
`project=4sky-hybrid-lab` · `env=lab` · `owner=daryl` · `costCenter=IT`

**Nomenclature des captures** :

| Type | Format |
|---|---|
| Étape standard | `EtapeXX-NomDeLaTache.png` |
| Erreur rencontrée | `EtapeXX-ERR_DescriptionErreur.png` |
| Solution appliquée | `EtapeXX-FIX_ExplicationSolution.png` |

---

## ⚙️ Prérequis

**Comptes** : abonnement Azure · tenant Microsoft Entra ID · compte GitHub.
**Poste local** : virtualisation activée (VT-x/AMD-V) · **VMware Workstation Pro** · **ISO Windows Server 2025**.
**Outils** : Azure CLI · Bicep · Git · Node.js · Docker Desktop · VS Code.

---

## 🚀 Guide de déploiement détaillé & justifié

---

### ✅ Étape 01 — Prérequis & outillage

**Objectif** : préparer les comptes, le poste de virtualisation et la chaîne d'outils avant tout déploiement.

**Pourquoi ces choix ?**
- **VMware Workstation Pro** plutôt que VirtualBox : outil de virtualisation **professionnel** (proche de la famille vSphere), snapshots robustes, meilleures performances réseau — et **gratuit pour l'usage personnel** depuis fin 2024.
- **Azure CLI + Bicep** plutôt que le portail seul : **reproductibilité** et **Infrastructure as Code**, alignés avec la démarche DevSecOps du projet.
- **Alerte de budget créée en premier** : garde-fou indispensable, le crédit se consomme vite (VPN Gateway, Application Gateway, Data Explorer…).

**Réalisation** : installation via `winget` (Azure CLI, Node, Docker, Git), `az bicep install`, connexion `az login`, puis vérification.

| Outils installés | Connexion Azure |
|---|---|
| ![Versions des outils](Screenshots/Etape01-OutilsVersions.png) | ![az login](Screenshots/Etape01-AzLogin.png) |

| Azure CLI / Bicep | Docker fonctionnel |
|---|---|
| ![Az CLI](Screenshots/Etape01-AzCliVersion.png) | ![Docker Hello World](Screenshots/Etape01-DockerHelloWorld.png) |

VMware Workstation installé et ISO Windows Server 2025 récupérée :

| VMware installé | ISO Windows Server |
|---|---|
| ![VMware](Screenshots/Etape01-VMwareInstalle.png) | ![ISO](Screenshots/Etape01-ISO_WindowsServer.png) |

---

### ✅ Étape 02 — Machine virtuelle & Windows Server

**Objectif** : créer la VM `SRV-DC01` qui jouera le rôle du **datacenter On-Premise**.

**Pourquoi ces choix ?**
- **Specs 4 vCPU / 8 Go / 80 Go / UEFI** : confortables pour un contrôleur de domaine cumulant plusieurs rôles.
- **Réseau NAT** (et non *bridged*) : **isolation** du réseau physique (crucial car on installera un **serveur DHCP** — en bridged, il distribuerait des adresses sur le vrai réseau maison), **adressage stable et portable**, et accès Internet conservé.
- **« Install OS later »** au lieu de l'Easy Install : pour **maîtriser chaque écran** d'installation (démarche pédagogique).
- **Édition Standard « Desktop Experience »** (avec interface graphique) : plus simple à apprendre et administrer que l'édition Core.

**Réalisation** : configuration matérielle de la VM, puis installation de Windows Server 2025 + VMware Tools.

| Configuration matérielle | Serveur opérationnel |
|---|---|
| ![Config VM](Screenshots/Etape02-ConfigMaterielleVM.png) | ![Serveur prêt](Screenshots/Etape02-ServeurPret.png) |

---

### ✅ Étape 03 — Contrôleur de domaine (AD DS + DNS + DHCP)

**Objectif** : transformer `SRV-DC01` en cœur de l'annuaire d'entreprise.

**Pourquoi ces choix ?**
- **IP statique** (`192.168.10.10`) : un contrôleur de domaine **doit** avoir une adresse fixe (tout le domaine s'y adresse).
- **DNS pointant vers lui-même** : AD DS repose entièrement sur le DNS ; le DC doit se résoudre via son propre service DNS.
- **Redirecteurs DNS** (`8.8.8.8`, `1.1.1.1`) : permettent au DC de résoudre les noms **externes** (Internet) tout en restant maître de sa zone locale.
- **Étendue DHCP `.50`–`.200`** : on réserve `.1`–`.49` (infra/IP fixes) et `.201`–`.254` (marge).
- **Autorisation DHCP dans AD** : un serveur DHCP non autorisé **refuse** de distribuer — sécurité anti-DHCP pirate.

**Réalisation** : réseau NAT aligné sur `192.168.10.0/24`, IP statique, renommage, promotion en nouvelle forêt `4skygroup.local`, mot de passe DSRM, redirecteurs DNS, puis rôle DHCP.

| Réseau NAT | IP statique | Renommage |
|---|---|---|
| ![NAT](Screenshots/Etape03-ReseauNAT.png) | ![IP statique](Screenshots/Etape03-IPStatique.png) | ![Renommage](Screenshots/Etape03-RenommagePC.png) |

| Rôle AD DS | Nouvelle forêt | Mot de passe DSRM |
|---|---|---|
| ![AD DS](Screenshots/Etape03-AjoutRoleADDS.png) | ![Forêt](Screenshots/Etape03-NouvelleForet.png) | ![DSRM](Screenshots/Etape03-MotDePasseDSRM.png) |

| Promotion | Connexion au domaine | Redirecteurs DNS |
|---|---|---|
| ![Promotion](Screenshots/Etape03-PromotionInstall.png) | ![Connexion domaine](Screenshots/Etape03-ConnexionDomaine.png) | ![Redirecteurs](Screenshots/Etape03-RedirecteursDNS.png) |

**DHCP** — rôle, autorisation dans AD, étendue et vérification :

| Rôle DHCP | Autorisation AD | Étendue | Vérification |
|---|---|---|---|
| ![Rôle DHCP](Screenshots/Etape03-AjoutRoleDHCP.png) | ![Autorisation](Screenshots/Etape03-AutorisationDHCP.png) | ![Étendue](Screenshots/Etape03-EtendueDHCP.png) | ![Vérif DHCP](Screenshots/Etape03-VerifDHCP.png) |

> 🛠️ Deux incidents rencontrés à cette étape (perte d'accès Internet, erreurs `dcdiag`) sont documentés dans le [journal de troubleshooting](#️-journal-de-troubleshooting-err--fix).

---

### ✅ Étape 04 — Réseau Azure Hub-Spoke

**Objectif** : bâtir le réseau cloud, gouverné et segmenté.

**Pourquoi ces choix ?**
- **Topologie Hub-Spoke** plutôt qu'un VNet unique : standard **entreprise** (isolation, mutualisation des services centraux, aligné AZ-700).
- **Région Germany West Central** : après le blocage de *West Europe* (saturée) et l'écart de *France Central* (dispo SKU compute limitée), GWC offre une **région mature, ouverte, avec un large catalogue de SKU** et la **conformité UE/RGPD**.
- **Azure Policy** (`Allowed locations` + `Require a tag on resources`) : **gouvernance automatisée** — empêche tout déploiement hors région autorisée et impose l'étiquette `project` (traçabilité/FinOps).
- **Un NSG par sous-réseau** : segmentation en **moindre privilège** (ex. RDP autorisé uniquement depuis le LAN On-Prem).
- **Étiquettes systématiques** : suivi des coûts et de la propriété des ressources.

**Réalisation** : RG réseau, Hub VNet + subnets, Spoke VNet + subnets, peering, policies, NSG (dont automatisation par script Bash `create-nsg-spoke.sh`).

| Contexte Azure | RG réseau | Policies |
|---|---|---|
| ![Contexte](Screenshots/Etape04-Contexte%20Azure.png) | ![RG réseau](Screenshots/Etape04-RGReseau.png) | ![Policies](Screenshots/Etape04-Policies.png) |

| Hub VNet | Spoke VNet | Peering |
|---|---|---|
| ![Hub](Screenshots/Etape04-HubVNet.png) | ![Spoke](Screenshots/Etape04-SpokeVNet.png) | ![Peering](Screenshots/Etape04-Peering.png) |

| NSG (VM) | NSG via script | Vérif NSG | Vérif peering |
|---|---|---|---|
| ![NSG VM](Screenshots/Etape04-NSG-vm.png) | ![NSG script](Screenshots/Etape04-NSG-script.png) | ![Vérif NSG](Screenshots/Etape04-VerifNSG.png) | ![Vérif peering](Screenshots/Etape04-VerifPeering.png) |

> 💡 **Automatisation** : les NSG `aci`, `data` et `pep` sont créés et associés via le script [`create-nsg-spoke.sh`](create-nsg-spoke.sh) — première brique d'Infrastructure as Code du projet.

---

### ✅ Étape 05 — Fondations partagées

**Objectif** : poser les services de plateforme (sécurité, monitoring, stockage).

**Pourquoi ces choix ?**
- **RG partagé dédié** : séparation des cycles de vie (démarche *landing zone*).
- **Log Analytics** : point de collecte central pour tous les journaux et métriques.
- **Key Vault en modèle RBAC** (et non *access policies*) : approche **moderne et granulaire** recommandée par Microsoft.
- **Storage Account en StorageV2** (et non « Blob » pur) : indispensable car il gère **à la fois Blob et Files** — les partages de fichiers étant requis pour Azure File Sync.
- **Redondance LRS** : la moins chère, suffisante pour un lab.

| RG partagé | Log Analytics | Key Vault | Storage |
|---|---|---|---|
| ![RG shared](Screenshots/Etape05-RGShared.png) | ![Log Analytics](Screenshots/Etape05-LogAnalytics.png) | ![Key Vault](Screenshots/Etape05-KeyVault.png) | ![Storage](Screenshots/Etape05-Storage.png) |

---

### ✅ Étape 06 — Hybridation des fichiers (Azure File Sync)

**Objectif** : synchroniser un dossier du serveur local avec le cloud, en bidirectionnel.

**Pourquoi ces choix ?**
- **Azure File Sync** plutôt qu'une copie manuelle : **synchronisation continue bidirectionnelle** + **cloud tiering** (déchargement des vieux fichiers vers Azure pour économiser le disque local).
- **Fonctionne en HTTPS** : **aucun VPN requis**, ce qui simplifie et sécurise l'hybridation.

**Réalisation (côté Azure)** : partage `partage-4sky`, Storage Sync Service `sss-4sky`, groupe de synchronisation.
**Réalisation (côté serveur)** : dossier `C:\Partages\Entreprise`, agent Azure File Sync, enregistrement du serveur, server endpoint.

| Partage Azure | Storage Sync Service | Groupe de synchro |
|---|---|---|
| ![File Share](Screenshots/Etape06-FileShare.png) | ![Sync Service](Screenshots/Etape06-StorageSyncService.png) | ![Sync Group](Screenshots/Etape06-SyncGroup.png) |

| Dossier local | Agent installé | Enregistrement serveur | Server endpoint |
|---|---|---|---|
| ![Dossier](Screenshots/Etape06-DossierPartage.png) | ![Agent](Screenshots/Etape06-AgentInstalle.png) | ![Enregistrement](Screenshots/Etape06-EnregistrementServeur.png) | ![Endpoint](Screenshots/Etape06-ServerEndpoint.png) |

Synchronisation validée (serveur → Azure) :

![Sync OnPrem vers Azure](Screenshots/Etape06-Sync-OnPrem-vers-Azure.png)

> 🛠️ Point clé documenté : le sens **cloud → serveur** repose sur une **détection différée (jusqu'à 24 h)** — voir le journal de troubleshooting.

---

### ✅ Étape 07 — Structuration de l'annuaire AD

**Objectif** : peupler l'Active Directory avant la synchronisation hybride.

**Pourquoi ces choix ?**
- **Unités d'organisation (OU)** : rangement logique + **délégation** de droits + ciblage des futures **GPO**.
- **Groupes de sécurité globaux** (`GG_IT`, `GG_RH`, `GG_Marketing`) : gestion des accès **par rôle** plutôt que par utilisateur.
- **Création par script PowerShell** : reproductible et documenté.

![Structure AD](Screenshots/Etape07-StructureAD.png)

---

### ✅ Étape 08 — Identité hybride (Entra Connect Cloud Sync)

**Objectif** : synchroniser l'annuaire local vers Microsoft Entra ID.

**Pourquoi ces choix ?**
- **Cloud Sync** plutôt que Connect Sync (classique) : **agent léger**, **piloté depuis le cloud**, idéal pour une **forêt unique** — et c'est la voie **recommandée par Microsoft** (Connect Sync disparaît d'ailleurs du Download Center).
- **PHS (Password Hash Sync)** : **même mot de passe** en local et dans le cloud, méthode la plus simple et résiliente.
- **Suffixe UPN routable** (`...onmicrosoft.com`) : obligatoire car `@4skygroup.local` n'est **pas routable** et ne peut pas être synchronisé.
- **Filtrage sur l'OU 4SKY** : ne remonter que les objets pertinents (pas les comptes système).

**Réalisation** : suffixe UPN, agent d'approvisionnement, configuration Cloud Sync (scope OU + PHS), activation.

| Suffixe UPN | Agent Cloud Sync OK | Configuration |
|---|---|---|
| ![Suffixe UPN](Screenshots/Etape08-SuffixeUPN.png) | ![Agent OK](Screenshots/Etape08-AgentCloudSyncOK.png) | ![Config](Screenshots/Etape08-ConfigCloudSync.png) |

| Filtre OU | Configuration activée | Vérification dans Entra ID |
|---|---|---|
| ![Filtre OU](Screenshots/Etape08-FiltreOU.png) | ![Config activée](Screenshots/Etape08-ConfigActivee.png) | ![Vérif Entra](Screenshots/Etape08-VerifSyncEntra.png) |

Résultat : **2 utilisateurs + 3 groupes** synchronisés vers Entra ID.

| Utilisateurs synchronisés | Détails |
|---|---|
| ![Vérif 2](Screenshots/Etape08-VerifSyncEntra02.png) | ![Vérif 3](Screenshots/Etape08-VerifSyncEntra03.png) |

---

### 🔜 Étape 09 — Compute (à venir)

Déploiement des applications sur **App Service (B1)**, Static Web Apps, VM et conteneurs (ACR → ACI → ACA).

---

## 🛠️ Journal de troubleshooting (ERR → FIX)

Ce projet met l'accent sur la **résolution de problèmes réels**. Chaque obstacle est documenté avec sa cause et sa solution.

| # | Problème | Cause | Solution |
|---|---|---|---|
| 1 | `az login` — `AADSTS50076 InteractionRequired` | MFA activée, jeton sans « tampon MFA » | `az logout` + `az login --tenant <id>` avec MFA |
| 2 | `docker : terme non reconnu` | PATH non rechargé + credential helper absent | Rouvrir le terminal / redémarrer + `...\Docker\resources\bin` au PATH |
| 3 | Création VNet refusée — `RequestDisallowedByAzure` | *West Europe* n'accepte plus de nouveaux clients (saturation) | Bascule vers **Germany West Central** |
| 4 | Broadcom : « No data found » (VMware) | Compte non habilité aux téléchargements gratuits | Section **« Free Software Downloads »** |
| 5 | Entra Connect introuvable sur le Download Center | Distribution déplacée par Microsoft | Téléchargement via le **Microsoft Entra Admin Center** |
| 6 | Liste des domaines vide (Cloud Sync) | Agent pas encore « actif » côté cloud | Attendre l'enregistrement + rafraîchir |
| 7 | `dcdiag` en erreur après promotion du DC | Réplication SYSVOL / DNS transitoires | `ipconfig /registerdns` + `Restart-Service Netlogon` |
| 8 | Fichier cloud non répliqué vers le serveur | Détection des changements directs (jusqu'à 24 h) | `Invoke-AzStorageSyncChangeDetection` |

**Illustrations (Étape 03)** — perte puis retour de l'accès Internet :

| ERR — plus d'Internet | FIX — Internet rétabli | ERR — dcdiag |
|---|---|---|
| ![ERR Internet](Screenshots/Etape03-ERR_PasInternet.png) | ![FIX Internet](Screenshots/Etape03-FIX_Internet.png) | ![ERR dcdiag](Screenshots/Etape03-ERR_dcdiag.png) |

---

## 🗺️ Roadmap

- [x] Prérequis & outillage
- [x] On-Premise : AD DS, DNS, DHCP
- [x] Réseau Azure Hub-Spoke + NSG + Policy
- [x] Fondations : Log Analytics, Key Vault, Storage
- [x] Hybridation fichiers (Azure File Sync)
- [x] Structuration AD
- [x] Identité hybride (Entra Connect)
- [ ] Compute : App Service, Static Web Apps, VM
- [ ] Conteneurs : ACR → ACI → ACA (`leads-hub`)
- [ ] Connexion hybride : VPN Gateway (Site-to-Site)
- [ ] Data : Azure Data Explorer + Event Hubs
- [ ] Edge & WAF : Front Door + Application Gateway
- [ ] Sauvegarde : Recovery Services Vault
- [ ] DevSecOps : pipeline CI/CD GitHub Actions (OIDC + *shift-left*)
- [ ] Supervision : Azure Monitor, Application Insights, Sentinel
- [ ] Document d'Architecture Technique (DAT) complet

---

## 🧰 Stack technique

**Cloud** : Microsoft Azure (Germany West Central) · Microsoft Entra ID
**On-Premise** : VMware Workstation Pro · Windows Server 2025 (AD DS, DNS, DHCP, Fichiers)
**Hybridation** : Azure File Sync · Entra Connect Cloud Sync
**IaC & outils** : Azure CLI · Bicep · Docker · Node.js · Git · PowerShell · VS Code
**DevSecOps (à venir)** : GitHub Actions · CodeQL · Dependabot · Trivy · Checkov · SonarQube · OWASP ZAP · Syft · Cosign · Defender for Cloud · Microsoft Sentinel

---

## 👤 Auteur

**Daryl Ngassa** — Projet de préparation à la certification **Microsoft Azure Administrator (AZ-104)**.

> 📌 *Documentation maintenue en temps réel. Chaque étape est justifiée et illustrée (dossier `Screenshots/`), et chaque obstacle rencontré est documenté dans le journal de troubleshooting — une démonstration concrète de capacité d'analyse et de résolution.*
