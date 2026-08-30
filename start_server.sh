#!/bin/bash
set -e

# Script de lancement 100% maison : SteamCMD, Proton et le binaire du jeu
# sont pilotés directement ici, sans passer par le wrapper d'une image toute
# faite. Le "${VARIABLE:-valeur}" veut dire : utiliser VARIABLE si elle est
# définie, sinon utiliser "valeur" par défaut.

# ── 1. Ajustement UID/GID ──────────────────────────────────────────────────
USER_ID=${PUID:-1000}
GROUP_ID=${PGID:-1000}

echo "Ajustement de l'utilisateur steam vers UID: $USER_ID et GID: $GROUP_ID..."
groupmod -g $GROUP_ID steam
usermod -u $USER_ID -g $GROUP_ID steam

# On ne chowne que les dossiers qui ont réellement besoin d'être modifiables
# par "steam" (les volumes montés) — jamais tout /home/steam/, qui contient
# aussi Proton (plusieurs milliers de fichiers, déjà lisibles/exécutables
# par tous) : un chown -R dessus à chaque démarrage est inutile et lent.
chown -R steam:steam ${SERVER_DIR} 2>/dev/null || true
chown -R steam:steam /home/steam/proton-prefix 2>/dev/null || true
chown -R steam:steam /home/steam/Steam 2>/dev/null || true
chown -R steam:steam /home/steam/steamcmd 2>/dev/null || true

# ── 2. Mise à jour via SteamCMD (App ID 2430930 = serveur dédié ASA) ────────
BINAIRE="${SERVER_DIR}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe"
if [ "$UPDATE_ON_START" = "true" ] || [ ! -f "$BINAIRE" ]; then
    echo "--- Mise à jour du serveur ARK: Survival Ascended (App: 2430930) ---"
    for i in 1 2 3; do
        gosu steam /home/steam/steamcmd/steamcmd.sh \
            +force_install_dir ${SERVER_DIR} \
            +login anonymous \
            +app_update 2430930 validate \
            +quit && break
        echo "--- Tentative $i échouée, nouvel essai dans 10s ---"
        sleep 10
    done
    # Évite un plantage connu au démarrage lié à cette DLL Steamworks 64-bit
    # livrée avec le dépôt mais incompatible avec l'exécution sous Proton.
    rm -f "${SERVER_DIR}/ShooterGame/Binaries/Win64/steamclient64.dll"
else
    echo "--- Saut de la mise à jour (UPDATE_ON_START=false) ---"
fi

mkdir -p "${SERVER_DIR}/ShooterGame/Binaries/Win64/cluster-shared"
chown -R steam:steam "${SERVER_DIR}/ShooterGame/Binaries/Win64/cluster-shared"

# ── 3. Préparation de l'environnement Proton ────────────────────────────────
export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/steam/Steam"
export STEAM_COMPAT_DATA_PATH="/home/steam/proton-prefix"
export XDG_RUNTIME_DIR="/run/user/$(id -u steam)"
mkdir -p "$XDG_RUNTIME_DIR" "$STEAM_COMPAT_DATA_PATH" "$STEAM_COMPAT_CLIENT_INSTALL_PATH"
chown -R steam:steam "$XDG_RUNTIME_DIR" "$STEAM_COMPAT_DATA_PATH" "$STEAM_COMPAT_CLIENT_INSTALL_PATH"

# Machine ID fixe : évite un avertissement bloquant de Proton dans les
# conteneurs qui n'ont pas de /etc/machine-id persistant.
[ -s /etc/machine-id ] || echo "d5b7b5ed-1674-497d-ad98-7437a6543312" > /etc/machine-id

# Écran virtuel : le moteur Unreal Engine tente d'initialiser un contexte
# graphique même en mode serveur dédié et plante (segfault) sans affichage
# disponible, y compris sous Proton.
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1024x768x16 &
export DISPLAY=:99
until [ -e /tmp/.X11-unix/X99 ]; do sleep 0.5; done

