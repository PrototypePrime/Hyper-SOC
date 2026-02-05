#!/bin/bash

# Hyper-SOC: Universal SOC Analysis Tool Installer for Linux
# Supports: Debian/Ubuntu (apt), RHEL/CentOS/Fedora (dnf), Arch Linux (pacman)

set -e

# --- Configuration ---
CONFIG_PATH="../tools.json"
CONFIG_URL="https://raw.githubusercontent.com/PrototypePrime/Hyper-SOC/main/tools.json"
LOG_PATH="./install.log"
JQ_BIN="/usr/bin/jq"

# --- Logging Function ---
log() {
    local level=$1
    local message=$2
    local color=$3
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Colors
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local CYAN='\033[0;36m'
    local PURPLE='\033[0;35m'
    local NC='\033[0m'

    # Print to console
    echo -e "${!color}${message}${NC}"

    # Write to file (if not Dry Run, or if we want to log Dry Run too - usually useful)
    echo "[$timestamp] [$level] $message" >> "$LOG_PATH"
}

# --- Functions ---

print_banner() {
    echo -e "\e[36m"
    echo "  _   _                      ____   ___   ____ "
    echo " | | | |_   _ _ __   ___ _  / ___| / _ \ / ___| "
    echo " | |_| | | | | '_ \ / _ \ '__\___ \| | | | |    
 |  _  | |_| | |_) |  __/ |    ___) | |_| | |___ 
 |_| |_|\__, | .__/ \___|_|   |____/ \___/ \____| "
    echo "        |___/|_|                                 "
    echo " Universal SOC Installer - Linux"
    echo -e "\e[0m"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "FATAL" "[!] Please run as root" "RED"
        exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log "FATAL" "[!] Cannot detect distribution" "RED"
        exit 1
    fi
}

get_config() {
    # Check local, else download
    if [ ! -f "$CONFIG_PATH" ]; then
        log "WARN" "[!] Configuration not found locally." "YELLOW"
        log "INFO" "[*] Attempting to download from GitHub..." "CYAN"
        
        if [ "$DRY_RUN" = true ]; then
             log "DRYRUN" "[DRY RUN] Would download $CONFIG_URL to /tmp/tools.json" "PURPLE"
             # Mock for dry run if missing
             CONFIG_PATH="/tmp/tools_mock.json"
             echo '{"linux": {"apt_packages": [], "dnf_packages": [], "pacman_packages": [], "pip_packages": []}}' > "$CONFIG_PATH"
             return
        fi

        CONFIG_PATH="/tmp/tools.json"
        if command -v curl &> /dev/null; then
            curl -sL "$CONFIG_URL" -o "$CONFIG_PATH"
        elif command -v wget &> /dev/null; then
            wget -qO "$CONFIG_PATH" "$CONFIG_URL"
        else
            log "FATAL" "[!] Neither curl nor wget found. Cannot download config." "RED"
            exit 1
        fi
        
        if [ -f "$CONFIG_PATH" ]; then
             log "SUCCESS" "[+] Configuration downloaded." "GREEN"
        else
             log "FATAL" "[!] Failed to download configuration." "RED"
             exit 1
        fi
    fi
}

install_jq() {
    # We need jq to parse the JSON config. Bootstrap it.
    if ! command -v jq &> /dev/null; then
        log "INFO" "[+] Installing jq for configuration parsing..." "CYAN"
        if [ "$DRY_RUN" = true ]; then
            log "DRYRUN" "[DRY RUN] Would install jq" "PURPLE"
            return
        fi

        case $DISTRO in
            ubuntu|debian|kali) apt update && apt install -y jq ;;
            fedora|centos|rhel) dnf install -y jq ;;
            arch) pacman -S --noconfirm jq ;;
            *) log "ERROR" "[!] Could not install jq automatically." "RED"; exit 1 ;;
        esac
    fi
}

get_tools_from_json() {
    local key=$1
    if [ -f "$CONFIG_PATH" ]; then
        cat "$CONFIG_PATH" | jq -r ".linux.$key[]"
    else
        echo "" # Should be handled by get_config/install loops
    fi
}

install_apt() {
    log "INFO" "[+] Detected Debian/Ubuntu based system" "YELLOW"
    
    install_jq
    local tools=($(get_tools_from_json "apt_packages"))

    if [ "$DRY_RUN" = true ]; then
        log "DRYRUN" "[DRY RUN] Would run: apt update && apt upgrade -y" "PURPLE"
        log "DRYRUN" "[DRY RUN] Would install: ${tools[*]}" "PURPLE"
        return
    fi
    
    apt update && apt upgrade -y
    apt install -y "${tools[@]}"
}

install_dnf() {
    log "INFO" "[+] Detected RHEL/Fedora based system" "YELLOW"
    
    install_jq
    local tools=($(get_tools_from_json "dnf_packages"))
    
    if [ "$DRY_RUN" = true ]; then
        log "DRYRUN" "[DRY RUN] Would run: dnf update -y" "PURPLE"
        log "DRYRUN" "[DRY RUN] Would install: ${tools[*]}" "PURPLE"
        return
    fi
    
    dnf update -y
    dnf install -y "${tools[@]}"
}

