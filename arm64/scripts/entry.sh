#!/bin/bash

# Fix permissions on mounted volumes before running SteamCMD or starting the server
echo "Fixing permissions on mounted volumes..."
chown -R steam:steam /home/steam/pz-dedicated /home/steam/Zomboid /home/steam/pz-dedicated/steamapps/workshop || true
chmod 755 /home/steam/pz-dedicated /home/steam/Zomboid || true

cd ${STEAMAPPDIR}

# Ensure Java box64 wrapper is in place (self-healing)
if [ -f "${STEAMAPPDIR}/jre64/bin/java" ] && [ "$(head -c 2 "${STEAMAPPDIR}/jre64/bin/java")" != "#!" ]; then
  echo "Restoring Java box64 wrapper..."
  mv "${STEAMAPPDIR}/jre64/bin/java" "${STEAMAPPDIR}/jre64/bin/java.real"
  cat << 'EOF' > "${STEAMAPPDIR}/jre64/bin/java"
#!/bin/bash
export BOX64_JVM=1
export BOX64_DYNAREC_BIGBLOCK=0
export BOX64_DYNAREC_STRONGMEM=1
export LD_LIBRARY_PATH="/home/steam/pz-dedicated:/home/steam/pz-dedicated/linux64:/home/steam/pz-dedicated/natives:/home/steam/pz-dedicated/jre64/lib:/home/steam/pz-dedicated/jre64/lib/server:${LD_LIBRARY_PATH}"
exec /usr/local/bin/box64 /home/steam/pz-dedicated/jre64/bin/java.real "$@"
EOF
  chmod +x "${STEAMAPPDIR}/jre64/bin/java"
  chown steam:steam "${STEAMAPPDIR}/jre64/bin/java"
fi

# Ensure ProjectZomboid64 box64 wrapper is in place (self-healing)
if [ -f "${STEAMAPPDIR}/ProjectZomboid64" ] && [ "$(head -c 2 "${STEAMAPPDIR}/ProjectZomboid64")" != "#!" ]; then
  echo "Restoring ProjectZomboid64 box64 wrapper..."
  mv "${STEAMAPPDIR}/ProjectZomboid64" "${STEAMAPPDIR}/ProjectZomboid64.real"
  cat << 'EOF' > "${STEAMAPPDIR}/ProjectZomboid64"
#!/bin/bash
JSON_FILE="/home/steam/pz-dedicated/ProjectZomboid64.json"
if [ -f "${JSON_FILE}" ] && command -v jq >/dev/null 2>&1; then
  CLASSPATH=$(jq -r '.classpath | join(":")' "${JSON_FILE}")
  MAINCLASS=$(jq -r '.mainClass' "${JSON_FILE}" | tr '/' '.')
  readarray -t VM_ARGS < <(jq -r '.vmArgs[]' "${JSON_FILE}")
else
  CLASSPATH="java/:java/projectzomboid.jar"
  MAINCLASS="zombie.network.GameServer"
  VM_ARGS=("-Xms16g" "-Xmx16g" "-Dzomboid.steam=1" "-Dzomboid.znetlog=1" "-Djava.library.path=linux64/:natives/")
fi

JVM_ARGS=()
APP_ARGS=()
in_app_args=false
for arg in "$@"; do
  if [ "$arg" = "--" ]; then
    in_app_args=true
    continue
  fi
  if [ "$in_app_args" = true ]; then
    APP_ARGS+=("$arg")
  else
    JVM_ARGS+=("$arg")
  fi
done

exec /home/steam/pz-dedicated/jre64/bin/java "${VM_ARGS[@]}" "${JVM_ARGS[@]}" -cp "${CLASSPATH}" "${MAINCLASS}" "${APP_ARGS[@]}"
EOF
  chmod +x "${STEAMAPPDIR}/ProjectZomboid64"
  chown steam:steam "${STEAMAPPDIR}/ProjectZomboid64"
fi

