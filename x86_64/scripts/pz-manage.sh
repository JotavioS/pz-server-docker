#!/bin/bash

# Configuration
FIFO_PATH="/home/steam/pz.fifo"
HOMEDIR="/home/steam"
ZOMBOID_DIR="${HOMEDIR}/Zomboid"
BACKUP_DIR="${ZOMBOID_DIR}/Backups"
SERVERNAME="${SERVERNAME:-servertest}"

show_help() {
  echo "Project Zomboid Server Management Tool"
  echo "======================================"
  echo "Usage: pz-manage <command> [arguments]"
  echo ""
  echo "Commands:"
  echo "  status                      Check if the server is running"
  echo "  send <command>              Send a raw command to the server console"
  echo "  backup [--hot | --cold]     Create a server backup"
  echo "                              --hot : Backs up while the server is running (default)"
  echo "                              --cold: Stops the server, backs up, and restarts"
  echo "  rollback                    List backups and choose one to restore (stops server)"
  echo "  wipe <type>                 Wipe server data (stops server)"
  echo "                              Types: world, players, all, complete"
  echo ""
  echo "Examples:"
  echo "  pz-manage status"
  echo "  pz-manage send \"servermsg 'Hello Players!'\""
  echo "  pz-manage backup --hot"
  echo "  pz-manage wipe world"
}

is_running() {
  pgrep -f "zombie.network.GameServer" > /dev/null
}

send_console() {
  if ! is_running; then
    echo "ERROR: Project Zomboid server is not running."
    exit 1
  fi
  if [ ! -p "$FIFO_PATH" ]; then
    echo "ERROR: Server input pipe (FIFO) is not available."
    exit 1
  fi
  echo "$1" > "$FIFO_PATH"
  echo "Command sent to server console: $1"
}

stop_server_gracefully() {
  echo "Saving the world..."
  send_console "save"
  sleep 3
  echo "Stopping the server..."
  send_console "quit"
  
  # Wait for process to terminate
  echo "Waiting for server to shut down..."
  while is_running; do
    sleep 1
  done
  echo "Server stopped."
}

do_status() {
  if is_running; then
    PID=$(pgrep -f "zombie.network.GameServer")
    echo "Status: RUNNING (PID: $PID)"
  else
    echo "Status: STOPPED"
  fi
}

do_backup_hot() {
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="${BACKUP_DIR}/backup_hot_$(date +%Y%m%d_%H%M%S).tar.gz"
  
  if is_running; then
    echo "Server is running. Sending save command to ensure consistency..."
    send_console "save"
    sleep 2
  fi
  
  echo "Creating hot backup at $BACKUP_FILE..."
  tar --exclude="Zomboid/Backups" -czf "$BACKUP_FILE" -C "$HOMEDIR" Zomboid
  echo "Hot backup created successfully!"
}

do_backup_cold() {
  if ! is_running; then
    echo "Server is stopped. Creating standard backup..."
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar --exclude="Zomboid/Backups" -czf "$BACKUP_FILE" -C "$HOMEDIR" Zomboid
    echo "Backup created successfully at $BACKUP_FILE"
    return
  fi

  echo "Scheduling cold backup..."
  echo "BACKUP_COLD" > "${ZOMBOID_DIR}/.pending_action"
  stop_server_gracefully
  echo "The container will now exit, perform the backup, and restart automatically."
}

do_wipe() {
  TYPE="$1"
  if [ -z "$TYPE" ]; then
    echo "ERROR: Please specify wipe type: world, players, all, or complete."
    exit 1
  fi

  case "$TYPE" in
    world) ACTION="WIPE_WORLD" ;;
    players) ACTION="WIPE_PLAYERS" ;;
    all) ACTION="WIPE_ALL" ;;
    complete) ACTION="WIPE_COMPLETE" ;;
    *)
      echo "ERROR: Invalid wipe type. Choose from: world, players, all, complete."
      exit 1
      ;;
  esac

  echo "WARNING: You are about to perform a $TYPE wipe!"
  echo "This action will stop the server and delete data."
  read -p "Are you sure you want to continue? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "Wipe cancelled."
    exit 0
  fi

  echo "Scheduling $TYPE wipe..."
  echo "$ACTION" > "${ZOMBOID_DIR}/.pending_action"

  if is_running; then
    stop_server_gracefully
    echo "The container will now restart, perform the wipe, and boot the server."
  else
    echo "Server is stopped. Action scheduled. Restart the container to apply."
  fi
}

do_rollback() {
  if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "No backups found in $BACKUP_DIR"
    exit 1
  fi

  echo "Available Backups:"
  echo "------------------"
  files=($(ls -1 "$BACKUP_DIR" | grep '\.tar\.gz$'))
  for i in "${!files[@]}"; do
    echo "[$i] ${files[$i]}"
  done
  echo "------------------"
  
  read -p "Select backup number to restore (or 'c' to cancel): " SELECTION
  
  if [ "$SELECTION" == "c" ] || [ "$SELECTION" == "C" ]; then
    echo "Rollback cancelled."
    exit 0
  fi

  if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -ge "${#files[@]}" ]; then
    echo "ERROR: Invalid selection."
    exit 1
  fi

  SELECTED_BACKUP="${files[$SELECTION]}"
  echo "WARNING: You are about to restore backup: $SELECTED_BACKUP"
  echo "This will OVERWRITE all current map, saves, and players. A backup of the current state will be created automatically."
  read -p "Are you sure you want to continue? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "Rollback cancelled."
    exit 0
  fi

  echo "Scheduling rollback to $SELECTED_BACKUP..."
  echo "ROLLBACK:$SELECTED_BACKUP" > "${ZOMBOID_DIR}/.pending_action"

  if is_running; then
    stop_server_gracefully
    echo "The container will now restart, perform the rollback, and boot the server."
  else
    echo "Server is stopped. Action scheduled. Restart the container to apply."
  fi
}

# Main command router
case "$1" in
  status)
    do_status
    ;;
  send)
    shift
    send_console "$*"
    ;;
  backup)
    if [ "$2" == "--cold" ]; then
      do_backup_cold
    else
      do_backup_hot
    fi
    ;;
  wipe)
    do_wipe "$2"
    ;;
  rollback)
    do_rollback
    ;;
  *)
    show_help
    ;;
esac
