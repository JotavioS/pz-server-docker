###########################################################
# Stage 1: Build Box64 with Box32 support
###########################################################
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Compile box64 (64-bit emulator with experimental Box32 support)
# Use RPI4ARM64 target optimized for ARMv8 cores, enabling BOX32 and BOX32_BINFMT
RUN git clone --depth 1 https://github.com/ptitSeb/box64.git /box64 && \
    mkdir -p /box64/build && cd /box64/build && \
    cmake .. -DRPI4ARM64=1 -DBOX32=ON -DBOX32_BINFMT=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install DESTDIR=/tmp/install

###########################################################
# Stage 2: Final Image
###########################################################
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Copy compiled emulator (Box64 with Box32 support)
COPY --from=builder /tmp/install/usr/local/bin/box64 /usr/local/bin/box64

# Configure multiarch and install dependencies (including 32-bit ARM libraries for Box32)
RUN dpkg --add-architecture armhf && \
    dpkg --add-architecture amd64 && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list && \
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
    jq && \
    mkdir -p /tmp/x86_64-libs && \
    cd /tmp/x86_64-libs && \
    apt-get download libstdc++6:amd64 libgcc-s1:amd64 && \
    dpkg-deb -x libstdc++6*_amd64.deb . && \
    dpkg-deb -x libgcc-s1*_amd64.deb . && \
    mkdir -p /usr/lib/x86_64-linux-gnu && \
    cp -d usr/lib/x86_64-linux-gnu/libstdc++.so.6* /usr/lib/x86_64-linux-gnu/ && \
    cp -d usr/lib/x86_64-linux-gnu/libgcc_s.so.1* /usr/lib/x86_64-linux-gnu/ && \
    rm -rf /tmp/x86_64-libs /var/lib/apt/lists/*

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

# Set the environment variables for Box64, JVM and SteamCMD thread safety
ENV BOX64_JVM=1
ENV BOX64_DYNAREC_BIGBLOCK=0
ENV BOX64_DYNAREC_STRONGMEM=1
ENV LD_PRELOAD="libpthread.so.0"
ENV BOX64_LD_PRELOAD="libpthread.so.0"

# Create steam user
RUN useradd -m -s /bin/bash steam

# Setup steamcmd
WORKDIR ${HOMEDIR}

RUN mkdir -p "${STEAMCMDDIR}" && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -C "${STEAMCMDDIR}" -zxvf -

# Set the DEBUGGER env variable to use Box64 for executing SteamCMD
ENV DEBUGGER="/usr/local/bin/box64"

# Optimize box64 dynarec for steamcmd (thread safety and stability)
RUN printf '[steamcmd]\nBOX64_DYNAREC_BIGBLOCK=3\nBOX64_DYNAREC_CALLRET=2\nBOX64_DYNAREC_STRONGMEM=1\n\n' >> /etc/box64.box64rc

# Run steamcmd to update itself during build
RUN /home/steam/steamcmd/steamcmd.sh +quit || true

# Create required folders to keep their permissions on mount
RUN mkdir -p "${HOMEDIR}/Zomboid" && \
    mkdir -p "${STEAMAPPDIR}" && \
    chown -R steam:steam "${HOMEDIR}" "${STEAMAPPDIR}"

# Copy entry scripts
COPY --chown=steam:steam scripts/entry.sh /server/scripts/entry.sh
COPY --chown=steam:steam scripts/search_folder.sh /server/scripts/search_folder.sh
RUN chmod 550 /server/scripts/entry.sh /server/scripts/search_folder.sh

WORKDIR ${HOMEDIR}

# Expose ports
EXPOSE 16261-16262/udp \
       8766-8767/udp \
       16262-16272/tcp \
       27015/tcp

ENTRYPOINT ["/server/scripts/entry.sh"]
