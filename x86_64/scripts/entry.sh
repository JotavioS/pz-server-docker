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

# If the server files do not exist, or if FORCEUPDATE is set, install/update the game
if [ ! -f "${STEAMAPPDIR}/start-server.sh" ] || [ "${FORCEUPDATE}" == "1" ] || [ "${FORCEUPDATE,,}" == "true" ]; then
  echo "Installing or updating Project Zomboid Dedicated Server..."
  if [ -z "${STEAMAPPBRANCH}" ] || [ "${STEAMAPPBRANCH}" = "public" ]; then
    su steam -c "${STEAMCMDDIR}/steamcmd.sh +@sSteamCmdForcePlatformType linux +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} validate +quit"
  else
    su steam -c "${STEAMCMDDIR}/steamcmd.sh +@sSteamCmdForcePlatformType linux +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} -beta ${STEAMAPPBRANCH} validate +quit"
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

# Create FIFO for server stdin if it doesn't exist
FIFO_PATH="/home/steam/pz.fifo"
if [ ! -p "$FIFO_PATH" ]; then
  echo "Creating stdin pipe (FIFO) at $FIFO_PATH..."
  mkfifo "$FIFO_PATH"
  chown steam:steam "$FIFO_PATH"
  chmod 660 "$FIFO_PATH"
fi

# Run the server with stdin redirected from the FIFO
# We keep the write descriptor open using tail -f to prevent EOF when commands finish writing
su - steam -c "export LANG=${LANG} && export LD_LIBRARY_PATH=\"${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}\" && cd ${STEAMAPPDIR} && tail -f $FIFO_PATH | ./start-server.sh ${ARGS}"
