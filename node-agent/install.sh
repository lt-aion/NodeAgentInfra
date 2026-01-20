#!/bin/bash
# Usage: ./install.sh --version 1.0.0 --token <token>

set -e

# --- Config ---
VERSION=""
BOOTSTRAP_TOKEN=""
ORCHESTRATOR_URL="http://localhost:9002"
AUTH_TYPE="auth0"
AUTH_PROVIDER="aion"
AUTH_PROVIDER_URL="http://localhost:9001"
LOG_LEVEL="info"
S3_BASE_URL="https://node-agent-1.s3.us-east-1.amazonaws.com"
BINARY_NAME="aion-node-agent"
DRY_RUN="false"

# --- Helpers ---
log_info() { echo -e "\e[34m[INSTALL]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; }

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] $@"
    else
        "$@"
    fi
}

run_write() {
    local target="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Writing content to $target"
        cat
    else
        cat > "$target"
    fi
}

# --- Detect Privilege Level ---
if [[ $EUID -eq 0 ]]; then
    IS_ROOT="true"
    EXECUTABLES_DIR="/opt/aion-node-agent"
    CONFIG_DIR="/etc/aion-node-agent"
    STATE_DIR="/var/lib/aion-node-agent"
    LOG_DIR="/var/log/aion-node-agent"
    
    SYSTEMD_DIR="/etc/systemd/system"
    SERVICE_NAME="aion-node-agent.service"
    SYSTEMCTL_CMD="systemctl"
else
    IS_ROOT="false"
    # User-level FHS-compliant paths
    EXECUTABLES_DIR="$HOME/.local/lib/aion-node-agent"
    CONFIG_DIR="$HOME/.config/aion-node-agent"
    
    # Use standard XDG data home
    STATE_DIR="$HOME/.local/share/aion-node-agent"
    LOG_DIR="$HOME/.local/logs/aion-node-agent"
    
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    SERVICE_NAME="aion-node-agent.service"
    SYSTEMCTL_CMD="systemctl --user"

    log_info "\e[33m[WARNING]\e[0m You are installing as a non-root user."
    log_info "          Certain plugins that require system-level permissions (e.g., SELinux context adjustment)"
    log_info "          may fail to initialize correctly without root privileges."
    echo ""
    printf "\e[34m[INSTALL]\e[0m Do you want to proceed with user-mode installation? [y/N]: "
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Installation aborted."
        exit 1
    fi
fi



load_init_config() {
    local init_file="init.yaml"
    if [[ -f "$init_file" ]]; then
        log_info "Loading configuration from $init_file..."
        
        # Extract specific keys using simple grep
        local bt=$(grep "bootstrap_token:" "$init_file" | awk -F'"' '{print $2}')
        [[ -n "$bt" ]] && BOOTSTRAP_TOKEN="$bt"

        local ou=$(grep "orchestrator_url:" "$init_file" | awk -F'"' '{print $2}')
        [[ -n "$ou" ]] && ORCHESTRATOR_URL="$ou"
        
        local at=$(grep "type:" "$init_file" | awk -F'"' '{print $2}')
        [[ -n "$at" ]] && AUTH_TYPE="$at"
        
        local ap=$(grep "provider:" "$init_file" | grep -v "url" | awk -F'"' '{print $2}')
        [[ -n "$ap" ]] && AUTH_PROVIDER="$ap"
        
        local apu=$(grep "provider_url:" "$init_file" | awk -F'"' '{print $2}')
        [[ -n "$apu" ]] && AUTH_PROVIDER_URL="$apu"
        
        local ll=$(grep "level:" "$init_file" | awk -F'"' '{print $2}')
        [[ -n "$ll" ]] && LOG_LEVEL="$ll"
    fi
}

# --- Functions ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version|-v) VERSION="$2"; shift 2 ;;
            --token|-t) BOOTSTRAP_TOKEN="$2"; shift 2 ;;
            --dry-run) DRY_RUN="true"; shift ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  -v, --version <v>      Version to install (optional, uses latest if omitted)"
                echo "  -t, --token <token>    Bootstrap token"
                exit 0
                ;;
            *) log_error "Unknown parameter: $1"; exit 1 ;;
        esac
    done
}

setup_dirs() {
    log_info "Preparing directories..."
    log_info "Mode: $( [[ "$IS_ROOT" == "true" ]] && echo 'System (Root)' || echo 'User' )"
    
    run_cmd mkdir -p "$EXECUTABLES_DIR/bin" "$CONFIG_DIR" "$STATE_DIR/plugins" "$LOG_DIR"
    
    if [[ "$IS_ROOT" == "true" ]]; then
        # Ensure strict permissions on system paths
        run_cmd chmod 755 "$EXECUTABLES_DIR"
        run_cmd chmod 750 "$CONFIG_DIR"
        run_cmd chmod 750 "$STATE_DIR"
    fi
}

