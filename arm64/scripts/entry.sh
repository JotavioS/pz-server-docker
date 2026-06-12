#!/bin/bash

# Fix permissions on mounted volumes before running SteamCMD or starting the server
echo "Fixing permissions on mounted volumes..."
chown -R steam:steam /home/steam/pz-dedicated /home/steam/Zomboid /home/steam/pz-dedicated/steamapps/workshop || true
chmod 755 /home/steam/pz-dedicated /home/steam/Zomboid || true

# Check for pending administration actions
PENDING_ACTION_FILE="/home/steam/Zomboid/.pending_action"
if [ -f "$PENDING_ACTION_FILE" ]; then
  ACTION=$(cat "$PENDING_ACTION_FILE")
  echo "Found pending admin action: $ACTION"
  
  # Ensure SERVERNAME is set (default to servertest if empty)
  S_NAME="${SERVERNAME:-servertest}"
  
  case "$ACTION" in
    WIPE_WORLD)
      echo "Performing WIPE of the world map..."
      # Create a backup first for safety
      BACKUP_FILE="/home/steam/Zomboid/Backups/auto_backup_before_wipe_$(date +%Y%m%d_%H%M%S).tar.gz"
      mkdir -p "/home/steam/Zomboid/Backups"
      tar --exclude="Zomboid/Backups" -czf "$BACKUP_FILE" -C "/home/steam" Zomboid
      echo "Backup created at $BACKUP_FILE"
      
      # Delete map saves folder
      rm -rf "/home/steam/Zomboid/Saves/Multiplayer/${S_NAME}"
      echo "World map wiped."
      ;;
    WIPE_PLAYERS)
      echo "Performing WIPE of player accounts/characters..."
      # Create a backup first for safety
      BACKUP_FILE="/home/steam/Zomboid/Backups/auto_backup_before_wipe_$(date +%Y%m%d_%H%M%S).tar.gz"
      mkdir -p "/home/steam/Zomboid/Backups"
      tar --exclude="Zomboid/Backups" -czf "$BACKUP_FILE" -C "/home/steam" Zomboid
      echo "Backup created at $BACKUP_FILE"
      
      # Delete player database files
      rm -f "/home/steam/Zomboid/db/${S_NAME}.db"*
      rm -f "/home/steam/Zomboid/Saves/Multiplayer/${S_NAME}/players.db"
      echo "Player databases wiped."
      ;;
    WIPE_ALL)
      echo "Performing WIPE of world map and player accounts..."
      # Create a backup first for safety
      BACKUP_FILE="/home/steam/Zomboid/Backups/auto_backup_before_wipe_$(date +%Y%m%d_%H%M%S).tar.gz"
      mkdir -p "/home/steam/Zomboid/Backups"
      tar --exclude="Zomboid/Backups" -czf "$BACKUP_FILE" -C "/home/steam" Zomboid
      echo "Backup created at $BACKUP_FILE"
      
      # Delete map saves and player database
      rm -rf "/home/steam/Zomboid/Saves/Multiplayer/${S_NAME}"
      rm -f "/home/steam/Zomboid/db/${S_NAME}.db"*
      echo "World map and player databases wiped."
      ;;
    WIPE_COMPLETE)
      echo "Performing COMPLETE WIPE (resetting all configs, saves, and databases)..."
      # Create a backup first for safety
      BACKUP_FILE="/home/steam/Zomboid/Backups/auto_backup_before_wipe_$(date +%Y%m%d_%H%M%S).tar.gz"
      mkdir -p "/home/steam/Zomboid/Backups"
      tar --exclude="Zomboid/Backups" -czf "$BACKUP_FILE" -C "/home/steam" Zomboid
      echo "Backup created at $BACKUP_FILE"
      
      # Delete everything under Zomboid except the Backups folder
      find "/home/steam/Zomboid" -mindepth 1 -maxdepth 1 ! -name 'Backups' ! -name '.pending_action' -exec rm -rf {} +
      echo "Complete server data wiped."
      ;;
    ROLLBACK:*)
      BACKUP_NAME="${ACTION#ROLLBACK:}"
      BACKUP_PATH="/home/steam/Zomboid/Backups/${BACKUP_NAME}"
      if [ -f "$BACKUP_PATH" ]; then
        echo "Performing ROLLBACK to $BACKUP_NAME..."
        
        # Create a pre-rollback backup just in case
        PRE_ROLLBACK="/home/steam/Zomboid/Backups/pre_rollback_$(date +%Y%m%d_%H%M%S).tar.gz"
        mkdir -p "/home/steam/Zomboid/Backups"
        tar --exclude="Zomboid/Backups" -czf "$PRE_ROLLBACK" -C "/home/steam" Zomboid
        
        # Extract the selected backup
        # Clean current files first, keeping Backups folder
        find "/home/steam/Zomboid" -mindepth 1 -maxdepth 1 ! -name 'Backups' ! -name '.pending_action' -exec rm -rf {} +
        
        # Extract the backup
        tar -xzf "$BACKUP_PATH" -C "/home/steam"
        echo "Rollback completed successfully."
      else
        echo "ERROR: Backup file not found at $BACKUP_PATH"
      fi
      ;;
    BACKUP_COLD)
      echo "Performing COLD BACKUP..."
      BACKUP_FILE="/home/steam/Zomboid/Backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
      mkdir -p "/home/steam/Zomboid/Backups"
      tar --exclude="Zomboid/Backups" -czf "$BACKUP_FILE" -C "/home/steam" Zomboid
      echo "Cold backup created at $BACKUP_FILE"
      ;;
    *)
      echo "Unknown pending action: $ACTION"
      ;;
  esac
  
  # Delete the pending action file
  rm -f "$PENDING_ACTION_FILE"
