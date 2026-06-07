###########################################################
# Dockerfile that builds a Project Zomboid Gameserver (x86_64)
# Built from scratch on Ubuntu 22.04
###########################################################
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies (SteamCMD 32-bit prerequisites and other utilities)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    dos2unix \
    locales \
    lib32gcc-s1 \
    lib32stdc++6 \
    libc6-i386 \
    && rm -rf /var/lib/apt/lists/*

# Generate locales to allow other languages in the PZ Server
RUN sed -i 's/^# *\(es_ES.UTF-8\)/\1/' /etc/locale.gen && \
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen

ENV STEAMAPPID=380870
ENV STEAMAPP=pz
ENV HOMEDIR=/home/steam
ENV STEAMAPPDIR="${HOMEDIR}/${STEAMAPP}-dedicated"
ENV STEAMCMDDIR="${HOMEDIR}/steamcmd"
ENV HOME="${HOMEDIR}"

# Create steam user
RUN useradd -m -s /bin/bash steam

# Setup steamcmd
WORKDIR ${HOMEDIR}

RUN mkdir -p "${STEAMCMDDIR}" && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -C "${STEAMCMDDIR}" -zxvf -

# Run steamcmd to update itself during build
RUN /home/steam/steamcmd/steamcmd.sh +quit || true

RUN chown -R steam:steam "${HOMEDIR}"

# Install Project Zomboid dedicated server as steam user
ARG STEAMAPPBRANCH="public"
ENV STEAMAPPBRANCH=$STEAMAPPBRANCH

RUN set -x && \
    mkdir -p "${STEAMAPPDIR}" && \
    chown -R steam:steam "${STEAMAPPDIR}" && \
    if [ -z "${STEAMAPPBRANCH}" ] || [ "${STEAMAPPBRANCH}" = "public" ]; then \
        su steam -c "${STEAMCMDDIR}/steamcmd.sh +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} validate +quit"; \
    else \
        su steam -c "${STEAMCMDDIR}/steamcmd.sh +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} -beta ${STEAMAPPBRANCH} validate +quit"; \
    fi

# Copy entry scripts
COPY --chown=steam:steam scripts/entry.sh /server/scripts/entry.sh
COPY --chown=steam:steam scripts/search_folder.sh /server/scripts/search_folder.sh
RUN chmod 550 /server/scripts/entry.sh /server/scripts/search_folder.sh

# Create required folders to keep their permissions on mount
RUN mkdir -p "${HOMEDIR}/Zomboid" && chown -R steam:steam "${HOMEDIR}/Zomboid"

WORKDIR ${HOMEDIR}

# Expose ports
EXPOSE 16261-16262/udp \
       8766-8767/udp \
       16262-16272/tcp \
       27015/tcp

ENTRYPOINT ["/server/scripts/entry.sh"]