install_pacman() {
    log "INFO" "[+] Detected Arch Based System" "YELLOW"
    
    install_jq
    local tools=($(get_tools_from_json "pacman_packages"))

    if [ "$DRY_RUN" = true ]; then
        log "DRYRUN" "[DRY RUN] Would update system" "PURPLE"
        log "DRYRUN" "[DRY RUN] Would install: ${tools[*]}" "PURPLE"
        return
    fi

    pacman -Syu --noconfirm
    pacman -S --noconfirm "${tools[@]}"
}

install_ghidra() {
    log "INFO" "[+] Installing Ghidra..." "YELLOW"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRYRUN" "[DRY RUN] Would install Java (JDK 17) and Ghidra (Snap)" "PURPLE"
        return
    fi

    # Ghidra requires Java. Installing JDK 17
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" || "$DISTRO" == "kali" ]]; then
        apt install -y openjdk-17-jdk unzip
    elif [[ "$DISTRO" == "fedora" || "$DISTRO" == "centos" || "$DISTRO" == "rhel" ]]; then
        dnf install -y java-17-openjdk unzip
    elif [[ "$DISTRO" == "arch" ]]; then
        pacman -S --noconfirm jdk17-openjdk unzip
    fi

    if command -v snap &> /dev/null; then
        snap install ghidra
    else
        log "ERROR" "[!] Snap not found. Skipping Ghidra automatic install. Please install manually." "RED"
    fi
}

install_pip_tools() {
    log "INFO" "[+] Installing Python Security Tools..." "YELLOW"
    
    local tools=($(get_tools_from_json "pip_packages"))

    if [ "$DRY_RUN" = true ]; then
        log "DRYRUN" "[DRY RUN] Would upgrade pip" "PURPLE"
        log "DRYRUN" "[DRY RUN] Would install pip packages: ${tools[*]}" "PURPLE"
        return
    fi
    
    # Ensure pip is upgraded
    python3 -m pip install --upgrade pip
    
    for tool in "${tools[@]}"; do
        log "INFO" "[->] Installing $tool..." "CYAN"
        pip3 install "$tool" || log "ERROR" "[!] Failed to install $tool" "RED"
    done
}

configure_post_install() {
    log "INFO" "[+] Running Post-Installation Configuration..." "YELLOW"
    
    # Wireshark Group Permissions
    if [ "$DRY_RUN" = true ]; then
        log "DRYRUN" "[DRY RUN] Would configure Wireshark permissions (non-root)" "PURPLE"
    else
        if command -v wireshark &> /dev/null; then
            log "INFO" "    Configuring Wireshark group..." "CYAN"
            # Interactive step usually, but we can try non-interactive for debian
            if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
                echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
                dpkg-reconfigure -f noninteractive wireshark-common
            fi
            # Add user to group
            if getent group wireshark >/dev/null; then
                # Get sudo user if running as sudo
                REAL_USER=${SUDO_USER:-$USER}
                usermod -aG wireshark "$REAL_USER"
                log "SUCCESS" "    Added $REAL_USER to wireshark group." "GREEN"
            fi
        fi
    fi

    # VS Code Extensions
    local extensions=("ms-python.python" "ms-azuretools.vscode-docker" "pkief.material-icon-theme" "redhat.vscode-yaml")
    if [ "$DRY_RUN" = true ]; then
         log "DRYRUN" "[DRY RUN] Would install VS Code extensions: ${extensions[*]}" "PURPLE"
    else
        if command -v code &> /dev/null; then
             # VS Code should ideally be run as user, not root. 
             # But if we are root, we might mess up ownership. 
             # Skipping automatic extension install if root, or running as SUDO_USER
             REAL_USER=${SUDO_USER:-$USER}
             log "INFO" "    Installing VS Code extensions for $REAL_USER..." "CYAN"
             for ext in "${extensions[@]}"; do
                 sudo -u "$REAL_USER" code --install-extension "$ext" --force >/dev/null 2>&1
             done
        fi
    fi
}

# --- Main ---
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
    esac
done

print_banner
if [ "$DRY_RUN" = true ]; then 
    log "INFO" "=== DRY RUN MODE ACTIVE ===" "PURPLE"
else
    check_root
fi

detect_distro
get_config

case $DISTRO in
    ubuntu|debian|kali)
        install_apt
        ;;
    fedora|centos|rhel)
        install_dnf
        ;;
    arch)
        install_pacman
        ;;
    *)
        log "FATAL" "[!] Unsupported distribution: $DISTRO" "RED"
        exit 1
        ;;
esac

install_ghidra
install_pip_tools
configure_post_install

log "SUCCESS" "[+] Installation Complete!" "GREEN"
