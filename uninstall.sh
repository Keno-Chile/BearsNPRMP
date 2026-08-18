#!/bin/bash
# ============================================================
#  🐻 BearsNPRMP — Script de Desinstalación
#  Revierte todos los cambios realizados por install.sh:
#    1. Detiene servicios Docker y Nginx
#    2. Elimina virtual hosts y entradas /etc/hosts
#    3. Elimina certificados SSL
#    4. Elimina symlinks globales
#    5. Elimina archivos del stack
#    6. Limpia configuración WSL
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEARS_DIR="${BEARS_DIR:-$HOME/bearsnprmp}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/bearsnprmp}"
WWW_DIR="${WWW_DIR:-/var/www}"

# CLI Arguments
DRY_RUN=0
YES=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) YES=1 ;;
        -h|--help)
            echo "Uso: ./uninstall.sh [--dry-run] [--yes]"
            echo ""
            echo "Elimina completamente BearsNPRMP del sistema:"
            echo "  • Detiene y elimina servicios Docker"
            echo "  • Elimina configuración de Nginx (vhosts)"
            echo "  • Elimina certificados SSL locales"
            echo "  • Elimina archivos del stack y symlinks"
            echo "  • Limpia configuración de /etc/hosts"
            exit 0
            ;;
        *)
            echo "Opción desconocida: $arg"
            exit 1
            ;;
    esac
done

export DRY_RUN YES

# Load Core Modules
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/detect.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/helpers.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/pkg_manager.sh"

# Load modules needed for cleanup
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/ssl.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/vhost.sh"

hr
printf "   🐻  %sBearsNPRMP — DESINSTALADOR%s  🐻\n" "$BOLD" "$RESET"
hr

# 1. Detect System
info "Analizando el entorno..."
detect_all

# 2. Confirmation
if [ "$YES" -eq 0 ]; then
    echo
    warn "Esto eliminará completamente BearsNPRMP y todos sus datos."
    warn "Directorio del stack: $BEARS_DIR"
    warn "Certificados SSL:     $CONFIG_DIR/ssl"
    warn "Datos Docker:         Volúmenes de MariaDB, PostgreSQL y Redis"
    echo
    echo -n "¿Estás seguro que deseas desinstalar? (s/N): "
    read -r confirm
    case "$confirm" in
        [sS]|[yY]|[sS][iI]) ;;
        *) echo "Desinstalación cancelada."; exit 0 ;;
    esac
fi

# 3. Stop all services
info "Deteniendo servicios..."

# Stop panel web
if pgrep -f "php.*router.php" >/dev/null 2>&1; then
    info "Deteniendo Panel Web..."
    pkill -f "php.*router.php" 2>/dev/null || true
    ok "Panel Web detenido."
fi

# Stop Nginx
if command -v nginx >/dev/null 2>&1; then
    info "Deteniendo Nginx..."
    if is_systemd; then
        run_root systemctl stop nginx 2>/dev/null || true
        run_root systemctl disable nginx 2>/dev/null || true
    elif [ "$INIT_SYSTEM" = "openrc" ]; then
        run_root service nginx stop 2>/dev/null || true
        run_root rc-update del nginx default 2>/dev/null || true
    else
        run_root nginx -s stop 2>/dev/null || true
    fi
    ok "Nginx detenido."
fi

# Stop Docker containers
if command -v docker >/dev/null 2>&1 && [ -f "$BEARS_DIR/templates/docker-compose.yml" ]; then
    info "Deteniendo contenedores Docker..."
    ( cd "$BEARS_DIR" && docker compose down -v 2>/dev/null ) || true
    ok "Contenedores Docker detenidos y volúmenes eliminados."
elif command -v docker >/dev/null 2>&1; then
    info "Deteniendo contenedores BearsNPRMP..."
    docker ps -a --filter "name=b-" --format "{{.Names}}" 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
    ok "Contenedores Docker limpiados."
fi

