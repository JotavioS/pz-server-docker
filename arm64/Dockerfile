# Stage 1: Base Image
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies, FEX-Emu and configure locales
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    wget \
    gnupg \
    ca-certificates \
    tar \
    dos2unix \
    locales \
    jq && \
    add-apt-repository -y ppa:fex-emu/fex && \
    apt-get update && \
    apt-get install -y fex-emu-armv8.0 && \
    rm -rf /var/lib/apt/lists/*

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
ENV USE_SYSTEM_JAVA="false"

# Create steam user
RUN useradd -m -s /bin/bash steam

# Fetch FEX RootFS for x86_64 emulation directly
RUN mkdir -p /home/steam/.fex-emu/RootFS && \
    wget -O /tmp/Ubuntu_22_04.tar.gz "https://www.dropbox.com/scl/fi/16mhn3jrwvzapdw50gt20/Ubuntu_22_04.tar.gz?rlkey=4m256iahwtcijkpzcv8abn7nf" && \
    tar xzf /tmp/Ubuntu_22_04.tar.gz -C /home/steam/.fex-emu/RootFS/ && \
    rm /tmp/Ubuntu_22_04.tar.gz && \
    echo '{"Config":{"RootFS":"Ubuntu_22_04"}}' > /home/steam/.fex-emu/Config.json && \
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