download_bin() {
    local download_url
    if [[ -z "$VERSION" ]]; then
        log_info "Downloading latest version..."
        download_url="${S3_BASE_URL}/aion-node-agent"
    else
        log_info "Downloading version $VERSION..."
        download_url="${S3_BASE_URL}/aion-node-agent-${VERSION}"
	log_info "artifact url ${download_url}"
    fi
    run_cmd curl -fL "$download_url" -o "$EXECUTABLES_DIR/bin/$BINARY_NAME"
    run_cmd chmod +x "$EXECUTABLES_DIR/bin/$BINARY_NAME"
    
    # Symlink to /usr/local/bin or ~/.local/bin for convenience
    local bin_link_dir
    if [[ "$IS_ROOT" == "true" ]]; then
        bin_link_dir="/usr/local/bin"
    else
        bin_link_dir="$HOME/.local/bin"
        run_cmd mkdir -p "$bin_link_dir"
    fi
    run_cmd ln -sf "$EXECUTABLES_DIR/bin/$BINARY_NAME" "$bin_link_dir/$BINARY_NAME"
}

write_config() {
    local conf_file="$CONFIG_DIR/config.yaml"
    if [[ ! -f "$conf_file" ]]; then
        log_info "Creating configuration at $conf_file..."
        
        # Determine systemd path for config based on mode
        local systemd_path
        if [[ "$IS_ROOT" == "true" ]]; then
            systemd_path="/etc/systemd/system"
        else
            systemd_path="$HOME/.config/systemd/user"
        fi

        run_write "$conf_file" <<EOF
# Aion Node Agent Configuration
agent:
    bootstrap_token: "${BOOTSTRAP_TOKEN}"
    
server:
    orchestrator_url: ${ORCHESTRATOR_URL}

auth:
    type: ${AUTH_TYPE}
    provider: ${AUTH_PROVIDER}
    provider_url: ${AUTH_PROVIDER_URL}
    client_id: ""
    client_secret: ""
    access_token: ""
    refresh_token: ""
    timeout: 120

# AUTO GENERATED BY THE AGENT: DONT EDIT
paths:
    executables: ${EXECUTABLES_DIR}
    config: ${CONFIG_DIR}
    state: ${STATE_DIR}
    logs: ${LOG_DIR}
    systemd: ${systemd_path}

logging:
    level: ${LOG_LEVEL}

intervals:
    heartbeat: 60
    polling: 10
    sync: 5
    task_timeout: 900

identity:
    agent_id: ""
    node_id: ""

metadata:
    hostname: ""
    os: ""
    arch: ""
    mac_address: ""
EOF
    fi
}

setup_service() {
    log_info "Setting up systemd service..."
    run_cmd export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    run_cmd mkdir -p "$SYSTEMD_DIR"
    
    run_write "$SYSTEMD_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=Aion Node Agent
After=network.target

[Service]
Type=simple

ExecStart=$EXECUTABLES_DIR/bin/$BINARY_NAME
Environment="CONFIG_PATH=$CONFIG_DIR/config.yaml"
Restart=on-failure
StandardOutput=append:$LOG_DIR/stdout.log
StandardError=append:$LOG_DIR/stderr.log

[Install]
WantedBy=default.target
EOF

    run_cmd $SYSTEMCTL_CMD daemon-reload
    run_cmd $SYSTEMCTL_CMD restart $SERVICE_NAME
}

# --- Main ---

parse_args "$@"
load_init_config
setup_dirs
download_bin
write_config
setup_service

log_info "Installation complete!"
log_info ""
log_info "----------------------------------------------------------------"
log_info "Service has been started automatically."
log_info "----------------------------------------------------------------"
log_info ""
log_info "1. View Logs:"
if [[ "$IS_ROOT" == "true" ]]; then
    log_info "   sudo journalctl -u $SERVICE_NAME -f"
    log_info ""
    log_info "2. Check Status:"
    log_info "   sudo systemctl status $SERVICE_NAME"
    log_info ""
    log_info "Useful Commands:"
    log_info "  Stop:        sudo systemctl stop $SERVICE_NAME"
    log_info "  Restart:     sudo systemctl restart $SERVICE_NAME"
    log_info "  Config:      sudo cat $CONFIG_DIR/config.yaml"
else
    log_info "   journalctl --user -u $SERVICE_NAME -f"
    log_info ""
    log_info "2. Check Status:"
    log_info "   systemctl --user status $SERVICE_NAME"
log_info ""
    log_info "Useful Commands:"
    log_info "  Stop:        systemctl --user stop $SERVICE_NAME"
    log_info "  Restart:     systemctl --user restart $SERVICE_NAME"
    log_info "  Config:      cat $CONFIG_DIR/config.yaml"
fi
log_info ""
