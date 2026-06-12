# === STAGE 1: BUILDER ===
FROM arm64v8/ubuntu:25.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install builder dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    pkg-config \
    ccache \
    clang \
    llvm \
    lld \
    python3 python3-setuptools \
    squashfs-tools squashfuse \
    qt6-base-dev qt6-declarative-dev \
    libc-bin \
    nasm \
    curl \
    sudo \
    fuse3 \
    wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/fex
RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
    cd FEX && \
    mkdir Build && cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LINKER=lld \
    -DENABLE_LTO=True \
    -DBUILD_TESTS=False -G Ninja .. && \
    ninja install

# === STAGE 2: RUNNER ===
FROM arm64v8/ubuntu:25.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and configure locales
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsdl3-0 \
    libssl3t64 \
    squashfuse \
    libc-bin \
    curl \
    sudo \
    wget \
    vim \
    nano \
    tmux \
    binfmt-support \
    locales \
    jq \
    dos2unix \
    ca-certificates \
    gnupg \
    tar && \
    rm -rf /var/lib/apt/lists/*

# Generate locales
RUN sed -i 's/^# *\(es_ES.UTF-8\)/\1/' /etc/locale.gen && \
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen

# Copy the finished FEX binaries and trunks from the builder
COPY --from=builder /usr/bin/FEX* /usr/bin/
COPY --from=builder /usr/lib/fex-emu /usr/lib/fex-emu
COPY --from=builder /usr/share/fex-emu /usr/share/fex-emu

ENV STEAMAPPID=380870
ENV STEAMAPP=pz
ENV HOMEDIR=/home/steam
ENV STEAMAPPDIR="${HOMEDIR}/${STEAMAPP}-dedicated"
ENV STEAMCMDDIR="${HOMEDIR}/steamcmd"
ENV HOME="${HOMEDIR}"
ENV USE_SYSTEM_JAVA="false"

# Create steam user
RUN useradd -m -s /bin/bash steam

# Fetch FEX RootFS for x86_64 emulation directly
RUN mkdir -p /home/steam/.fex-emu/RootFS/Ubuntu_25_04 && \
    wget -O /tmp/Ubuntu_25_04.tar.gz "https://www.dropbox.com/scl/fi/na3t1pwu1f8hwemtescjd/Ubuntu_25_04.tar.gz?rlkey=vhnm1jeuh09z6406lptn5izrx&st=eo4w8s9q&dl=1" && \
    tar xpzf /tmp/Ubuntu_25_04.tar.gz -C /home/steam/.fex-emu/RootFS/Ubuntu_25_04/ && \
    rm /tmp/Ubuntu_25_04.tar.gz && \
    cp /etc/resolv.conf /home/steam/.fex-emu/RootFS/Ubuntu_25_04/etc/resolv.conf && \
    echo '{"Config":{"RootFS":"Ubuntu_25_04", "Server":"0"}}' > /home/steam/.fex-emu/Config.json && \
    chown -R steam:steam /home/steam/.fex-emu

RUN mkdir -p "${STEAMCMDDIR}" && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -C "${STEAMCMDDIR}" -zxvf -

# Create required folders to keep their permissions on mount
RUN mkdir -p "${HOMEDIR}/Zomboid" && \
    mkdir -p "${STEAMAPPDIR}" && \
    chown -R steam:steam "${HOMEDIR}" "${STEAMAPPDIR}"

# Copy entry scripts
COPY --chown=steam:steam scripts/entry.sh /server/scripts/entry.sh
COPY --chown=steam:steam scripts/search_folder.sh /server/scripts/search_folder.sh
COPY --chown=steam:steam scripts/pz-manage.sh /server/scripts/pz-manage.sh
RUN chmod 550 /server/scripts/entry.sh /server/scripts/search_folder.sh /server/scripts/pz-manage.sh && \
    ln -sf /server/scripts/pz-manage.sh /usr/local/bin/pz-manage

WORKDIR ${HOMEDIR}

# Expose ports
EXPOSE 16261-16262/udp \
       8766-8767/udp \
       16262-16272/tcp \
       27015/tcp

ENTRYPOINT ["/server/scripts/entry.sh"]