fi

cd ${STEAMAPPDIR}

# Define JRE health check function
is_jre_healthy() {
  if [ "${USE_SYSTEM_JAVA,,}" = "true" ]; then
    if [ -f "/usr/bin/java" ]; then
      /usr/bin/java -version > /dev/null 2>&1
      return $?
    else
      return 1
    fi
  else
    if [ -f "${STEAMAPPDIR}/jre64/bin/java" ]; then
      LD_LIBRARY_PATH="${STEAMAPPDIR}:${STEAMAPPDIR}/linux64:${STEAMAPPDIR}/natives:${STEAMAPPDIR}/jre64/lib:${STEAMAPPDIR}/jre64/lib/server:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}" BOX64_JVM=0 BOX64_DYNAREC_BIGBLOCK=0 BOX64_DYNAREC_STRONGMEM=3 BOX64_DYNAREC_SAFEFLAGS=2 BOX64_SSE42=0 /usr/local/bin/box64 "${STEAMAPPDIR}/jre64/bin/java" -version > /dev/null 2>&1
      return $?
    else
      return 1
    fi
  fi
}

# Run JRE health check
if ! is_jre_healthy; then
  echo "JRE is missing, incomplete or corrupt. Forcing redownload/validation..."
  rm -f "${STEAMAPPDIR}/.download_complete"
fi