# If the server files do not exist, or if FORCEUPDATE is set, install/update the game
if [ ! -f "${STEAMAPPDIR}/start-server.sh" ] || [ "${FORCEUPDATE}" == "1" ] || [ "${FORCEUPDATE,,}" == "true" ]; then
  echo "Installing or updating Project Zomboid Dedicated Server..."
  if [ -z "${STEAMAPPBRANCH}" ] || [ "${STEAMAPPBRANCH}" = "public" ]; then
    su steam -c "export DEBUGGER=/usr/local/bin/box64 && ${STEAMCMDDIR}/steamcmd.sh +@sSteamCmdForcePlatformType linux +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} validate +quit"
  else
    su steam -c "export DEBUGGER=/usr/local/bin/box64 && ${STEAMCMDDIR}/steamcmd.sh +@sSteamCmdForcePlatformType linux +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} -beta ${STEAMAPPBRANCH} validate +quit"
  fi
  
  # Check and restore Java wrapper if it got overwritten or is missing after update/install
  if [ -f "${STEAMAPPDIR}/jre64/bin/java" ] && [ "$(head -c 2 "${STEAMAPPDIR}/jre64/bin/java")" != "#!" ]; then
    echo "Restoring Java box64 wrapper after installation..."
    mv "${STEAMAPPDIR}/jre64/bin/java" "${STEAMAPPDIR}/jre64/bin/java.real"
    cat << 'EOF' > "${STEAMAPPDIR}/jre64/bin/java"
#!/bin/bash
export BOX64_JVM=1
export BOX64_DYNAREC_BIGBLOCK=0
export BOX64_DYNAREC_STRONGMEM=1
export LD_LIBRARY_PATH="/home/steam/pz-dedicated:/home/steam/pz-dedicated/linux64:/home/steam/pz-dedicated/natives:/home/steam/pz-dedicated/jre64/lib:/home/steam/pz-dedicated/jre64/lib/server:${LD_LIBRARY_PATH}"
exec /usr/local/bin/box64 /home/steam/pz-dedicated/jre64/bin/java.real "$@"
EOF
    chmod +x "${STEAMAPPDIR}/jre64/bin/java"
    chown steam:steam "${STEAMAPPDIR}/jre64/bin/java"
  fi

  # Check and restore ProjectZomboid64 wrapper if it got overwritten or is missing after update/install
  if [ -f "${STEAMAPPDIR}/ProjectZomboid64" ] && [ "$(head -c 2 "${STEAMAPPDIR}/ProjectZomboid64")" != "#!" ]; then
    echo "Restoring ProjectZomboid64 box64 wrapper after installation..."
    mv "${STEAMAPPDIR}/ProjectZomboid64" "${STEAMAPPDIR}/ProjectZomboid64.real"
    cat << 'EOF' > "${STEAMAPPDIR}/ProjectZomboid64"
#!/bin/bash
JSON_FILE="/home/steam/pz-dedicated/ProjectZomboid64.json"
if [ -f "${JSON_FILE}" ] && command -v jq >/dev/null 2>&1; then
  CLASSPATH=$(jq -r '.classpath | join(":")' "${JSON_FILE}")
  MAINCLASS=$(jq -r '.mainClass' "${JSON_FILE}" | tr '/' '.')
  readarray -t VM_ARGS < <(jq -r '.vmArgs[]' "${JSON_FILE}")
else
  CLASSPATH="java/:java/projectzomboid.jar"
  MAINCLASS="zombie.network.GameServer"
  VM_ARGS=("-Xms16g" "-Xmx16g" "-Dzomboid.steam=1" "-Dzomboid.znetlog=1" "-Djava.library.path=linux64/:natives/")
fi

JVM_ARGS=()
APP_ARGS=()
in_app_args=false
for arg in "$@"; do
  if [ "$arg" = "--" ]; then
    in_app_args=true
    continue
  fi
  if [ "$in_app_args" = true ]; then
    APP_ARGS+=("$arg")
  else
    JVM_ARGS+=("$arg")
  fi
done

exec /home/steam/pz-dedicated/jre64/bin/java "${VM_ARGS[@]}" "${JVM_ARGS[@]}" -cp "${CLASSPATH}" "${MAINCLASS}" "${APP_ARGS[@]}"
EOF
    chmod +x "${STEAMAPPDIR}/ProjectZomboid64"
    chown steam:steam "${STEAMAPPDIR}/ProjectZomboid64"
  fi
fi

if [ "${FORCESTEAMCLIENTSOUPDATE}" == "1" ] || [ "${FORCESTEAMCLIENTSOUPDATE,,}" == "true" ]; then
  echo "FORCESTEAMCLIENTSOUPDATE variable is set, updating steamclient.so in Zomboid's server"
  cp "${STEAMCMDDIR}/linux64/steamclient.so" "${STEAMAPPDIR}/linux64/steamclient.so"
  cp "${STEAMCMDDIR}/linux32/steamclient.so" "${STEAMAPPDIR}/steamclient.so"
fi


######################################
#                                    #
# Process the arguments in variables #
#                                    #
######################################
ARGS=""

