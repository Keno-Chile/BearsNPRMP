#!/bin/bash
# ============================================================
#  🐻 BearsNPRMP — Universal OS-Aware Web Development Stack
#  (Nginx, PHP 7.4/8.4/8.5, Redis, MariaDB, PostgreSQL,
#   Mailpit, RoadRunner, Node.js & Web Panel)
#
#  Soporte Universal:
#    - WSL2 / WSL1
#    - Linux Bare-Metal (Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, Alpine)
#    - Máquinas Virtuales (KVM, VMware, VirtualBox, Proxmox)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEARS_DIR="${BEARS_DIR:-$HOME/bearsnprmp}"

# CLI Arguments
DRY_RUN=0
YES=0
NO_START=0
MODE_CHOICE=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) YES=1 ;;
        --no-start) NO_START=1 ;;
        --mode=*) MODE_CHOICE="${arg#--mode=}" ;;
        -h|--help)
            echo "Uso: ./install.sh [--dry-run] [--yes] [--no-start] [--mode=container|native|hybrid]"
            exit 0
            ;;
        *)
            echo "Opción desconocida: $arg"
            exit 1
            ;;
    esac
done

export DRY_RUN YES NO_START BEARS_DIR

# 1. Load Core Modules
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/detect.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/helpers.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/pkg_manager.sh"

# 2. Load Action Modules
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/docker.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/nginx.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/node.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/services.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/vhost.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/panel.sh"

hr
printf "   🐻  %sBearsNPRMP — INSTALADOR UNIVERSAL MODULAR%s  🐻\n" "$BOLD" "$RESET"
hr

# 3. Detect System Environment
info "Analizando el entorno de ejecución..."
detect_all
print_detected_info
hr

# 4. Sudo Validation
ensure_sudo

# 5. Interactive Configuration (if not --yes)
if [ "$YES" -eq 0 ] && [ -z "$MODE_CHOICE" ]; then
    echo "¿Cómo deseas ejecutar los servicios principales del stack?"
    echo "  [1] Dockerizado (Recomendado - 100% universal y multi-versión)"
    echo "  [2] Nativo (vía gestor de paquetes de tu distro + systemd)"
    echo "  [3] Híbrido (Docker para BDs y Nativo para PHP)"
    echo -n "Selecciona [1]: "
    read -r m_input
    case "$m_input" in
        2) MODE_CHOICE="native" ;;
        3) MODE_CHOICE="hybrid" ;;
        *) MODE_CHOICE="container" ;;
    esac
fi

[ -z "$MODE_CHOICE" ] && MODE_CHOICE="container"
info "Modo seleccionado: $MODE_CHOICE"

# 6. Install Base Dependencies
info "Instalando paquetes base para $OS_NAME..."
pkg_update
# shellcheck disable=SC2046
pkg_install $(pkg_get_base_packages)

# 7. Setup Docker (if in container or hybrid mode)
if [ "$MODE_CHOICE" != "native" ]; then
    install_docker
fi

# 8. Setup Nginx
install_nginx

# 9. Setup Node.js via fnm
install_node "22"

# 9.1 Optimize WSL2 systemd configuration if on WSL
if is_wsl; then
    if [ ! -f /etc/wsl.conf ] || ! grep -q "\[boot\]" /etc/wsl.conf 2>/dev/null; then
        info "Optimizando configuración de WSL2 (/etc/wsl.conf)..."
        run_root sh -c "cat >> /etc/wsl.conf" <<'EOF'
[boot]
systemd=true
[network]
generateHosts=true
EOF
        ok "Configuración WSL (/etc/wsl.conf) aplicada."
    fi
fi

# 10. Copy and Initialize Stack Workspace
info "Sincronizando archivos del stack en $BEARS_DIR..."
mkdir -p "$BEARS_DIR"
cp -r "$SCRIPT_DIR"/* "$BEARS_DIR/" 2>/dev/null || true

# Initialize .env file
load_env
PHP_MODE="$MODE_CHOICE"
DB_MODE="$MODE_CHOICE"
PG_MODE="$MODE_CHOICE"
save_env

# 11. Start Stack Services unless --no-start
if [ "$NO_START" -eq 0 ]; then
    if [ "$MODE_CHOICE" = "container" ] || [ "$MODE_CHOICE" = "hybrid" ]; then
        info "Descargando imágenes y levantando el stack Docker..."
        ( cd "$BEARS_DIR" && run docker compose pull redis mailpit roadrunner php85 mariadb11 postgres17 || true )
        start_stack
    fi
    # Start web panel
    cmd_panel_server start
fi

# 12. Create handy global symlinks if writable
if [ -w /usr/local/bin ] || [ "$(id -u)" -eq 0 ] || (command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null); then
    run_root ln -sf "$BEARS_DIR/modules/panel.sh" /usr/local/bin/bears
    run_root ln -sf "$BEARS_DIR/modules/vhost.sh" /usr/local/bin/bears-vhost
    ok "Comandos globales creados: 'bears' y 'bears-vhost'."
fi

hr
ok "¡Instalación de BearsNPRMP completada exitosamente!"
hr
printf "  • Panel CLI    : %s\n" "bears (o $BEARS_DIR/modules/panel.sh)"
printf "  • Panel Web    : http://127.0.0.1:8088\n"
printf "  • Raíz Proyectos: %s\n" "$WWW_DIR"
printf "  • Crear VHost  : bears-vhost create --domain mi-sitio.test\n"
hr
