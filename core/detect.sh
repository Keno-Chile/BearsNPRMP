#!/bin/bash
# ============================================================
#  BearsNPRMP — Core Environment & OS Detection Engine
#  Identifies:
#    - Environment: WSL2, WSL1, Bare-Metal, VM, Container
#    - Distro / Family: Debian, Ubuntu, Fedora, RHEL, Rocky, Arch, openSUSE, Alpine
#    - Package Manager: apt, dnf, pacman, zypper, apk
#    - Init System: systemd, OpenRC, sysvinit
#    - Architecture: x86_64, aarch64, armv7l
# ============================================================

detect_all() {
    detect_arch
    detect_environment
    detect_os
    detect_init_system
}

detect_arch() {
    ARCH="$(uname -m 2>/dev/null || echo "unknown")"
    case "$ARCH" in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        armv7l|armhf) ARCH="armv7l" ;;
    esac
}

detect_environment() {
    ENV_TYPE="baremetal"
    ENV_DESC="Linux Nativo (Bare-Metal)"

    # Check for WSL (Windows Subsystem for Linux)
    if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ]; then
        if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ] || uname -r | grep -qi 'microsoft-standard-WSL2'; then
            ENV_TYPE="wsl2"
            ENV_DESC="Windows Subsystem for Linux 2 (WSL2)"
        else
            ENV_TYPE="wsl1"
            ENV_DESC="Windows Subsystem for Linux 1 (WSL1 - No recomendado)"
        fi
        return 0
    fi

    # Check if running in a container
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -qE '(docker|lxc|kubepods)' /proc/1/cgroup 2>/dev/null; then
        ENV_TYPE="container"
        ENV_DESC="Contenedor (Docker / LXC / Podman)"
        return 0
    fi

    # Check for Virtual Machine hypervisors
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt
        virt="$(systemd-detect-virt 2>/dev/null || echo 'none')"
        if [ "$virt" != "none" ]; then
            ENV_TYPE="vm"
            ENV_DESC="Máquina Virtual ($virt)"
            return 0
        fi
    fi
}

detect_os() {
    OS_ID="unknown"
    OS_NAME="Linux Desconocido"
    OS_LIKE=""
    OS_VERSION=""
    OS_CODENAME=""
    PKG_MGR="unknown"

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_NAME="${NAME:-Linux}"
        OS_LIKE="${ID_LIKE:-$OS_ID}"
        OS_VERSION="${VERSION_ID:-}"
        OS_CODENAME="${VERSION_CODENAME:-}"
    elif [ -f /etc/redhat-release ]; then
        OS_ID="rhel"
        OS_NAME="Red Hat Enterprise Linux"
        OS_LIKE="rhel fedora"
    elif [ -f /etc/debian_version ]; then
        OS_ID="debian"
        OS_NAME="Debian GNU/Linux"
        OS_LIKE="debian"
    elif [ -f /etc/arch-release ]; then
        OS_ID="arch"
        OS_NAME="Arch Linux"
        OS_LIKE="arch"
    elif [ -f /etc/alpine-release ]; then
        OS_ID="alpine"
        OS_NAME="Alpine Linux"
        OS_LIKE="alpine"
    fi

    # Determine standard package manager
    case "$OS_ID" in
        debian|ubuntu|linuxmint|pop|kali|raspbian)
            PKG_MGR="apt"
            ;;
        fedora|rhel|centos|rocky|almalinux|oracle|ol)
            if command -v dnf >/dev/null 2>&1; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            ;;
        arch|manjaro|endeavouros|garuda|artix)
            PKG_MGR="pacman"
            ;;
        opensuse*|sles|suse)
            PKG_MGR="zypper"
            ;;
        alpine)
            PKG_MGR="apk"
            ;;
        *)
            if [[ "$OS_LIKE" =~ debian|ubuntu ]]; then PKG_MGR="apt"
            elif [[ "$OS_LIKE" =~ rhel|fedora|centos ]]; then PKG_MGR="dnf"
            elif [[ "$OS_LIKE" =~ arch ]]; then PKG_MGR="pacman"
            elif [[ "$OS_LIKE" =~ suse ]]; then PKG_MGR="zypper"
            elif [[ "$OS_LIKE" =~ alpine ]]; then PKG_MGR="apk"
            fi
            ;;
    esac
}

detect_init_system() {
    INIT_SYSTEM="unknown"
    
    if [ -d /run/systemd/system ] || [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
        INIT_SYSTEM="systemd"
    elif command -v rc-status >/dev/null 2>&1 || [ -f /sbin/openrc-run ]; then
        INIT_SYSTEM="openrc"
    elif [ -f /etc/init.d/cron ] || [ -f /etc/init.d/rcS ]; then
        INIT_SYSTEM="sysvinit"
    fi
}

is_wsl() { [ "${ENV_TYPE:-}" = "wsl2" ] || [ "${ENV_TYPE:-}" = "wsl1" ]; }
is_systemd() { [ "${INIT_SYSTEM:-}" = "systemd" ]; }

print_detected_info() {
    printf "  • Entorno     : %s\n" "$ENV_DESC"
    printf "  • Sistema Op. : %s (%s %s)\n" "$OS_NAME" "$OS_ID" "$OS_VERSION"
    printf "  • Gestor Pkgs : %s\n" "$PKG_MGR"
    printf "  • Init System : %s\n" "$INIT_SYSTEM"
    printf "  • Arquitectura: %s\n" "$ARCH"
}
