###########################################################
# Stage 1: Build Box86 and Box64
###########################################################
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    ca-certificates \
    python3 \
    gcc-arm-linux-gnueabihf \
    libc6-dev-armhf-cross \
    && rm -rf /var/lib/apt/lists/*

# Compile box86 (32-bit emulator)
# Use RPI4ARM64 target which automatically sets up gcc-arm-linux-gnueabihf cross-compilation for ARM64 hosts
RUN git clone --depth 1 https://github.com/ptitSeb/box86.git /box86 && \
    mkdir -p /box86/build && cd /box86/build && \
    cmake .. -DRPI4ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install DESTDIR=/tmp/install

# Compile box64 (64-bit emulator)
# Use RPI4ARM64 target optimized for ARMv8 cores
RUN git clone --depth 1 https://github.com/ptitSeb/box64.git /box64 && \
    mkdir -p /box64/build && cd /box64/build && \
    cmake .. -DRPI4ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install DESTDIR=/tmp/install

###########################################################
# Stage 2: Final Image
###########################################################
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Copy compiled emulators
COPY --from=builder /tmp/install/usr/local/bin/box86 /usr/local/bin/box86
COPY --from=builder /tmp/install/usr/local/bin/box64 /usr/local/bin/box64

# Configure multiarch and install dependencies (including 32-bit libraries for box86)
RUN dpkg --add-architecture armhf && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    dos2unix \
    locales \
    libc6:armhf \
    libncurses5:armhf \
    libstdc++6:armhf \
    && rm -rf /var/lib/apt/lists/*

# Generate locales
RUN sed -i 's/^# *\(es_ES.UTF-8\)/\1/' /etc/locale.gen && \
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen

ENV STEAMAPPID=380870
ENV STEAMAPP=pz
ENV HOMEDIR=/home/steam
ENV STEAMAPPDIR="${HOMEDIR}/${STEAMAPP}-dedicated"
ENV STEAMCMDDIR="${HOMEDIR}/steamcmd"
ENV HOME="${HOMEDIR}"

# Set the environment variables for Box64 and JVM
ENV BOX64_JVM=1
ENV BOX64_DYNAREC_BIGBLOCK=0
ENV BOX64_DYNAREC_STRONGMEM=1

# Create steam user
RUN useradd -m -s /bin/bash steam

# Setup steamcmd
WORKDIR ${HOMEDIR}

RUN mkdir -p "${STEAMCMDDIR}" && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -C "${STEAMCMDDIR}" -zxvf -

# Create wrapper for SteamCMD before we run it during build
RUN mkdir -p "${STEAMCMDDIR}/linux32" && \
    touch "${STEAMCMDDIR}/linux32/steamcmd" && \
    mv "${STEAMCMDDIR}/linux32/steamcmd" "${STEAMCMDDIR}/linux32/steamcmd.real" || true && \
    echo -e '#!/bin/bash\nexec /usr/local/bin/box86 /home/steam/steamcmd/linux32/steamcmd.real "$@"' > "${STEAMCMDDIR}/linux32/steamcmd" && \
    chmod +x "${STEAMCMDDIR}/linux32/steamcmd"

# Run steamcmd to update itself
RUN /home/steam/steamcmd/steamcmd.sh +quit || true

# Restore SteamCMD wrapper if overwritten by update
RUN if [ -f "${STEAMCMDDIR}/linux32/steamcmd" ] && [ ! -f "${STEAMCMDDIR}/linux32/steamcmd.real" ]; then \
        mv "${STEAMCMDDIR}/linux32/steamcmd" "${STEAMCMDDIR}/linux32/steamcmd.real" && \
        echo -e '#!/bin/bash\nexec /usr/local/bin/box86 /home/steam/steamcmd/linux32/steamcmd.real "$@"' > "${STEAMCMDDIR}/linux32/steamcmd" && \
        chmod +x "${STEAMCMDDIR}/linux32/steamcmd"; \
    fi

RUN chown -R steam:steam "${HOMEDIR}"

# Install Project Zomboid dedicated server as steam user
ARG STEAMAPPBRANCH="public"
ENV STEAMAPPBRANCH=$STEAMAPPBRANCH

RUN set -x && \
    mkdir -p "${STEAMAPPDIR}" && \
    chown -R steam:steam "${STEAMAPPDIR}" && \
    if [ -z "${STEAMAPPBRANCH}" ] || [ "${STEAMAPPBRANCH}" = "public" ]; then \
        su steam -c "/usr/local/bin/box86 ${STEAMCMDDIR}/linux32/steamcmd.real +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} validate +quit"; \
    else \
        su steam -c "/usr/local/bin/box86 ${STEAMCMDDIR}/linux32/steamcmd.real +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} -beta ${STEAMAPPBRANCH} validate +quit"; \
    fi

# Copy entry scripts
COPY --chown=steam:steam scripts/entry.sh /server/scripts/entry.sh
COPY --chown=steam:steam scripts/search_folder.sh /server/scripts/search_folder.sh
RUN chmod 550 /server/scripts/entry.sh /server/scripts/search_folder.sh

# Setup Java wrapper for Box64 before runtime
RUN if [ -f "${STEAMAPPDIR}/jre64/bin/java" ]; then \
        mv "${STEAMAPPDIR}/jre64/bin/java" "${STEAMAPPDIR}/jre64/bin/java.real" && \
        echo -e '#!/bin/bash\nexport BOX64_JVM=1\nexport BOX64_DYNAREC_BIGBLOCK=0\nexport BOX64_DYNAREC_STRONGMEM=1\nexport LD_LIBRARY_PATH="/home/steam/pz-dedicated/linux64:/home/steam/pz-dedicated/natives:/home/steam/pz-dedicated/jre64/lib:${LD_LIBRARY_PATH}"\nexec /usr/local/bin/box64 /home/steam/pz-dedicated/jre64/bin/java.real "$@"' > "${STEAMAPPDIR}/jre64/bin/java" && \
        chmod +x "${STEAMAPPDIR}/jre64/bin/java" && \
        chown steam:steam "${STEAMAPPDIR}/jre64/bin/java"; \
    fi

# Create Zomboid data folder
RUN mkdir -p "${HOMEDIR}/Zomboid" && chown -R steam:steam "${HOMEDIR}/Zomboid"

WORKDIR ${HOMEDIR}

EXPOSE 16261-16262/udp \
       8766-8767/udp \
       16262-16272/tcp \
       27015/tcp

ENTRYPOINT ["/server/scripts/entry.sh"]