# If the server files do not exist, or if FORCEUPDATE is set, or if previous download was incomplete, install/update the game
if [ ! -f "${STEAMAPPDIR}/start-server.sh" ] || [ ! -f "${STEAMAPPDIR}/.download_complete" ] || [ "${FORCEUPDATE}" == "1" ] || [ "${FORCEUPDATE,,}" == "true" ]; then
  echo "Installing or updating Project Zomboid Dedicated Server..."
  rm -f "${STEAMAPPDIR}/.download_complete"
  
  MAX_RETRIES=3
  RETRY_COUNT=0
  SUCCESS=false
  STEAMCMD_OUT=$(mktemp)
  
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "SteamCMD download attempt $RETRY_COUNT of $MAX_RETRIES..."
    
    if [ -z "${STEAMAPPBRANCH}" ] || [ "${STEAMAPPBRANCH}" = "public" ]; then
      su steam -c "export DEBUGGER=/usr/local/bin/box64 && export STEAM_PLATFORM=linux64 && export BOX64_DYNAREC=1 && ${STEAMCMDDIR}/steamcmd.sh +@sSteamCmdForcePlatformType linux +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} validate +quit" 2>&1 | tee "$STEAMCMD_OUT"
    else
      su steam -c "export DEBUGGER=/usr/local/bin/box64 && export STEAM_PLATFORM=linux64 && export BOX64_DYNAREC=1 && ${STEAMCMDDIR}/steamcmd.sh +@sSteamCmdForcePlatformType linux +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} -beta ${STEAMAPPBRANCH} validate +quit" 2>&1 | tee "$STEAMCMD_OUT"
    fi
    
    # Check if this attempt was successful
    if [ ${PIPESTATUS[0]} -eq 0 ] && \
       [ -f "${STEAMAPPDIR}/start-server.sh" ] && \
       [ -f "${STEAMAPPDIR}/ProjectZomboid64" ] && \
       [ -f "${STEAMAPPDIR}/jre64/bin/java" ] && \
       grep -q "fully installed" "$STEAMCMD_OUT" && \
       is_jre_healthy; then
      SUCCESS=true
      break
    else
      echo "Warning: SteamCMD download attempt $RETRY_COUNT failed."
      if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "Waiting 10 seconds before retrying..."
        sleep 10
      fi
    fi
  done
  
  if [ "$SUCCESS" = true ]; then
    touch "${STEAMAPPDIR}/.download_complete"
    echo "Download completed successfully."
  else
    echo "ERROR: SteamCMD download failed after $MAX_RETRIES attempts."
    rm -f "${STEAMAPPDIR}/.download_complete"
    rm -f "$STEAMCMD_OUT"
    exit 1
  fi
  rm -f "$STEAMCMD_OUT"
  

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

# Create FIFO for server stdin if it doesn't exist
FIFO_PATH="/home/steam/pz.fifo"
if [ ! -p "$FIFO_PATH" ]; then
  echo "Creating stdin pipe (FIFO) at $FIFO_PATH..."
  mkfifo "$FIFO_PATH"
  chown steam:steam "$FIFO_PATH"
  chmod 660 "$FIFO_PATH"
fi

# Keep the FIFO open for writing on FD 3 to prevent EOF when writers disconnect
exec 3<> "$FIFO_PATH"

# Inject Box64 compatibility flags and configured JVM options into ProjectZomboid64.json
JSON_FILE="${STEAMAPPDIR}/ProjectZomboid64.json"
if [ -f "${JSON_FILE}" ] && command -v jq >/dev/null 2>&1; then
  echo "Injecting Box64 compatibility arguments into ProjectZomboid64.json..."
  
  # Determine GC method (default: UseG1GC)
  GC_METHOD="${JVM_GC:-UseG1GC}"
  
  # Base Box64 JVM compatibility args
  VM_ARGS="\"-Dsun.reflect.noInflation=true\", \"-Djdk.reflect.useDirectMethodHandle=false\", \"-XX:CompileCommand=exclude,java/lang/Class,reflectionData\", \"-XX:CompileCommand=exclude,se/krka/kahlua/*,*\", \"-XX:-UseSuperWord\""
  
  # Add Tiered Compilation Stop Level if specified
  if [ -n "${JVM_TIERED_STOP_AT_LEVEL}" ]; then
    VM_ARGS="${VM_ARGS}, \"-XX:TieredStopAtLevel=${JVM_TIERED_STOP_AT_LEVEL}\""
  fi
  
  # Add Interpreted mode if specified
  if [ "${JVM_INTERPRETED,,}" = "true" ]; then
    VM_ARGS="${VM_ARGS}, \"-Xint\""
  fi
  
  # Perform replacement in JSON
  jq --arg gc "-XX:+${GC_METHOD}" ".vmArgs = (.vmArgs | map(if . == \"-XX:+UseZGC\" then \$gc else . end) + [${VM_ARGS}] | unique)" "${JSON_FILE}" > "${JSON_FILE}.tmp"
  mv "${JSON_FILE}.tmp" "${JSON_FILE}"
  chown steam:steam "${JSON_FILE}"
