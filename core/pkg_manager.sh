#!/bin/bash
# ============================================================
#  BearsNPRMP — Package Manager Abstraction Layer (PMAL)
#  Universal API for apt, dnf, yum, pacman, zypper, apk.
# ============================================================

# Ensure detect module is available
if [ -z "${PKG_MGR:-}" ]; then
    # shellcheck disable=SC1091
    source "$(dirname "${BASH_SOURCE[0]}")/detect.sh"
    detect_all
fi

# Update package repository indexes
pkg_update() {
    case "$PKG_MGR" in
        apt)
            run --sudo apt-get update -y
            ;;
        dnf|yum)
            run --sudo "$PKG_MGR" check-update -y || true
            ;;
        pacman)
            run --sudo pacman -Sy --noconfirm
            ;;
        zypper)
            run --sudo zypper refresh
            ;;
        apk)
            run --sudo apk update
            ;;
        *)
            warn "Gestor de paquetes no soportado para actualización automática: $PKG_MGR"
            return 1
            ;;
    esac
}

# Install one or more packages
pkg_install() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0

    case "$PKG_MGR" in
        apt)
            DEBIAN_FRONTEND=noninteractive run --sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
            ;;
        dnf|yum)
            run --sudo "$PKG_MGR" install -y "${pkgs[@]}"
            ;;
        pacman)
            run --sudo pacman -S --noconfirm --needed "${pkgs[@]}"
            ;;
        zypper)
            run --sudo zypper install -y --no-recommends "${pkgs[@]}"
            ;;
        apk)
            run --sudo apk add "${pkgs[@]}"
            ;;
        *)
            fail "No se pueden instalar paquetes: gestor '$PKG_MGR' desconocido."
            return 1
            ;;
    esac
}

# Check if a package is installed
pkg_is_installed() {
    local pkg="$1"
    case "$PKG_MGR" in
        apt)
            dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"
            ;;
        dnf|yum)
            rpm -q "$pkg" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Qi "$pkg" >/dev/null 2>&1
            ;;
        zypper)
            rpm -q "$pkg" >/dev/null 2>&1
            ;;
        apk)
            apk info -e "$pkg" >/dev/null 2>&1
            ;;
        *)
            command -v "$pkg" >/dev/null 2>&1
            ;;
    esac
}

# Resolves base packages required for bootstrap per distro
pkg_get_base_packages() {
    case "$PKG_MGR" in
        apt)
            echo "curl git unzip jq ca-certificates gnupg lsb-release procps net-tools"
            ;;
        dnf|yum)
            echo "curl git unzip jq ca-certificates gnupg2 procps-ng net-tools"
            ;;
        pacman)
            echo "curl git unzip jq ca-certificates gnupg procps-ng net-tools which"
            ;;
        zypper)
            echo "curl git unzip jq ca-certificates gpg2 procps net-tools"
            ;;
        apk)
            echo "curl git unzip jq ca-certificates gnupg procps net-tools shadow bash"
            ;;
        *)
            echo "curl git unzip jq ca-certificates"
            ;;
    esac
}

# Resolves Nginx package name
pkg_get_nginx_package() {
    case "$PKG_MGR" in
        pacman) echo "nginx-mainline" ;;
        *)      echo "nginx" ;;
    esac
}
