# ARK: Survival Ascended — Dedicated Server (Docker)

🇬🇧 [English](#english) | 🇫🇷 [Français](#français)

---

## English

Docker container to host an **ARK: Survival Ascended** dedicated server (SteamCMD App ID `2430930`).

ARK: Survival Ascended has **no native Linux server binary** — the real server is a Windows executable (`ArkAscendedServer.exe`). This image runs it under **Proton-GE** (`GE-Proton11-5`, pinned in the `Dockerfile`) on top of a headless Xvfb display and a software Vulkan driver (`mesa-vulkan-drivers` / lavapipe), since the Unreal Engine 5 server still tries to initialize a graphics device even with no GPU present. Everything else (SteamCMD download/update, launch parameters, process supervision) is a custom `start_server.sh`, not a third-party image.

- Docker Hub image: [`ludix0/asa`](https://hub.docker.com/r/ludix0/asa)
- Ports used: `7777/udp` (game), `27020/tcp` (RCON)

### Requirements

- Docker Engine + Docker Compose v2
- ~40 GB free disk space for the server files (more with mods)
- No GPU required (software Vulkan rendering)
- A free UDP port for the game and a free TCP port for RCON

### Method 1 — Quick install from Docker Hub (recommended)

Create a folder, add a `docker-compose.yml`:

```yaml
services:
  asa:
    image: ludix0/asa:latest
    container_name: ASA
    restart: unless-stopped
    environment:
      - TZ=Europe/Paris
      - PUID=1000
      - PGID=1000
      - ASA_SERVER_PASSWORD=
      - ASA_ADMIN_PASSWORD=changeme
      - GAME_PORT=7777
      - RCONPort=27020
      - MAX_PLAYERS=20
      - UPDATE_ON_START=true
      - map=Astraeos_WP
      - SessionName=Ludix_ASA_FR
      - CLUSTER_ID=LudixASACluster
      - NoBattlEye=True
      - ServerPVE=True
    ports:
      - 0.0.0.0:7777:7777/udp
      - 0.0.0.0:27020:27020/tcp
    volumes:
      - ./filesServer:/home/steam/asa_server
      - ./logs:/home/steam/asa_server/ShooterGame/Saved/Logs
      - ./cluster-shared:/home/steam/asa_server/ShooterGame/Binaries/Win64/cluster-shared
      - ./proton-steam:/home/steam/Steam
      - ./proton-prefix:/home/steam/proton-prefix
      - ./steamcmd:/home/steam/steamcmd
```

Then:

```bash
docker compose up -d
docker compose logs -f
```

### Method 2 — Build from source (GitHub)

```bash
git clone <YOUR-GITHUB-REPO-URL>
cd asa
cp .env.example .env   # fill in your own values
docker compose build
docker compose up -d
```

### Environment variables

**Connection / core**

| Variable | Required | Description |
|---|---|---|
| `TZ` | yes | Container timezone |
| `PUID` / `PGID` | yes | UID/GID the server runs as inside the container |
| `ASA_SERVER_PASSWORD` | no | Password to join the server (empty = open) |
| `ASA_ADMIN_PASSWORD` | yes | Admin password (used in-game via `enablecheats`) |
| `GAME_PORT` | yes | UDP game port (container side, default `7777`) |
| `RCONPort` | yes | TCP RCON port (container side, default `27020`) |
| `MAX_PLAYERS` | yes | Max simultaneous players |
| `UPDATE_ON_START` | yes | Force a SteamCMD update on every container start |

**Server / session**

| Variable | Required | Description |
|---|---|---|
| `map` | yes | Map to load. One of: `TheIsland_WP`, `TheCenter_WP`, `ScorchedEarth_WP`, `Astraeos_WP`, `Extinction_WP`, `LostColony_WP`, `Valguero_WP`, `Aberration_WP`, `Ragnarok_WP` |
| `SessionName` | yes | Name shown in the ARK server browser |
| `CLUSTER_ID` | no | Cluster identifier, shared across maps via the `cluster-shared` volume |
| `MODS` | no | Comma-separated CurseForge mod IDs |
| `NoBattlEye` | no | Disable BattlEye anti-cheat (recommended `True` — unreliable under Proton/Linux) |
| `EXTRA_PARAMS` | no | Free-form extra launch arguments, appended as-is |

**Gameplay (multipliers, limits, misc.)** — all optional, defaults shown are this project's current settings in `docker-compose.yml`:

| Variable | Default | Description |
|---|---|---|
| `ServerPVE` | `True` | PVE mode instead of PVP |
| `ShowFloatingDamageText` | `True` | Show damage numbers |
| `XPMultiplier` | `2.0` | XP gain multiplier |
| `DifficultyOffset` | `10` | Difficulty offset (affects max wild creature level) |
| `OverrideOfficialDifficulty` | `10` | Forces official difficulty (e.g. 5 = level 150 creatures) |
| `DinoDamageMultiplier` | `1.0` | Dino damage multiplier |
| `TamingSpeedMultiplier` | `5.0` | Taming speed multiplier |
| `HarvestAmountMultiplier` | `1.0` | Resource harvest multiplier |
| `StructureResistanceMultiplier` | `1.0` | Structure damage resistance multiplier |
| `AllowHitMarkers` / `bPreventHitMarkers` | `True` / `True` | Hit marker display |
| `bPreventCrosshair` | `True` | Hide default crosshair |
| `EggHatchSpeedMultiplier` | `10.0` | Egg hatching speed |
| `BabyMatureSpeedMultiplier` | `10.0` | Baby dino growth speed |
| `BabyCuddleIntervalMultiplier` | `0.5` | Interval between baby dino cuddles |
| `DinoCountMultiplier` | `2.0` | Wild dino spawn count multiplier |
| `AllowFlyerCarryPvE` | `True` | Allow flyers to carry players/dinos in PvE |
| `MaxTamedDinos` | `5000` | Max tamed dinos on the server |
| `ShowMapPlayerLocation` | `True` | Show player position on map |
| `AllowThirdPersonPlayer` | `True` | Allow third-person camera |
| `ServerCrosshair` | `True` | Show server crosshair |
| `TheMaxStructuresInRange` | `10500` | Max structures in a given area |
| `StartTimeHour` | `-1` | Day/night cycle start hour (`-1` = random) |
| `OxygenSwimSpeedStatMultiplier` | `1` | Swim speed / oxygen consumption multiplier |
| `StructurePreventResourceRadiusMultiplier` | `1` | Radius preventing building near resources |
| `TribeNameChangeCooldown` | `15` | Days before a tribe can rename again |
| `PlatformSaddleBuildAreaBoundsMultiplier` | `1` | Buildable area on platform saddles |
| `AlwaysAllowStructurePickup` | `True` | Always allow picking up placed structures |
| `StructurePickupTimeAfterPlacement` | `30` | Seconds a structure stays pickable after placement |
| `StructurePickupHoldDuration` | `0.5` | Seconds to hold to pick up a structure |
| `AllowHideDamageSourceFromLogs` | `True` | Hide damage source from server logs |
| `RaidDinoCharacterFoodDrainMultiplier` | `1` | Food drain multiplier for raid dinos |
| `PvEDinoDecayPeriodMultiplier` | `1` | Decay speed of unclaimed PvE dinos |
| `KickIdlePlayersPeriod` | `3600` | Seconds before kicking an idle player |
| `PerPlatformMaxStructuresMultiplier` | `1` | Max structures per platform multiplier |
| `AutoSavePeriodMinutes` | `30` | Minutes between auto-saves |
| `MaxTamedDinos_SoftTameLimit` | `5000` | Soft tame limit before automatic cleanup |
| `MaxTamedDinos_SoftTameLimit_CountdownForDeletionDuration` | `604800` | Seconds before deleting dinos past the soft limit |
| `OverrideSecondsUntilBuriedTreasureAutoReveals` | `1209600` | Seconds before buried treasure auto-reveals |
| `ItemStackSizeMultiplier` | `1` | Inventory item stack size multiplier |
| `RCONServerGameLogBuffer` | `600` | RCON game log buffer size |
| `ImplantSuicideCD` | `28800` | Cooldown before implant suicide is possible again |
| `DisableCryopodFridgeRequirement` | `True` | Deploy/recall cryopodded dinos without a nearby Cryofridge |
| `AllowCryoFridgeOnSaddle` | `True` | Allow building a Cryofridge on a platform saddle (mobile base) |
| `DisableCryopodEnemyCheck` | `True` | Ignore the nearby-enemy check when using cryopods (mainly relevant in PvP) |

**Seasonal events** — on ARK: Survival Ascended, seasonal events are real CurseForge mods published by `StudioWildcardMods`, not a simple flag. Each is added to `MODS` automatically while today's date falls within its window. `<NAME>_DATE` accepts a `MM/DD-MM/DD` range and can wrap around New Year (e.g. Winter Wonderland); set `<NAME>=False` to disable one event entirely.

| Variable | Default | Mod ID | Default date range |
|---|---|---|---|
| `LOVE_ASCENDED` / `LOVE_ASCENDED_DATE` | `True` / `02/11-02/18` | `927084` | Official 2026 dates |
| `EGGCELLENT_ADVENTURE` / `EGGCELLENT_ADVENTURE_DATE` | `True` / `03/31-04/14` | `877745` | Official 2026 dates |
| `SUMMER_BASH` / `SUMMER_BASH_DATE` | `True` / `07/01-07/21` | `927091` | Approximate — adjust once official dates are known |
| `FEAR_ASCENDED` / `FEAR_ASCENDED_DATE` | `True` / `10/01-10/31` | `877752` | Approximate — adjust once official dates are known |
| `TURKEY_TRIAL` / `TURKEY_TRIAL_DATE` | `True` / `11/20-11/30` | `927083` | Approximate — adjust once official dates are known |
| `WINTER_WONDERLAND` / `WINTER_WONDERLAND_DATE` | `True` / `12/10-01/10` | `927090` | Approximate — adjust once official dates are known |

### Volumes

| Host volume | Container path | Content |
|---|---|---|
| `~/volumes/ASA/filesServer` | `/home/steam/asa_server` | Server files (installed/updated by SteamCMD) |
| `~/volumes/ASA/logs` | `/home/steam/asa_server/ShooterGame/Saved/Logs` | Server logs |
| `~/volumes/ASA/cluster-shared` | `.../Binaries/Win64/cluster-shared` | Cluster data shared across maps |
| `~/volumes/ASA-proton/steam` | `/home/steam/Steam` | Steam folder used by Proton |
| `~/volumes/ASA-proton/proton-prefix` | `/home/steam/proton-prefix` | Proton/Wine prefix |
| `~/volumes/steamcmd` | `/home/steam/steamcmd` | SteamCMD, shared with all other game servers |

### Ports

| Port | Protocol | Usage |
|---|---|---|
| `7777` (host: `${jeux1}`) | UDP | Game port (players connect via the ARK server browser) |
| `27020` (host: `${rcon}`) | TCP | RCON (remote administration) |

---

## Français

Conteneur Docker pour héberger un serveur dédié **ARK: Survival Ascended** (SteamCMD App ID `2430930`).

ARK: Survival Ascended **n'a pas de binaire serveur Linux natif** — le vrai serveur est un exécutable Windows (`ArkAscendedServer.exe`). Cette image l'exécute via **Proton-GE** (`GE-Proton11-5`, figé dans le `Dockerfile`) au-dessus d'un écran virtuel Xvfb et d'un pilote Vulkan logiciel (`mesa-vulkan-drivers` / lavapipe), car le serveur sous Unreal Engine 5 tente d'initialiser un périphérique graphique même sans GPU. Tout le reste (téléchargement/mise à jour SteamCMD, paramètres de lancement, supervision du processus) vient d'un `start_server.sh` maison, pas d'une image tierce toute faite.

- Image Docker Hub : [`ludix0/asa`](https://hub.docker.com/r/ludix0/asa)
- Ports utilisés : `7777/udp` (jeu), `27020/tcp` (RCON)

### Prérequis

- Docker Engine + Docker Compose v2
- ~40 Go d'espace disque libre pour les fichiers serveur (plus avec des mods)
- Aucun GPU requis (rendu Vulkan logiciel)
- Un port UDP libre pour le jeu et un port TCP libre pour le RCON

### Méthode 1 — Installation rapide depuis Docker Hub (recommandé)

Créer un dossier, y ajouter un `docker-compose.yml` :

```yaml
services:
  asa:
    image: ludix0/asa:latest
    container_name: ASA
    restart: unless-stopped
    environment:
      - TZ=Europe/Paris
      - PUID=1000
      - PGID=1000
      - ASA_SERVER_PASSWORD=
      - ASA_ADMIN_PASSWORD=changeme
      - GAME_PORT=7777
      - RCONPort=27020
      - MAX_PLAYERS=20
      - UPDATE_ON_START=true
      - map=Astraeos_WP
      - SessionName=Ludix_ASA_FR
      - CLUSTER_ID=LudixASACluster
      - NoBattlEye=True
      - ServerPVE=True
    ports:
      - 0.0.0.0:7777:7777/udp
      - 0.0.0.0:27020:27020/tcp
    volumes:
      - ./filesServer:/home/steam/asa_server
      - ./logs:/home/steam/asa_server/ShooterGame/Saved/Logs
      - ./cluster-shared:/home/steam/asa_server/ShooterGame/Binaries/Win64/cluster-shared
      - ./proton-steam:/home/steam/Steam
      - ./proton-prefix:/home/steam/proton-prefix
      - ./steamcmd:/home/steam/steamcmd
```

Puis :

```bash
docker compose up -d
docker compose logs -f
```

### Méthode 2 — Build depuis les sources (GitHub)

```bash
git clone <URL-DE-VOTRE-DEPOT-GITHUB>
cd asa
cp .env.example .env   # renseigner vos propres valeurs
docker compose build
docker compose up -d
```

### Variables d'environnement

**Connexion / cœur**

| Variable | Obligatoire | Description |
|---|---|---|
| `TZ` | oui | Fuseau horaire du conteneur |
| `PUID` / `PGID` | oui | UID/GID sous lequel tourne le serveur dans le conteneur |
| `ASA_SERVER_PASSWORD` | non | Mot de passe pour rejoindre le serveur (vide = accès libre) |
| `ASA_ADMIN_PASSWORD` | oui | Mot de passe admin (utilisé en jeu via `enablecheats`) |
| `GAME_PORT` | oui | Port UDP de jeu (côté conteneur, défaut `7777`) |
| `RCONPort` | oui | Port TCP RCON (côté conteneur, défaut `27020`) |
| `MAX_PLAYERS` | oui | Nombre maximum de joueurs simultanés |
| `UPDATE_ON_START` | oui | Force la mise à jour SteamCMD à chaque démarrage du conteneur |

**Serveur / session**

| Variable | Obligatoire | Description |
|---|---|---|
| `map` | oui | Carte à charger. Parmi : `TheIsland_WP`, `TheCenter_WP`, `ScorchedEarth_WP`, `Astraeos_WP`, `Extinction_WP`, `LostColony_WP`, `Valguero_WP`, `Aberration_WP`, `Ragnarok_WP` |
| `SessionName` | oui | Nom affiché dans le navigateur de serveurs ARK |
| `CLUSTER_ID` | non | Identifiant de cluster, partagé entre cartes via le volume `cluster-shared` |
| `MODS` | non | Identifiants CurseForge séparés par des virgules |
| `NoBattlEye` | non | Désactive BattlEye (recommandé `True` — peu fiable sous Proton/Linux) |
| `EXTRA_PARAMS` | non | Paramètres de lancement libres, ajoutés tels quels |

**Gameplay (multiplicateurs, limites, divers)** — tous facultatifs, valeurs par défaut = réglages actuels de ce projet dans `docker-compose.yml` :

| Variable | Défaut | Description |
|---|---|---|
| `ServerPVE` | `True` | Mode PVE plutôt que PVP |
| `ShowFloatingDamageText` | `True` | Affiche les dégâts au-dessus de la cible |
| `XPMultiplier` | `2.0` | Multiplicateur d'expérience |
| `DifficultyOffset` | `10` | Décalage de difficulté (niveau max des créatures sauvages) |
| `OverrideOfficialDifficulty` | `10` | Force la difficulté officielle (ex : 5 = créatures niveau 150) |
| `DinoDamageMultiplier` | `1.0` | Multiplicateur de dégâts des dinos |
| `TamingSpeedMultiplier` | `5.0` | Multiplicateur de vitesse d'apprivoisement |
| `HarvestAmountMultiplier` | `1.0` | Multiplicateur de récolte de ressources |
| `StructureResistanceMultiplier` | `1.0` | Multiplicateur de résistance des structures |
| `AllowHitMarkers` / `bPreventHitMarkers` | `True` / `True` | Affichage des marqueurs de coup |
| `bPreventCrosshair` | `True` | Masque le réticule par défaut |
| `EggHatchSpeedMultiplier` | `10.0` | Vitesse d'éclosion des œufs |
| `BabyMatureSpeedMultiplier` | `10.0` | Vitesse de croissance des bébés dinos |
| `BabyCuddleIntervalMultiplier` | `0.5` | Intervalle entre câlins des bébés dinos |
| `DinoCountMultiplier` | `2.0` | Multiplicateur du nombre de dinos sauvages |
| `AllowFlyerCarryPvE` | `True` | Autorise les volants à transporter en PvE |
| `MaxTamedDinos` | `5000` | Nombre maximum de dinos apprivoisés |
| `ShowMapPlayerLocation` | `True` | Affiche la position du joueur sur la carte |
| `AllowThirdPersonPlayer` | `True` | Autorise la vue à la troisième personne |
| `ServerCrosshair` | `True` | Affiche le réticule du serveur |
| `TheMaxStructuresInRange` | `10500` | Nombre max de structures dans une zone donnée |
| `StartTimeHour` | `-1` | Heure de démarrage du cycle jour/nuit (`-1` = aléatoire) |
| `OxygenSwimSpeedStatMultiplier` | `1` | Multiplicateur vitesse de nage / oxygène |
| `StructurePreventResourceRadiusMultiplier` | `1` | Rayon empêchant de construire près des ressources |
| `TribeNameChangeCooldown` | `15` | Jours avant de pouvoir renommer sa tribu |
| `PlatformSaddleBuildAreaBoundsMultiplier` | `1` | Zone constructible sur plateformes/selles |
| `AlwaysAllowStructurePickup` | `True` | Autorise toujours le ramassage de structures |
| `StructurePickupTimeAfterPlacement` | `30` | Secondes pendant lesquelles une structure reste ramassable |
| `StructurePickupHoldDuration` | `0.5` | Secondes de maintien du clic pour ramasser |
| `AllowHideDamageSourceFromLogs` | `True` | Masque la source des dégâts dans les logs |
| `RaidDinoCharacterFoodDrainMultiplier` | `1` | Multiplicateur de faim des dinos en raid |
| `PvEDinoDecayPeriodMultiplier` | `1` | Vitesse de décomposition des dinos PvE non réclamés |
| `KickIdlePlayersPeriod` | `3600` | Secondes avant expulsion d'un joueur inactif |
| `PerPlatformMaxStructuresMultiplier` | `1` | Multiplicateur du nombre max de structures par plateforme |
| `AutoSavePeriodMinutes` | `30` | Minutes entre deux sauvegardes automatiques |
| `MaxTamedDinos_SoftTameLimit` | `5000` | Limite douce de dinos apprivoisés |
| `MaxTamedDinos_SoftTameLimit_CountdownForDeletionDuration` | `604800` | Secondes avant suppression au-delà de la limite douce |
| `OverrideSecondsUntilBuriedTreasureAutoReveals` | `1209600` | Secondes avant révélation des trésors enterrés |
| `ItemStackSizeMultiplier` | `1` | Multiplicateur de taille de pile d'objets |
| `RCONServerGameLogBuffer` | `600` | Taille du tampon de journal RCON |
| `ImplantSuicideCD` | `28800` | Délai avant nouveau suicide par implant |
| `DisableCryopodFridgeRequirement` | `True` | Déploie/rappelle les dinos cryopodés sans Cryofridge à proximité |
| `AllowCryoFridgeOnSaddle` | `True` | Autorise à construire un Cryofridge sur une selle de plateforme (base mobile) |
| `DisableCryopodEnemyCheck` | `True` | Ignore la vérification de présence ennemie à l'usage des cryopods (surtout utile en PvP) |

**Événements saisonniers** — sur ARK: Survival Ascended, les événements saisonniers sont de vrais mods CurseForge publiés par `StudioWildcardMods`, pas un simple réglage. Chacun est ajouté automatiquement à `MODS` tant que la date du jour tombe dans sa période. `<NOM>_DATE` accepte une plage `MM/JJ-MM/JJ`, qui peut traverser le 1er janvier (ex. Winter Wonderland) ; mettre `<NOM>=False` pour désactiver un événement.

| Variable | Défaut | ID du mod | Plage de dates par défaut |
|---|---|---|---|
| `LOVE_ASCENDED` / `LOVE_ASCENDED_DATE` | `True` / `02/11-02/18` | `927084` | Dates officielles 2026 |
| `EGGCELLENT_ADVENTURE` / `EGGCELLENT_ADVENTURE_DATE` | `True` / `03/31-04/14` | `877745` | Dates officielles 2026 |
| `SUMMER_BASH` / `SUMMER_BASH_DATE` | `True` / `07/01-07/21` | `927091` | Approximative — à ajuster une fois les dates officielles connues |
| `FEAR_ASCENDED` / `FEAR_ASCENDED_DATE` | `True` / `10/01-10/31` | `877752` | Approximative — à ajuster une fois les dates officielles connues |
| `TURKEY_TRIAL` / `TURKEY_TRIAL_DATE` | `True` / `11/20-11/30` | `927083` | Approximative — à ajuster une fois les dates officielles connues |
| `WINTER_WONDERLAND` / `WINTER_WONDERLAND_DATE` | `True` / `12/10-01/10` | `927090` | Approximative — à ajuster une fois les dates officielles connues |

### Volumes

| Volume hôte | Chemin conteneur | Contenu |
|---|---|---|
| `~/volumes/ASA/filesServer` | `/home/steam/asa_server` | Fichiers du serveur (installés/mis à jour par SteamCMD) |
| `~/volumes/ASA/logs` | `/home/steam/asa_server/ShooterGame/Saved/Logs` | Journaux du serveur |
| `~/volumes/ASA/cluster-shared` | `.../Binaries/Win64/cluster-shared` | Données de cluster partagées entre cartes |
| `~/volumes/ASA-proton/steam` | `/home/steam/Steam` | Dossier Steam utilisé par Proton |
| `~/volumes/ASA-proton/proton-prefix` | `/home/steam/proton-prefix` | Préfixe Proton/Wine |
| `~/volumes/steamcmd` | `/home/steam/steamcmd` | SteamCMD, partagé avec tous les autres serveurs de jeux |

### Ports

| Port | Protocole | Usage |
|---|---|---|
| `7777` (hôte : `${jeux1}`) | UDP | Port de jeu (connexion des joueurs via le navigateur de serveurs ARK) |
| `27020` (hôte : `${rcon}`) | TCP | RCON (administration à distance) |