# ── 4. Construction des paramètres de lancement ARK ─────────────────────────
# Partie "réglages de partie" (map, difficulté, multiplicateurs...) de
# ASA_START_PARAMS, séparée par des "?" comme l'exige ARK.
construire_parametres_partie() {
    local parametres=(
        "${map:-Valguero_WP}?listen"
        "ServerPassword=${ASA_SERVER_PASSWORD}"
        "Port=${GAME_PORT}"
        "RCONPort=${RCONPort}"
        "RCONEnabled=True"
        "SessionName=${SessionName:-Ludix_ASA_FR}"
        "ServerPVE=${ServerPVE:-True}"
        "ShowFloatingDamageText=${ShowFloatingDamageText:-True}"
        "XPMultiplier=${XPMultiplier:-2.0}"
        "DifficultyOffset=${DifficultyOffset:-10}"
        "OverrideOfficialDifficulty=${OverrideOfficialDifficulty:-10}"
        "DinoDamageMultiplier=${DinoDamageMultiplier:-1.0}"
        "TamingSpeedMultiplier=${TamingSpeedMultiplier:-5.0}"
        "HarvestAmountMultiplier=${HarvestAmountMultiplier:-1.0}"
        "StructureResistanceMultiplier=${StructureResistanceMultiplier:-1.0}"
        "AllowHitMarkers=${AllowHitMarkers:-True}"
        "bPreventCrosshair=${bPreventCrosshair:-True}"
        "bPreventHitMarkers=${bPreventHitMarkers:-True}"
        "EggHatchSpeedMultiplier=${EggHatchSpeedMultiplier:-10.0}"
        "BabyMatureSpeedMultiplier=${BabyMatureSpeedMultiplier:-10.0}"
        "BabyCuddleIntervalMultiplier=${BabyCuddleIntervalMultiplier:-0.5}"
        "DinoCountMultiplier=${DinoCountMultiplier:-2.0}"
        "AllowFlyerCarryPvE=${AllowFlyerCarryPvE:-True}"
        "MaxTamedDinos=${MaxTamedDinos:-5000}"
        "ShowMapPlayerLocation=${ShowMapPlayerLocation:-True}"
        "AllowThirdPersonPlayer=${AllowThirdPersonPlayer:-True}"
        "ServerCrosshair=${ServerCrosshair:-True}"
        "TheMaxStructuresInRange=${TheMaxStructuresInRange:-10500}"
        "StartTimeHour=${StartTimeHour:--1}"
        "OxygenSwimSpeedStatMultiplier=${OxygenSwimSpeedStatMultiplier:-1}"
        "StructurePreventResourceRadiusMultiplier=${StructurePreventResourceRadiusMultiplier:-1}"
        "TribeNameChangeCooldown=${TribeNameChangeCooldown:-15}"
        "PlatformSaddleBuildAreaBoundsMultiplier=${PlatformSaddleBuildAreaBoundsMultiplier:-1}"
        "AlwaysAllowStructurePickup=${AlwaysAllowStructurePickup:-True}"
        "StructurePickupTimeAfterPlacement=${StructurePickupTimeAfterPlacement:-30}"
        "StructurePickupHoldDuration=${StructurePickupHoldDuration:-0.5}"
        "AllowHideDamageSourceFromLogs=${AllowHideDamageSourceFromLogs:-True}"
        "RaidDinoCharacterFoodDrainMultiplier=${RaidDinoCharacterFoodDrainMultiplier:-1}"
        "PvEDinoDecayPeriodMultiplier=${PvEDinoDecayPeriodMultiplier:-1}"
        "KickIdlePlayersPeriod=${KickIdlePlayersPeriod:-3600}"
        "PerPlatformMaxStructuresMultiplier=${PerPlatformMaxStructuresMultiplier:-1}"
        "AutoSavePeriodMinutes=${AutoSavePeriodMinutes:-30}"
        "MaxTamedDinos_SoftTameLimit=${MaxTamedDinos_SoftTameLimit:-5000}"
        "MaxTamedDinos_SoftTameLimit_CountdownForDeletionDuration=${MaxTamedDinos_SoftTameLimit_CountdownForDeletionDuration:-604800}"
        "OverrideSecondsUntilBuriedTreasureAutoReveals=${OverrideSecondsUntilBuriedTreasureAutoReveals:-1209600}"
        "ItemStackSizeMultiplier=${ItemStackSizeMultiplier:-1}"
        "RCONServerGameLogBuffer=${RCONServerGameLogBuffer:-600}"
        "ImplantSuicideCD=${ImplantSuicideCD:-28800}"
    )
    local IFS='?'
    echo "${parametres[*]}"
}