fi

# Create a wrapper bin directory to intercept PATH lookups without modifying pristine binaries
mkdir -p "${STEAMAPPDIR}/box64-wrappers"
cat << EOF > "${STEAMAPPDIR}/box64-wrappers/java"
#!/bin/bash
exec /usr/local/bin/box64 "${STEAMAPPDIR}/jre64/bin/java" "\$@"
EOF
chmod +x "${STEAMAPPDIR}/box64-wrappers/java"
chown -R steam:steam "${STEAMAPPDIR}/box64-wrappers"

# Patch start-server.sh to explicitly use box64 and prevent JVM bitness check failures
if [ -f "${STEAMAPPDIR}/start-server.sh" ]; then
  # Remove previous box64 injections if any to prevent duplication
  sed -i 's|/usr/local/bin/box64 ||g' "${STEAMAPPDIR}/start-server.sh"
  
  # Inject box64 into the java version check
  sed -i 's|"${INSTDIR}/jre64/bin/java" -version|/usr/local/bin/box64 "${INSTDIR}/jre64/bin/java" -version|g' "${STEAMAPPDIR}/start-server.sh"
  
  # Inject box64-wrappers into the PATH export inside start-server.sh
  sed -i 's|export PATH="${INSTDIR}/jre64/bin:$PATH"|export PATH="${INSTDIR}/box64-wrappers:${INSTDIR}/jre64/bin:$PATH"|g' "${STEAMAPPDIR}/start-server.sh"
  
  # Inject box64 into the ProjectZomboid64 execution line
  sed -i 's|\./ProjectZomboid64|/usr/local/bin/box64 ./ProjectZomboid64|g' "${STEAMAPPDIR}/start-server.sh"
fi

# Configure Box64 Dynarec Math optimizations
BOX64_FAST_MATH="${BOX64_FAST_MATH:-true}"
if [ "${BOX64_FAST_MATH,,}" = "true" ]; then
  FAST_NAN=1
  FAST_ROUND=1
else
  FAST_NAN=0
  FAST_ROUND=0
fi

STRONG_MEM="${BOX64_STRONG_MEM:-3}"

# Check for eatmydata to bypass disk syncs on slow drives
USE_EATMYDATA="${USE_EATMYDATA:-false}"
LAUNCH_CMD="./start-server.sh ${ARGS}"
if [ "${USE_EATMYDATA,,}" = "true" ]; then
  if command -v eatmydata >/dev/null 2>&1; then
    echo "Running server with eatmydata to bypass disk write syncs (highly optimized for HDDs)..."
    LAUNCH_CMD="eatmydata ./start-server.sh ${ARGS}"
  else
    echo "WARNING: eatmydata requested but the 'eatmydata' command is not available."
  fi
fi

# Run the server with stdin redirected from the FIFO
su - steam -c "export LANG=${LANG} && export LD_LIBRARY_PATH=\"${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}\" && export BOX64_DYNAREC_STRONGMEM=${STRONG_MEM} && export BOX64_DYNAREC_SAFEFLAGS=2 && export BOX64_DYNAREC_FASTNAN=${FAST_NAN} && export BOX64_DYNAREC_FASTROUND=${FAST_ROUND} && cd ${STEAMAPPDIR} && ${LAUNCH_CMD} < $FIFO_PATH"
