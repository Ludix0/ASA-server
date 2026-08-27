# CLAUDE.md — Projet ASA (ARK: Survival Ascended, serveur Docker)

Ce fichier documente ce que ce projet fait et pourquoi, pour reprendre le travail sans tout re-découvrir. Voir aussi [[infrastructure]] (réseau de Ludo) et le skill `server_game_docker` (conventions générales pour tous les serveurs de jeux de Ludo) — ce fichier ne répète que ce qui est **spécifique à ASA**.

## Quoi

Serveur dédié **ARK: Survival Ascended** dockerisé, construit sur `cm2network/steamcmd:root`, dans `~/projets/ASA/`. Suit la structure standard des serveurs de jeux de Ludo (`Dockerfile` / `docker-compose.yml` / `.env` symlink / `start_server.sh`), avec une particularité majeure : **ASA n'a pas de binaire Linux natif**, il faut Proton.

Fichiers du projet :
- `Dockerfile` — image + installation de Proton-GE au build
- `docker-compose.yml` — service `asa`, tagué `ludix0/asa:latest`, tous les réglages de gameplay ARK
- `start_server.sh` — SteamCMD, préparation Proton/Xvfb, construction des paramètres de lancement, lancement + relais des logs
- `.env` — lien symbolique vers `~/volumes/secrets/steam-account.env` (fichier partagé entre tous les projets de jeux, ne pas le recréer en dur)
- `README.md` — doc d'installation bilingue EN/FR (gabarit standard du skill `server_game_docker`)

