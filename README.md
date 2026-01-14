# Hytale Server Docker

A production-ready, secure Docker implementation for the Hytale Server

This project provides a container environment. It is designed with some security in mind (hopefully), running as a non-root user with minimal kernel capabilities.

## Features

- **Rootless Runtime:** Runs as `uid:1001` (hytale) for isolation.
- **Automated Install:** Detects missing server files and fetches the latest patchline automatically.
- **CLI Wrapper:** Includes `hytale-cli` for sending commands without entering the container.
- **Git-Friendly:** Pre-configured `.gitignore` for server data.

## Quick Start

### 1. Requirements

- Docker & Docker Compose
- `bash` (for the CLI wrapper)

### 2. Setup

Clone the repository and build the image.

```bash
git clone https://github.com/Dari-OS/hytale-container.git
cd hytale-container
docker compose up -d --build

```

### 3. First-Time Authentication

Authentication is a two-step process: first for the **Installer** (to download files), and second for the **Server** (to host the game).

#### Phase A: Installer (Download)

1. Start the container and view the logs:

```bash
docker logs -f hytale_server

```

2. Look for the Installer OAuth message:

   > Please visit the following URL to authenticate:  
   > https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=<YOUR_CODE>  
   > Or visit the following URL and enter the code:  
   > https://oauth.accounts.hytale.com/oauth2/device/verify  
   > Authorization code: <YOUR_CODE>

3. Visit the link and approve the session.
4. The server will download assets (~1.4GB) and boot automatically.

#### Phase B: Server (Runtime)

Once the download finishes, the server will start. You will see a log entry: ` No server tokens configured. Use /auth login to authenticate.`. You must authenticate the running server instance.

1. Use the CLI tool to initiate the **Device Flow**:

```bash
./hytale-cli auth login device

```

2. The logs (or your console) will display a **new** URL and Code. Visit the link to approve.
3. **Crucial:** By default, credentials are stored in memory and lost on restart. Enable persistence to save them to the volume:

```bash
./hytale-cli auth persistence Encrypted

```

_Note: Credentials are cached in the volume. You do not need to repeat this step on restarts._

---

## Usage

### Sending Commands

Do not use `docker attach`. Instead, use the included wrapper script. This ensures the input stream is handled correctly via the named pipe.

**Interactive Mode:**

```bash
./hytale-cli

```

_Type commands normally. Press `Ctrl+C` to exit the tool (server remains running)._

**Single Command:**

```bash
./hytale-cli op Self

```

### Updates

To update the server to the latest version of the selected patchline:

1. Open `docker-compose.yml`.
2. Set `UPDATE_ON_BOOT=true`.
3. Restart the container:

```bash
docker compose restart

```

4. _Recommended:_ Set it back to `false` after the update to prevent re-downloading on every restart.

---

## Configuration

Environment variables can be set in `docker-compose.yml`.

| Variable           | Default   | Description                                      |
| ------------------ | --------- | ------------------------------------------------ |
| `HYTALE_PATCHLINE` | `release` | The update branch (`release`, etc).              |
| `UPDATE_ON_BOOT`   | `false`   | If `true`, re-runs the installer on every start. |
| `SERVER_PORT`      | `5520`    | The UDP port the server listens on.              |
| `JAVA_MS`          | `2G`      | Initial Java heap size.                          |
| `JAVA_MX`          | `4G`      | Maximum Java heap size.                          |
| `TERM`             | `xterm`   | Required for terminal emulation support.         |

## Project Structure

```text
.
├── docker-compose.yml    # Container orchestration
├── Dockerfile            # Base image definition (Eclipse Temurin 25)
├── docker-entrypoint.sh  # Startup logic, permissions fix, and pipe handler
├── hytale-cli            # Host-side wrapper script
└── server/               # Volume mount (Contains world data & config)

```

The `server/` directory is locally mounted to persist data. To back up your world, simply zip this folder.

## Security Details

This setup adheres to container security best practices:

- **User Isolation:** The container entrypoint starts as `root` only to fix volume permissions (`chown`) and create the named pipe, then immediately drops privileges to the `hytale` user using `gosu`.
- **Capability Dropping:** The `docker-compose.yml` drops all Linux capabilities (`cap_drop: ALL`) and selectively adds back only what is strictly necessary (`CHOWN`, `SETUID`, `SETGID`).
- **No New Privileges:** `security_opt: no-new-privileges:true` prevents privilege escalation attacks (e.g., sudo/suid binaries) inside the container.

## Troubleshooting

**Nothing happens after `docker compose up -d --build`:**  
Make sure to follow the tutorial and authenticate!

**Stuck on `downloading latest ("release" patchline) to "/data/hytale/output.zip"`:**  
Don't worry, it is not stuck it is just downloading. Sadly the progress does not get updated.
This is some weird behaviour caused by `docker logs` so be patient.
