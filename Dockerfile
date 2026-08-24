# Base Debian avec SteamCMD et les libs 32-bit déjà présentes (lib32gcc-s1,
# lib32stdc++6, architecture i386 activée) — ne pas les réinstaller.
FROM cm2network/steamcmd:root

# ARK: Survival Ascended n'a PAS de binaire serveur Linux natif (seuls des
# fichiers Steamworks le sont) : le vrai binaire est un .exe Windows
# (ArkAscendedServer.exe). Proton l'exécute sous Linux. Cette image ne
# contient QUE Proton en plus de la base SteamCMD — tout le reste
# (téléchargement du serveur, paramètres, lancement) est dans start_server.sh,
# écrit et contrôlé par nous, pas par une image tierce toute faite.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gosu \
    wget \
    ca-certificates \
    xvfb \
    xauth \
    winbind \
    libvulkan1 \
    libgl1 \
    # Le jeu (Unreal Engine 5) tente d'initialiser un périphérique DirectX 12
    # même en mode serveur dédié (traduit en Vulkan par Proton). Sans GPU dans
    # le conteneur, il faut un pilote Vulkan LOGICIEL (lavapipe) pour que
    # cette initialisation réussisse — sinon le jeu plante immédiatement
    # (EXCEPTION_ACCESS_VIOLATION dans dxgi.dll/d3d12.dll).
    mesa-vulkan-drivers \
    # Le lanceur "proton" de GE-Proton est un script Python, pas un binaire :
    # Python 3 doit être présent dans l'image pour pouvoir l'exécuter.
    python3 \
    && rm -rf /var/lib/apt/lists/*

ENV SERVER_DIR="/home/steam/asa_server"
ENV PROTON_DIR="/home/steam/proton"
# Version de Proton-GE (build de GloriousEggroll, compatibilité Windows
# renforcée par rapport au Proton officiel de Valve). Changer cette valeur
# et relancer "docker compose build" pour mettre à jour Proton.
ARG PROTON_VERSION="GE-Proton11-5"

# Téléchargée et installée une seule fois au moment du build de l'image
# (pas à chaque démarrage du conteneur).
RUN mkdir -p ${PROTON_DIR} && \
    wget -q "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}-x86_64.tar.gz" -O /tmp/proton.tar.gz && \
    tar -xzf /tmp/proton.tar.gz -C ${PROTON_DIR} --strip-components=1 && \
    rm /tmp/proton.tar.gz

COPY --chown=steam:steam start_server.sh /home/steam/start_server.sh
RUN chmod +x /home/steam/start_server.sh

WORKDIR /home/steam

# Ports officiels du jeu (documentation uniquement — c'est docker-compose qui publie)
EXPOSE 7777/udp 27020/tcp

ENTRYPOINT ["/home/steam/start_server.sh"]