# Set the server memory. Units are accepted (1024m=1Gig, 2048m=2Gig, 4096m=4Gig): Example: 1024m
if [ -n "${MIN_MEMORY}" ] && [ -n "${MAX_MEMORY}" ]; then
  ARGS="${ARGS} -Xms${MIN_MEMORY} -Xmx${MAX_MEMORY}"
elif [ -n "${MEMORY}" ]; then
  ARGS="${ARGS} -Xms${MEMORY} -Xmx${MEMORY}"
fi

# Option to perform a Soft Reset
if [ "${SOFTRESET}" == "1" ] || [ "${SOFTRESET,,}" == "true" ]; then
  ARGS="${ARGS} -Dsoftreset"
fi

# End of Java arguments
ARGS="${ARGS} -- "

# Runs a coop server instead of a dedicated server. Disables the default admin from being accessible.
# - Default: Disabled
if [ "${COOP}" == "1" ] || [ "${COOP,,}" == "true" ]; then
  ARGS="${ARGS} -coop"
fi

# Disables Steam integration on server.
# - Default: Enabled
if [ "${NOSTEAM}" == "1" ] || [ "${NOSTEAM,,}" == "true" ]; then
  ARGS="${ARGS} -nosteam"
fi

# Sets the path for the game data cache dir.
# - Default: ~/Zomboid
# - Example: /server/Zomboid/data
if [ -n "${CACHEDIR}" ]; then
  ARGS="${ARGS} -cachedir=${CACHEDIR}"
fi

# Option to control where mods are loaded from and the order. Any of the 3 keywords may be left out and may appear in any order.
# - Default: workshop,steam,mods
# - Example: mods,steam
if [ -n "${MODFOLDERS}" ]; then
  ARGS="${ARGS} -modfolders ${MODFOLDERS}"
fi

# Launches the game in debug mode.
# - Default: Disabled
if [ "${DEBUG}" == "1" ] || [ "${DEBUG,,}" == "true" ]; then
  ARGS="${ARGS} -debug"
fi

# Option to set the admin username. Current admins will not be changed.
if [ -n "${ADMINUSERNAME}" ]; then
  ARGS="${ARGS} -adminusername ${ADMINUSERNAME}"
fi

# Option to bypasses the enter-a-password prompt when creating a server.
# This option is mandatory the first startup or will be asked in console and startup will fail.
# Once is launched and data is created, then can be removed without problem.
# Is recommended to remove it, because the server logs the arguments in clear text, so Admin password will be sent to log in every startup.
if [ -n "${ADMINPASSWORD}" ]; then
  ARGS="${ARGS} -adminpassword ${ADMINPASSWORD}"
fi

# Server password (Doesn't work)
#if [ -n "${PASSWORD}" ]; then
#  ARGS="${ARGS} -password ${PASSWORD}"
#fi

# You can choose a different servername by using this option when starting the server.
if [ -n "${SERVERNAME}" ]; then
  ARGS="${ARGS} -servername \"${SERVERNAME}\""
else
  # If not servername is set, use the default name in the next step
  SERVERNAME="servertest"
fi

# If preset is set, then the config file is generated when it doesn't exists or SERVERPRESETREPLACE is set to True.
if [ -n "${SERVERPRESET}" ]; then
  # If preset file doesn't exists then show an error and exit
  if [ ! -f "${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua" ]; then
    echo "*** ERROR: the preset ${SERVERPRESET} doesn't exists. Please fix the configuration before start the server ***"
    exit 1
  # If SandboxVars files doesn't exists or replace is true, copy the file
  elif [ ! -f "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua" ] || [ "${SERVERPRESETREPLACE,,}" == "true" ]; then
    echo "*** INFO: New server will be created using the preset ${SERVERPRESET} ***"
    echo "*** Copying preset file from \"${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua\" to \"${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua\" ***"
    mkdir -p "${HOMEDIR}/Zomboid/Server/"
    cp -nf "${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
    sed -i "1s/return.*/SandboxVars = \{/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
    # Remove carriage return
    dos2unix "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
    # I have seen that the file is created in execution mode (755). Change the file mode for security reasons.
    chmod 644 "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_SandboxVars.lua"
  fi
fi

# Option to handle multiple network cards. Example: 127.0.0.1
if [ -n "${IP}" ]; then
  ARGS="${ARGS} ${IP} -ip ${IP}"
fi

# Set the DefaultPort for the server. Example: 16261
if [ -n "${PORT}" ]; then
  ARGS="${ARGS} -port ${PORT}"
fi