# Écrit (ou met à jour) une clé=valeur sous une section [Section] d'un fichier
# .ini, en créant le fichier/la section si besoin. Idempotent : relancer le
# conteneur remet juste la même valeur, ça ne duplique jamais la ligne.
appliquer_reglage_ini() {
    local fichier="$1" section="$2" cle="$3" valeur="$4"
    mkdir -p "$(dirname "$fichier")"
    touch "$fichier"
    if ! grep -q "^\[${section}\]" "$fichier"; then
        printf '\n[%s]\n' "$section" >> "$fichier"
    fi
    if grep -q "^${cle}=" "$fichier"; then
        sed -i "s|^${cle}=.*|${cle}=${valeur}|" "$fichier"
    else
        # Délimiteur "|" (pas "/") pour l'adresse : certaines sections ARK
        # (ex: Game.ini) contiennent des "/" dans leur nom.
        sed -i "\\|^\\[${section}\\]|a ${cle}=${valeur}" "$fichier"
    fi
}

# Réglages Cryopod : contrairement aux paramètres de "construire_parametres_partie"
# ci-dessus (passés en "?clé=valeur" au lancement), ARK ne lit PAS ces trois-là
# depuis la ligne de commande — ils doivent être écrits en dur dans
# GameUserSettings.ini, section [ServerSettings], avant de lancer le jeu.
appliquer_reglages_cryopod() {
    local ini="${SERVER_DIR}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"
    appliquer_reglage_ini "$ini" "ServerSettings" "DisableCryopodFridgeRequirement" "${DisableCryopodFridgeRequirement:-True}"
    appliquer_reglage_ini "$ini" "ServerSettings" "AllowCryoFridgeOnSaddle" "${AllowCryoFridgeOnSaddle:-True}"
    appliquer_reglage_ini "$ini" "ServerSettings" "DisableCryopodEnemyCheck" "${DisableCryopodEnemyCheck:-True}"
    chown steam:steam "$ini"
}

# Réglages Game.ini : autre fichier que GameUserSettings.ini, absent des
# paramètres de lancement classiques ("?clé=valeur"/-options) — friendly fire,
# XP détaillée par activité, bascules apprivoisement/monte/reproduction.
appliquer_reglages_game_ini() {
    local ini="${SERVER_DIR}/ShooterGame/Saved/Config/WindowsServer/Game.ini"
    local section="/script/shootergame.shootergamemode"
    appliquer_reglage_ini "$ini" "$section" "bDisableFriendlyFire" "${bDisableFriendlyFire:-False}"
    appliquer_reglage_ini "$ini" "$section" "bPvEDisableFriendlyFire" "${bPvEDisableFriendlyFire:-False}"
    appliquer_reglage_ini "$ini" "$section" "bAutoPvETimer" "${bAutoPvETimer:-False}"
    appliquer_reglage_ini "$ini" "$section" "PreventOfflinePvPConnectionInvincibleInterval" "${PreventOfflinePvPConnectionInvincibleInterval:-5}"
    appliquer_reglage_ini "$ini" "$section" "GenericXPMultiplier" "${GenericXPMultiplier:-1.0}"
    appliquer_reglage_ini "$ini" "$section" "KillXPMultiplier" "${KillXPMultiplier:-1.0}"
    appliquer_reglage_ini "$ini" "$section" "CraftXPMultiplier" "${CraftXPMultiplier:-1.0}"
    appliquer_reglage_ini "$ini" "$section" "HarvestXPMultiplier" "${HarvestXPMultiplier:-1.0}"
    appliquer_reglage_ini "$ini" "$section" "bDisableDinoTaming" "${bDisableDinoTaming:-False}"
    appliquer_reglage_ini "$ini" "$section" "bDisableDinoRiding" "${bDisableDinoRiding:-False}"
    appliquer_reglage_ini "$ini" "$section" "bDisableDinoBreeding" "${bDisableDinoBreeding:-False}"
    chown steam:steam "$ini"
}

