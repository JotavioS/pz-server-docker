# Project Zomboid Dedicated Server Docker (x86_64 & arm64)

This repository provides complete and structured Docker configurations from scratch to run a dedicated **Project Zomboid** server on **x86_64** (Intel/AMD) and **arm64** (Apple Silicon, Raspberry Pi, Oracle Cloud Ampere VMs, etc.) architectures.

Both setups are built on consistent bases using **Ubuntu 22.04** as the base image and the non-privileged `steam` user.

## Repository Structure

The project is divided into two directories corresponding to each architecture:

*   **`x86_64/`**: Native configuration built from Ubuntu 22.04, ideal for standard Intel or AMD computers and servers.
*   **`arm64/`**: High-performance emulation-based configuration utilizing **Box86** (for the 32-bit SteamCMD) and **Box64** (for the 64-bit Java Virtual Machine of Project Zomboid).

---

## Server Configuration (`.env`)

Server configuration is done identically in both architectures through environment files.

1. Go to the folder corresponding to your architecture (`x86_64` or `arm64`).
2. Copy the `.env.template` file to `.env`:
   ```bash
   cp .env.template .env
   ```
3. Edit the `.env` file to adjust your server parameters:
   *   **`STEAMAPPBRANCH`**: Set the SteamCMD branch (e.g. `public` for Build 41, `unstable` for Build 42).
   *   **`FORCEUPDATE`**: Set to `True` to force update game files on container start.
   *   **`ADMINPASSWORD`**: (Required on first startup) Set the server administrator password.
   *   **`MEMORY`**: RAM allocated for the server (e.g. `4096m` or `8192m`).
   *   **`NOSTEAM`**: Set to `True` if you want to allow connections from non-official/non-Steam clients.
   *   **`MOD_IDS`** and **`WORKSHOP_IDS`**: IDs of mods and Workshop items separated by semicolons.

---

## How to Run

### Option 1: x86_64 (Native Intel/AMD)

Enter the directory and start the container:
```bash
cd x86_64
docker compose up -d --build
```

### Option 2: arm64 (Emulated via Box86/Box64)

This image will compile the **Box86** and **Box64** instruction translation tools directly inside the container to run the game with near-native performance (far superior to QEMU).

Enter the directory and start the container:
```bash
cd arm64
docker compose up -d --build
```
*Note: Emulator compilation and the initial download of game files may take 5 to 10 minutes on the first run.*

---

## Server Management

Both architectures come with a command-line utility `pz-manage` inside the container to perform administrative tasks (backups, wipes, rollbacks, status checking, and sending live console commands) safely.

### How to Run Commands

You can execute the management commands directly from the host terminal using `docker compose exec`:

*   **Check Server Status:**
    ```bash
    docker compose exec ProjectZomboidDedicatedServer pz-manage status
    ```
    *(For ARM64, replace `ProjectZomboidDedicatedServer` with `ProjectZomboidDedicatedServerArm64`).*

*   **Send a Console Command:**
    ```bash
    docker compose exec ProjectZomboidDedicatedServer pz-manage send "<command>"
    # Example:
    docker compose exec ProjectZomboidDedicatedServer pz-manage send "servermsg 'Backup starting...'"
    ```

*   **Create a Backup:**
    ```bash
    # Hot backup (server stays online):
    docker compose exec ProjectZomboidDedicatedServer pz-manage backup
    # Cold backup (stops server, backs up, and restarts):
    docker compose exec -it ProjectZomboidDedicatedServer pz-manage backup --cold
    ```
    *All backups are saved as `.tar.gz` files in `./data/Backups/`.*

*   **Wipe Server Data:**
    ```bash
    docker compose exec -it ProjectZomboidDedicatedServer pz-manage wipe <type>
    # Types:
    # - world     : deletes map chunks and saves (keeps accounts/configs)
    # - players   : deletes player database/characters (keeps map/configs)
    # - all       : deletes map chunks and player databases
    # - complete  : wipes everything except the Backups folder (hard reset)
    ```

*   **Rollback to a Backup:**
    ```bash
    docker compose exec -it ProjectZomboidDedicatedServer pz-manage rollback
    ```
    *Lists available backups and asks which one to restore.*

---

## Connectivity and Required Ports

Ports are pre-configured in the `docker-compose.yml` files to support both Steam and non-Steam clients.

Make sure to release/forward the following ports in your system's firewall and router:

### Common Ports (Steam & General)
*   `16261/UDP` — Main game server communication network port.
*   `27015/TCP` — Optional port for RCON (remote management).

### Ports for Non-Steam Clients (Direct Connection)
If you defined `NOSTEAM=True` in your `.env`, the server requires the following ports to be open:
*   `8766/UDP` and `8767/UDP` — Authentication query ports.
*   `16262-16272/TCP` — Direct connection TCP port range. *Each simultaneously connected player consumes one port from this range (e.g. the default 11-port range handles up to 11 simultaneous players).*

---

## How ARM64 Emulation Works

Due to the lack of native Project Zomboid builds for ARM processors, the `arm64/` folder uses the following virtualization strategy:
1. **Custom Compilation**: Box86 and Box64 are compiled from source with optimizations targeted for ARMv8-A architectures.
2. **SteamCMD (32-bit x86)**: Translated via **Box86** with support for native 32-bit libraries (`armhf`) installed in the container.
3. **Project Zomboid (64-bit x86_64)**: Translated via **Box64**, intercepting calls to the game's 64-bit Java Runtime Environment (JRE).
4. **Resilience (Self-Healing)**: The `entry.sh` script in the `arm64/` folder monitors binary integrity. If a SteamCMD or game update restores the original x86 Java or SteamCMD executables, the script automatically recreates the translation wrappers during boot.

---

## License

This project is licensed under the **WTFPL (Do What The Fuck You Want To Public License)**. See the [LICENSE](file:///c:/development/pz-server-docker/LICENSE) file for details.