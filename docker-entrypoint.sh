#!/bin/bash
set -e

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_action(){ echo -e "${RED}${BOLD}[ACTION REQUIRED]${NC} $1"; }

export HYTALE_DIR="/data/hytale"
export INSTALLER_DIR="/data/installer"
export CONSOLE_PIPE="/data/console.pipe"

mkdir -p "$HYTALE_DIR" "$INSTALLER_DIR"

if [ "$(id -u)" = "0" ]; then
    log_info "Fixing permissions on data directory..."
    chown -R hytale:hytale /data
    log_info "Dropping privileges to user 'hytale'..."
    exec gosu hytale "$0" "$@"
fi

if [ ! -p "$CONSOLE_PIPE" ]; then
    mkfifo "$CONSOLE_PIPE"
    chmod 600 "$CONSOLE_PIPE"
fi

echo -e "${CYAN}========================================================${NC}"
echo -e "${CYAN}           HYTALE SERVER - DOCKERIZED                   ${NC}"
echo -e "${CYAN}========================================================${NC}"
echo -e "  ${BOLD}:: Patchline ::${NC}   $HYTALE_PATCHLINE"
echo -e "  ${BOLD}:: Port      ::${NC}   $SERVER_PORT (UDP)"
echo -e "  ${BOLD}:: Console   ::${NC}   ./hytale-cli"
echo -e "${CYAN}========================================================${NC}"
echo ""

SHOULD_INSTALL=false

if [ ! -f "$HYTALE_DIR/Server/HytaleServer.jar" ]; then
    log_warn "Server JAR not found. Setup required."
    SHOULD_INSTALL=true
elif [ "$UPDATE_ON_BOOT" = "true" ]; then
    log_info "Update requested via UPDATE_ON_BOOT flag."
    SHOULD_INSTALL=true
else
    log_ok "Server files found. Skipping update check."
fi

if [ "$SHOULD_INSTALL" = "true" ]; then
    cd "$INSTALLER_DIR"

    if [ ! -f "hytale-downloader-linux-amd64" ]; then
        log_info "Fetching Hytale Downloader tool..."
        curl -s -L "https://downloader.hytale.com/hytale-downloader.zip" --output installer.zip
        unzip -q -o installer.zip
        chmod +x hytale-downloader-linux-amd64
        rm installer.zip
        log_ok "Downloader tool installed."
    fi

    if [ -f ".hytale-downloader-credentials.json" ]; then
        log_info "Cached credentials found."
    else
        echo ""
        echo -e "${YELLOW}------------------------------------------------------------${NC}"
        log_action "AUTHENTICATION REQUIRED"
        echo -e "       1. Look for the ${BOLD}URL and CODE${NC} in the lines below."
        echo -e "       2. Visit the URL in your browser to approve."
        echo -e "${YELLOW}------------------------------------------------------------${NC}"
        echo ""
    fi

    log_info "Starting Downloader..."
    ./hytale-downloader-linux-amd64 -patchline "$HYTALE_PATCHLINE" -download-path "$HYTALE_DIR/output"

    if [ -f "$HYTALE_DIR/output.zip" ]; then
        log_ok "Download complete. Unpacking..."
        unzip -q -o "$HYTALE_DIR/output.zip" -d "$HYTALE_DIR"
        rm "$HYTALE_DIR/output.zip"
    else
        echo ""
        log_error "Download failed. Check the logs above."
        exit 1
    fi
fi

echo ""
log_info "Starting Hytale Server..."
cd "$HYTALE_DIR/Server"

trap 'kill -SIGTERM $SERVER_PID' SIGTERM SIGINT

tail -f "$CONSOLE_PIPE" | java -Xms${JAVA_MS} -Xmx${JAVA_MX} \
    -jar HytaleServer.jar \
    --assets ../Assets.zip \
    --bind 0.0.0.0:$SERVER_PORT &

SERVER_PID=$!
wait "$SERVER_PID"