Pas encore de dépôt Git ni de `description.txt` (le projet n'a pas encore été publié sur GitHub/Docker Hub — voir skill `publish_docker_project` si demandé).

## Pourquoi Proton (le point le plus important à ne pas oublier)

ARK: Survival Ascended tourne sur Unreal Engine 5. Le serveur dédié n'existe qu'en `.exe` Windows (`ArkAscendedServer.exe`). Ce projet :
1. installe **Proton-GE `GE-Proton11-5`** au moment du build (`ARG PROTON_VERSION`, à changer + rebuild pour mettre à jour) ;
2. lance le binaire via `${PROTON_DIR}/proton run ArkAscendedServer.exe ...` dans `start_server.sh`.

Conséquences directement dans le code, à ne pas "simplifier" sans comprendre pourquoi elles existent :
- **`Xvfb` obligatoire** : même en mode serveur dédié, l'UE5 tente d'initialiser un contexte DirectX 12 (traduit en Vulkan par Proton) et segfault sans affichage. `start_server.sh` lance `Xvfb :99` et attend que `/tmp/.X11-unix/X99` existe avant de démarrer le jeu (race condition sinon) ; supprime aussi `/tmp/.X99-lock` en début de script (sinon échec `Server is already active` après un `restart: unless-stopped`).
- **`mesa-vulkan-drivers` (lavapipe) obligatoire** : sans GPU dans le conteneur, il faut un pilote Vulkan *logiciel* pour que cette même initialisation DX12/Vulkan réussisse.
- **`winbind` obligatoire** : requis par Proton pour NTLM/EOS (Epic Online Services, utilisé par ASA).
- **`rm steamclient64.dll` après chaque update SteamCMD** : cette DLL 64-bit livrée avec le dépôt du jeu plante sous Proton — bug connu, la supprimer est la solution.
- **`PROTON_USE_XALIA=0`** : Xalia (aide manette/graphique de Proton) plante en cherchant un display SDL propre à elle ; inutile sur un serveur headless.
- **`/etc/machine-id` figé en dur** (`d5b7b5ed-...`) : évite un avertissement bloquant de Proton dans les conteneurs sans `/etc/machine-id` persistant.
- Le script ne fait **pas** `exec` sur le lancement du jeu (contrairement à la convention habituelle du skill) : il le lance en arrière-plan (`&`) pour pouvoir aussi `tail -F` le vrai fichier de log du jeu (`ShooterGame.log`, qu'ARK écrit à part de sa sortie standard) et le relayer dans `docker compose logs`. Le `trap TERM INT` transmet l'arrêt au process Proton/jeu.

## Décisions spécifiques à ce projet

- **App ID SteamCMD** : `2430930` (serveur dédié). Connexion anonyme (pas de `STEAM_USER`/`STEAM_PASSWORD` câblés — ASA fonctionne en anonyme).
- **Carte par défaut** : `Astraeos_WP`, session `Ludix_ASA_FR`, cluster `LudixASACluster`.
- **`NoBattlEye=True` par défaut** : BattlEye n'est pas fiable sous Proton/Linux et peut bloquer la connexion des joueurs — délibérément désactivé plutôt que "à corriger plus tard".
- **`UPDATE_ON_START=true`** : figé en dur dans `docker-compose.yml` (pas dans le `.env` partagé), comme pour tous les serveurs de jeux de Ludo — permet de le couper pour ce serveur précis sans affecter les autres.
- Ports hôte : `${jeux1}` (jeu, UDP) et `${rcon}` (RCON, TCP), tous deux issus du `.env` partagé (`~/volumes/secrets/steam-account.env`), pas de valeurs en dur.
- Réglages de gameplay (une quarantaine de variables : XP, taming, harvest, structures, etc.) tous câblés en valeurs fixes dans `docker-compose.yml`, commentés en français ligne par ligne — c'est la source de vérité, `README.md` en reprend la liste mais toute modification de valeur se fait dans `docker-compose.yml`.

## Cryopods hors base et événements saisonniers automatiques

- **Cryopods utilisables loin de la base** : trois réglages dans `docker-compose.yml`/`start_server.sh` — `DisableCryopodFridgeRequirement=True` (déploiement/rappel sans Cryofridge à proximité), `AllowCryoFridgeOnSaddle=True` (Cryofridge constructible sur une selle de plateforme — reste utile car un Cryofridge est toujours nécessaire pour **fabriquer/recharger** les cryopods, ce que `DisableCryopodFridgeRequirement` ne change pas), `DisableCryopodEnemyCheck=True` (ignore la présence ennemie à proximité — surtout utile en PvP, notre serveur étant en `ServerPVE=True`).

- **Événements saisonniers ajoutés automatiquement à `MODS`** : sur ASA (contrairement à l'ancien ASE), les événements (Winter Wonderland, Love Ascended, etc.) sont distribués comme de vrais mods CurseForge du studio `StudioWildcardMods` — pas de simple flag `-ActiveEvent=`. Dans `start_server.sh`, les fonctions `jour_dans_plage` et `construire_mods_evenements` comparent la date du jour aux variables `<NOM>_DATE=MM/JJ-MM/JJ` de `docker-compose.yml` et ajoutent l'ID CurseForge correspondant à `MODS` pendant la période, sans toucher aux mods perso de Ludo. Piloté par `<NOM>=True/False` + `<NOM>_DATE` pour chacun de :

  | Événement | ID CurseForge | Variable |
  |---|---|---|
  | Love Ascended | 927084 | `LOVE_ASCENDED` |
  | Eggcellent Adventure | 877745 | `EGGCELLENT_ADVENTURE` |
  | Summer Bash | 927091 | `SUMMER_BASH` |
  | Fear Ascended | 877752 | `FEAR_ASCENDED` |
  | Turkey Trial | 927083 | `TURKEY_TRIAL` |
  | Winter Wonderland | 927090 | `WINTER_WONDERLAND` |

  IDs vérifiés directement sur les pages CurseForge (2026-08-26). Pas de mod "Anniversary" trouvé sur CurseForge pour ASA — événement volontairement absent de la liste. Les dates par défaut sont approximatives (sauf Love Ascended et Eggcellent Adventure, dates officielles 2026 confirmées) — à corriger chaque année directement dans `docker-compose.yml`, pas dans le script.

- **Couleur d'événement indépendante du mod (`-ActiveEvent=`)** : le flag `-ActiveEvent=` existe bel et bien dans ASA, mais ne sert qu'à forcer la palette de couleurs saisonnière des dinos sauvages — un mécanisme plus léger et distinct des mods CurseForge ci-dessus (qui apportent le contenu complet : items, skins, engrammes). Chaque événement a donc en plus un interrupteur `<NOM>_COLORS=True/False` indépendant de `<NOM>` (le mod), pour pouvoir activer/désactiver la couleur et le mod séparément selon ce que Ludo veut. Dans `start_server.sh`, `determiner_event_couleur_actif` réutilise `jour_dans_plage` sur la même variable `<NOM>_DATE` et s'arrête au premier événement trouvé (un seul `-ActiveEvent=` possible à la fois), en renseignant les globales `EVENT_COULEUR_ACTUEL`/`EVENT_COULEUR_NOM_VARIABLE` (pas un `echo` capturé par `$(...)`, qui tournerait dans un sous-shell et perdrait ces valeurs pour l'appel suivant) ; la correspondance nom-interne → nom accepté par ARK (ex. `LOVE_ASCENDED` → `LoveEvolved`, `EGGCELLENT_ADVENTURE` → `Easter`) est codée dans cette fonction.

- **Renouvellement automatique des dinos sauvages (`<NOM>_DESTROY_WILD_DINOS`)** : les dinos sauvages déjà spawnés gardent leur ancienne couleur tant qu'ils ne meurent pas — renouvellement sinon uniquement progressif, au rythme de la chasse des joueurs. `<NOM>_DESTROY_WILD_DINOS=True` (défaut `False`, car plus radical que les autres réglages : ça tue tous les dinos sauvages de la carte) déclenche l'envoi automatique de `DestroyWildDinos` par RCON dès que celui-ci répond après le démarrage du conteneur. Pas de client RCON tiers installé dans l'image : `rcon_exec()` dans `start_server.sh` embarque un client minimal du protocole Source RCON écrit en Python (réutilise le `python3` déjà présent pour le lanceur Proton), lancé via `detruire_dinos_sauvages_si_demande &` en arrière-plan juste après le lancement du jeu, pour ne jamais bloquer le démarrage. Un délai fixe de 30s après l'ouverture du port RCON est ajouté avant d'envoyer la commande, le temps que le monde finisse de spawner ses dinos sauvages (le RCON peut répondre avant la fin du chargement).

## Réseau (contexte [[infrastructure]])

Ce serveur appartient au réseau **Jeux vidéo** de Ludo (`192.168.3.0/24`), volontairement ouvert vers l'extérieur. Les ports `${jeux1}` et `${rcon}` sont donc potentiellement exposés à internet via pfSense — la sécurité de ce conteneur (pas de root, `BattlEye` mis à part) compte à ce titre. RCON en particulier ne doit jamais être exposé sans protection supplémentaire côté pare-feu si ce n'est pas déjà le cas.

## Nettoyage à faire si on retouche ce projet

- Un fichier de swap Vim résiduel traîne à la racine : `.docker-compose.yml.swp`. À supprimer avant toute publication Git (et à ajouter à `.gitignore` si ça se reproduit).
- Pas de `.gitignore` ni de dépôt Git pour l'instant — à créer avant tout `git init` (voir skill `publish_docker_project` : exclure `.env`, `*.env`, `.actif`, `description.txt`).

## Commandes de référence

```bash
docker compose build        # build l'image (grâce à build: . dans docker-compose.yml)
docker compose up -d        # démarre le serveur
docker compose logs -f      # logs en direct (relayés depuis ShooterGame.log)
docker compose down         # arrêt propre
```

Ne jamais exécuter ces commandes à la place de Ludo sans qu'il le demande — il gère lui-même son infrastructure.