# Vrai si la date du jour tombe dans une plage "MM/JJ-MM/JJ" (gère aussi les
# plages qui traversent le 1er janvier, ex: Winter Wonderland décembre-janvier).
jour_dans_plage() {
    local plage="$1"
    [ -z "$plage" ] && return 1
    local debut="${plage%-*}"
    local fin="${plage#*-}"
    local jour_debut jour_fin jour_actuel
    jour_debut=$(date -d "2000-${debut/\//-}" +%j) || return 1
    jour_fin=$(date -d "2000-${fin/\//-}" +%j) || return 1
    jour_actuel=$(date +%j)
    jour_debut=$((10#$jour_debut))
    jour_fin=$((10#$jour_fin))
    jour_actuel=$((10#$jour_actuel))
    if [ "$jour_debut" -le "$jour_fin" ]; then
        [ "$jour_actuel" -ge "$jour_debut" ] && [ "$jour_actuel" -le "$jour_fin" ]
    else
        [ "$jour_actuel" -ge "$jour_debut" ] || [ "$jour_actuel" -le "$jour_fin" ]
    fi
}

# Événements saisonniers officiels ARK (mods CurseForge StudioWildcardMods),
# ajoutés automatiquement à MODS quand on est dans leur période — pilotés par
# les variables <NOM>/<NOM>_DATE définies dans docker-compose.yml.
construire_mods_evenements() {
    local evenements=(
        "LOVE_ASCENDED:927084"
        "EGGCELLENT_ADVENTURE:877745"
        "SUMMER_BASH:927091"
        "FEAR_ASCENDED:877752"
        "TURKEY_TRIAL:927083"
        "WINTER_WONDERLAND:927090"
    )
    local mods_evenements=""
    local entree nom_variable id_mod activee plage_var plage
    for entree in "${evenements[@]}"; do
        nom_variable="${entree%%:*}"
        id_mod="${entree##*:}"
        activee="${!nom_variable}"
        [ -z "$activee" ] && activee="True"
        plage_var="${nom_variable}_DATE"
        plage="${!plage_var}"
        if [ "$activee" = "True" ] && jour_dans_plage "$plage"; then
            mods_evenements="${mods_evenements:+$mods_evenements,}$id_mod"
        fi
    done
    echo "$mods_evenements"
}

# Correspondance entre nos noms de variables et le nom accepté par le
# paramètre -ActiveEvent= d'ARK (force la palette de couleurs saisonnière sur
# les dinos sauvages, indépendamment du mod CurseForge). Un seul actif à la
# fois : on s'arrête au premier événement trouvé dont <NOM>_COLORS=True et
# dont la date du jour tombe dans <NOM>_DATE.
#
# Renseigne EVENT_COULEUR_ACTUEL (nom pour -ActiveEvent=) et
# EVENT_COULEUR_NOM_VARIABLE (notre nom de variable, ex: WINTER_WONDERLAND)
# via des variables globales plutôt qu'un echo : cette fonction est aussi
# appelée sans "$(...)" pour retrouver <NOM>_DESTROY_WILD_DINOS plus loin, et
# "$(...)" exécuterait la fonction dans un sous-shell qui perdrait ces valeurs.
EVENT_COULEUR_ACTUEL=""
EVENT_COULEUR_NOM_VARIABLE=""
determiner_event_couleur_actif() {
    EVENT_COULEUR_ACTUEL=""
    EVENT_COULEUR_NOM_VARIABLE=""
    local evenements=(
        "LOVE_ASCENDED:LoveEvolved"
        "EGGCELLENT_ADVENTURE:Easter"
        "SUMMER_BASH:SummerBash"
        "FEAR_ASCENDED:FearEvolved"
        "TURKEY_TRIAL:TurkeyTrial"
        "WINTER_WONDERLAND:WinterWonderland"
    )
    local entree nom_variable nom_active_event activee_var activee plage_var plage
    for entree in "${evenements[@]}"; do
        nom_variable="${entree%%:*}"
        nom_active_event="${entree##*:}"
        activee_var="${nom_variable}_COLORS"
        activee="${!activee_var}"
        [ -z "$activee" ] && activee="True"
        plage_var="${nom_variable}_DATE"
        plage="${!plage_var}"
        if [ "$activee" = "True" ] && jour_dans_plage "$plage"; then
            EVENT_COULEUR_ACTUEL="$nom_active_event"
            EVENT_COULEUR_NOM_VARIABLE="$nom_variable"
            return
        fi
    done
}

# Client RCON minimal (protocole Source RCON, celui qu'utilise ARK) en Python,
# pour éviter d'installer un paquet supplémentaire dans l'image (python3 est
# déjà présent pour le lanceur de Proton). Usage : rcon_exec "DestroyWildDinos"
rcon_exec() {
    local commande="$1"
    python3 - "127.0.0.1" "${RCONPort}" "${ASA_ADMIN_PASSWORD}" "$commande" <<'EOF_PY'
import socket
import struct
import sys


def recevoir_tout(sock, taille):
    donnees = b""
    while len(donnees) < taille:
        morceau = sock.recv(taille - len(donnees))
        if not morceau:
            raise ConnectionError("connexion RCON fermée prématurément")
        donnees += morceau
    return donnees


def envoyer_paquet(sock, id_, type_, corps):
    charge = struct.pack("<ii", id_, type_) + corps.encode() + b"\x00\x00"
    sock.sendall(struct.pack("<i", len(charge)) + charge)


def lire_paquet(sock):
    taille = struct.unpack("<i", recevoir_tout(sock, 4))[0]
    charge = recevoir_tout(sock, taille)
    id_, type_ = struct.unpack("<ii", charge[:8])
    corps = charge[8:-2].decode(errors="replace")
    return id_, type_, corps


hote, port, mot_de_passe, commande = sys.argv[1:5]
sock = socket.create_connection((hote, int(port)), timeout=10)
envoyer_paquet(sock, 1, 3, mot_de_passe)
id_auth, _, _ = lire_paquet(sock)
if id_auth == -1:
    print("Authentification RCON refusée", file=sys.stderr)
    sys.exit(1)
envoyer_paquet(sock, 2, 2, commande)
_, _, reponse = lire_paquet(sock)
print(reponse)
EOF_PY
}

# Si l'événement couleur actif a <NOM>_DESTROY_WILD_DINOS=True, envoie
# "DestroyWildDinos" par RCON dès que celui-ci répond, pour renouveler
# immédiatement la couleur des dinos sauvages déjà présents sur la carte
# (sinon ils la gardent tant qu'ils ne meurent pas naturellement). Lancée en
# arrière-plan (voir plus bas) : ne doit jamais bloquer le démarrage du jeu.
detruire_dinos_sauvages_si_demande() {
    determiner_event_couleur_actif
    local nom_variable="$EVENT_COULEUR_NOM_VARIABLE"
    [ -z "$nom_variable" ] && return
    local destroy_var="${nom_variable}_DESTROY_WILD_DINOS"
    [ "${!destroy_var}" = "True" ] || return

    echo "--- ${EVENT_COULEUR_ACTUEL} actif avec DESTROY_WILD_DINOS=True : attente du RCON ---"
    local tentatives=60
    while [ $tentatives -gt 0 ]; do
        if (echo > "/dev/tcp/127.0.0.1/${RCONPort}") 2>/dev/null; then
            # Laisse le temps au monde de finir de spawner les dinos avant de
            # les détruire (le RCON répond parfois avant la fin du chargement).
            sleep 30
            echo "--- Envoi de DestroyWildDinos par RCON ---"
            rcon_exec "DestroyWildDinos"
            return
        fi
        sleep 5
        tentatives=$((tentatives - 1))
    done
    echo "--- RCON resté indisponible, DestroyWildDinos non envoyé ---" >&2
}

# Partie "options de lancement" (drapeaux -NoBattlEye, cluster, mods...) de
# ASA_START_PARAMS, séparée par des espaces.
construire_options_lancement() {
    local id_cluster="${CLUSTER_ID:-LudixASACluster}"
    # Le dossier cible existe déjà à côté du binaire (créé plus haut) — chemin
    # relatif, résolu sans ambiguïté par Proton par rapport au dossier courant.
    # ServerAdminPassword est ici (option "-", espace-séparée) et pas dans la
    # chaîne "?clé=valeur" de construire_parametres_partie : placé dans cette
    # dernière, son parseur avale tout ce qui suit dans la chaîne (bug connu
    # d'ARK), comme constaté dans GameUserSettings.ini réel du serveur.
    local options="-ServerAdminPassword=${ASA_ADMIN_PASSWORD} -WinLiveMaxPlayers=${MAX_PLAYERS} -log -ClusterDirOverride=cluster-shared -CLUSTER_ID=${id_cluster}"
    # Anti-triche BattlEye — piloté par la variable NoBattlEye (True/False)
    if [ "${NoBattlEye:-True}" = "True" ]; then
        options="$options -NoBattlEye"
    fi
    # Mods optionnels : liste d'identifiants CurseForge séparés par des virgules,
    # complétée automatiquement par les mods d'événements saisonniers en cours
    local mods_evenements="$(construire_mods_evenements)"
    local tous_mods="$MODS"
    if [ -n "$mods_evenements" ]; then
        tous_mods="${tous_mods:+$tous_mods,}$mods_evenements"
    fi
    if [ -n "$tous_mods" ]; then
        options="$options -mods=${tous_mods}"
    fi
    # Couleur d'événement saisonnier sur les dinos sauvages, indépendante du
    # mod CurseForge — pilotée par <NOM>_COLORS dans docker-compose.yml
    determiner_event_couleur_actif
    if [ -n "$EVENT_COULEUR_ACTUEL" ]; then
        options="$options -ActiveEvent=${EVENT_COULEUR_ACTUEL}"
    fi
    # Paramètres libres, ajoutés tels quels (voir EXTRA_PARAMS dans docker-compose.yml)
    if [ -n "$EXTRA_PARAMS" ]; then
        options="$options ${EXTRA_PARAMS}"
    fi
    echo "$options"
}

# Xalia (aide graphique/manette de Proton) tente d'ouvrir un affichage SDL
# propre et plante sans en trouver un — inutile sur un serveur dédié headless,
# on le désactive plutôt que de continuer à bricoler l'affichage virtuel.
# (Nom de variable vérifié dans le README source de Proton : PROTON_USE_XALIA,
# pas PROTON_DISABLE_XALIA qui n'existe pas et était donc ignorée.)
export PROTON_USE_XALIA=0

# ── 5. Lancement du serveur via Proton, avec ses logs relayés vers la
#      sortie du conteneur (docker compose logs) ────────────────────────────
cd "${SERVER_DIR}/ShooterGame/Binaries/Win64"

appliquer_reglages_cryopod
appliquer_reglages_game_ini

ASA_START_PARAMS="$(construire_parametres_partie) $(construire_options_lancement)"
echo "--- Lancement : ArkAscendedServer.exe ${ASA_START_PARAMS} ---"

# Pas de "exec" ici : on garde la main pour pouvoir relayer le fichier de
# log du jeu en plus de sa sortie standard directe (voir plus bas).
gosu steam "${PROTON_DIR}/proton" run ArkAscendedServer.exe ${ASA_START_PARAMS} &
GAME_PID=$!

# En arrière-plan, sans bloquer le démarrage du jeu : renouvelle les dinos
# sauvages par RCON si l'événement couleur actif le demande (voir
# détruire_dinos_sauvages_si_demande, pilotée par <NOM>_DESTROY_WILD_DINOS).
detruire_dinos_sauvages_si_demande &

# Relaie un arrêt propre du conteneur (docker compose down/stop) vers le
# vrai processus du jeu, plutôt que de le laisser être tué brutalement.
trap 'echo "--- Arrêt demandé, transmission au serveur ARK ---"; kill -TERM "$GAME_PID" 2>/dev/null' TERM INT

# Le jeu écrit l'essentiel de son journal dans ce fichier plutôt que sur sa
# sortie standard — on l'attend puis on le relaie dans "docker compose logs".
LOGFILE="${SERVER_DIR}/ShooterGame/Saved/Logs/ShooterGame.log"
echo "--- En attente du fichier de log ARK (${LOGFILE}) ---"
until [ -f "$LOGFILE" ]; do sleep 1; done
tail -n +1 -F "$LOGFILE" &
TAIL_PID=$!

set +e
wait "$GAME_PID"
EXIT_CODE=$?
set -e

kill "$TAIL_PID" 2>/dev/null
exit "$EXIT_CODE"