# Option to enable/disable VAC on Steam servers. On the server command-line use -steamvac true/false. In the server's INI file, use STEAMVAC=true/false.
if [ -n "${STEAMVAC}" ] && { [ "${STEAMVAC,,}" == "true" ] || [ "${STEAMVAC,,}" == "false" ]; }; then
  ARGS="${ARGS} -steamvac ${STEAMVAC,,}"
fi

# Steam servers require two additional ports to function (I'm guessing they are both UDP ports, but you may need TCP as well).
# These are in addition to the DefaultPort= setting. These can be specified in two ways:
#  - In the server's INI file as SteamPort1= and SteamPort2=.
#  - Using STEAMPORT1 and STEAMPORT2 variables.
if [ -n "${STEAMPORT1}" ]; then
  ARGS="${ARGS} -steamport1 ${STEAMPORT1}"
fi
if [ -n "${STEAMPORT2}" ]; then
  ARGS="${ARGS} -steamport2 ${STEAMPORT2}"
fi

if [ -n "${PASSWORD}" ]; then
	sed -i "s/^Password=.*/Password=${PASSWORD}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
fi

if [ -n "${RCONPASSWORD}" ]; then
	sed -i "s/^RCONPassword=.*/RCONPassword=${RCONPASSWORD}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
fi

# Shows the server on the in-game browser.
if [ "${PUBLIC}" == "1" ] || [ "${PUBLIC,,}" == "true" ]; then
  sed -i "s/^Public=.*/Public=true/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
elif [ "${PUBLIC}" == "0" ] || [ "${PUBLIC,,}" == "false" ]; then
  sed -i "s/^Public=.*/Public=false/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
fi

# Set the display name for the server.
if [ -n "${DISPLAYNAME}" ]; then
  sed -i "s/^PublicName=.*/PublicName=${DISPLAYNAME}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
fi

if [ "${SELF_MANAGED_MODS}" == "1" ] || [ "${SELF_MANAGED_MODS,,}" == "true" ]; then
  echo "*** INFO: SELF_MANAGED_MODS is set; leaving Mods and WorkshopItems untouched ***"
else
  if [ -n "${MOD_IDS}" ]; then
    echo "*** INFO: Found Mods including ${MOD_IDS} ***"
    sed -i "s/Mods=.*/Mods=${MOD_IDS}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
  fi

  if [ -n "${WORKSHOP_IDS}" ]; then
    echo "*** INFO: Found Workshop IDs including ${WORKSHOP_IDS} ***"
    sed -i "s/WorkshopItems=.*/WorkshopItems=${WORKSHOP_IDS}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
  else
    echo "*** INFO: Workshop IDs is empty, clearing configuration ***"
    sed -i 's/WorkshopItems=.*$/WorkshopItems=/' "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"
  fi
fi

# Fixes EOL in script file for good measure
sed -i 's/\r$//' /server/scripts/search_folder.sh
# Check 'search_folder.sh' script for details
if [ -e "${HOMEDIR}/pz-dedicated/steamapps/workshop/content/108600" ]; then

  map_list=""
  source /server/scripts/search_folder.sh "${HOMEDIR}/pz-dedicated/steamapps/workshop/content/108600"
  map_list=$(<"${HOMEDIR}/maps.txt")  
  rm "${HOMEDIR}/maps.txt"

  if [ -n "${map_list}" ]; then
    echo "*** INFO: Added maps including ${map_list} ***"
    sed -i "s/Map=.*/Map=${map_list}Muldraugh, KY/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}.ini"

    # Checks which added maps have spawnpoints.lua files and adds them to the spawnregions file if they aren't already added
    IFS=";" read -ra strings <<< "$map_list"
    for string in "${strings[@]}"; do
        if ! grep -q "$string" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_spawnregions.lua"; then
          if [ -e "${HOMEDIR}/pz-dedicated/media/maps/$string/spawnpoints.lua" ]; then
            result="{ name = \"$string\", file = \"media/maps/$string/spawnpoints.lua\" },"
            sed -i "/function SpawnRegions()/,/return {/ {    /return {/ a\
            \\\t\t$result
            }" "${HOMEDIR}/Zomboid/Server/${SERVERNAME}_spawnregions.lua"
          fi
        fi
    done
  fi 
fi

# Fix to a bug in start-server.sh that causes to no preload a library:
# ERROR: ld.so: object 'libjsig.so' from LD_PRELOAD cannot be preloaded (cannot open shared object file): ignored.
export LD_LIBRARY_PATH="${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}"

su - steam -c "export LANG=${LANG} && export LD_LIBRARY_PATH=\"${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}\" && cd ${STEAMAPPDIR} && pwd && ./start-server.sh ${ARGS}"