# 4. Remove virtual hosts
info "Eliminando virtual hosts..."
if [ -d "/etc/nginx/sites-available" ]; then
    for vhost in /etc/nginx/sites-available/*; do
        [ -f "$vhost" ] || continue
        local_domain=$(basename "$vhost")
        # Remove symlinks
        rm -f "/etc/nginx/sites-enabled/$local_domain" 2>/dev/null || true
        # Remove /etc/hosts entries
        if grep -q "127.0.0.1.*$local_domain" /etc/hosts 2>/dev/null; then
            tmp=$(mktemp)
            awk -v d="$local_domain" '{f=0; for(i=2;i<=NF;i++) if($i==d) f=1; if(!f) print}' /etc/hosts > "$tmp"
            run_root install -m 644 "$tmp" /etc/hosts
            rm -f "$tmp"
        fi
    done
    run_root rm -rf /etc/nginx/sites-available /etc/nginx/sites-enabled
    ok "Virtual hosts eliminados."
fi

# 5. Remove SSL certificates
info "Eliminando certificados SSL..."
if [ -d "$CONFIG_DIR/ssl" ]; then
    ssl_purge
    ok "Certificados SSL eliminados."
fi

# 6. Remove global symlinks
info "Eliminando symlinks globales..."
for link in bears bears-vhost bears-ssl; do
    link_path="/usr/local/bin/$link"
    if [ -L "$link_path" ]; then
        local target
        target=$(readlink "$link_path" 2>/dev/null || echo "")
        case "$target" in
            *bearsnprmp*|*BearsNPRMP*)
                run_root rm -f "$link_path"
                ok "Symlink eliminado: $link_path"
                ;;
        esac
    fi
done

# 7. Stop Nginx (if installed by BearsNPRMP)
info "Removiendo configuración de Nginx..."
if [ -d "/etc/nginx" ]; then
    # Backup original nginx.conf if we modified it
    if [ -f "/etc/nginx/nginx.conf.bearsnprmp.bak" ]; then
        run_root mv /etc/nginx/nginx.conf.bearsnprmp.bak /etc/nginx/nginx.conf
        ok "nginx.conf restaurado desde backup."
    fi
fi

# 8. Remove stack workspace
info "Eliminando directorio del stack..."
if [ -d "$BEARS_DIR" ]; then
    run_root rm -rf "$BEARS_DIR"
    ok "Directorio eliminado: $BEARS_DIR"
fi

# 9. Remove configuration directory
info "Eliminando configuración..."
if [ -d "$CONFIG_DIR" ]; then
    run_root rm -rf "$CONFIG_DIR"
    ok "Configuración eliminada: $CONFIG_DIR"
fi

# 10. Remove default welcome page from /var/www
info "Limpiando /var/www..."
if [ -f "$WWW_DIR/index.html" ] && grep -q "BearsNPRMP" "$WWW_DIR/index.html" 2>/dev/null; then
    run_root rm -f "$WWW_DIR/index.html"
    ok "Página de bienvenida eliminada."
fi

# 11. Clean WSL config if modified
if is_wsl; then
    if [ -f /etc/wsl.conf ]; then
        info "Limpiando configuración WSL..."
        # Remove only BearsNPRMP additions from wsl.conf
        if grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
            tmp=$(mktemp)
            grep -v "systemd=true" /etc/wsl.conf > "$tmp" 2>/dev/null || true
            # Only clean if we added it (check if there's nothing else under [boot])
            if [ ! -s "$tmp" ] || [ "$(wc -l < "$tmp")" -le 1 ]; then
                run_root rm -f /etc/wsl.conf
                ok "wsl.conf limpiado."
            else
                run_root install -m 644 "$tmp" /etc/wsl.conf
            fi
            rm -f "$tmp"
        fi
    fi
fi

# 12. Remove fnm/Node.js environment from shell rc files
info "Limpiando configuración de Node.js en shell..."
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ] && grep -q "fnm (Fast Node Manager)" "$rc" 2>/dev/null; then
        tmp=$(mktemp)
        # Remove the fnm snippet block
        sed '/# fnm (Fast Node Manager)/,/^fi$/d' "$rc" > "$tmp"
        run_root install -m 644 "$tmp" "$rc"
        rm -f "$tmp"
        ok "fnm configuration removed from $(basename "$rc")."
    fi
done

# 13. Remove .env file
if [ -f "$BEARS_DIR/.env" ]; then
    run_root rm -f "$BEARS_DIR/.env"
fi

hr
ok "🐻 ¡Desinstalación de BearsNPRMP completada!"
hr
echo
echo "  Notas:"
echo "  • Los paquetes del sistema (Nginx, Docker, etc.) NO fueron eliminados."
echo "    Si deseas eliminarlos, usa tu gestor de paquetes."
echo "  • Si instalaste Node.js via fnm, ejecuta: fnm uninstall <version>"
echo "  • Si ejecutaste 'mkcert -install', puedes eliminar la CA con:"
echo "    mkcert -uninstall"
echo
hr
