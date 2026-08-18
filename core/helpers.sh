#!/bin/bash
# ============================================================
#  BearsNPRMP — Core Utilities & Shared Helpers
# ============================================================

BEARS_DIR="${BEARS_DIR:-$HOME/bearsnprmp}"
ENV_FILE="${BEARS_DIR}/.env"
WWW_DIR="${WWW_DIR:-/var/www}"
DATA_DIR="${DATA_DIR:-/var/lib/bearsnprmp}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/bearsnprmp}"

# Color codes
GREEN=$'\e[32m'
RED=$'\e[31m'
BLUE=$'\e[34m'
CYAN=$'\e[36m'
YELLOW=$'\e[33m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

TICK="${GREEN}✔${RESET}"
CROSS="${RED}✘${RESET}"
WARN_ICON="${YELLOW}⚠${RESET}"
INFO_ICON="${BLUE}ℹ${RESET}"

info() { printf "${BLUE}ℹ${RESET}  %s\n" "$*"; }
ok()   { printf "${GREEN}✔${RESET}  %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${RESET}  %s\n" "$*"; }
fail() { printf "${RED}✘${RESET}  %s\n" "$*"; }
hr()   { printf -- '=========================================================\n'; }
sep()  { printf -- '---------------------------------------------------------\n'; }

# Run command with dry-run support and optional privilege escalation
run() {
    local use_sudo=0
    if [ "${1:-}" = "--sudo" ]; then
        use_sudo=1
        shift
    fi

    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf "${YELLOW}[dry-run]${RESET} "
        [ "$use_sudo" = "1" ] && [ "$(id -u)" -ne 0 ] && printf 'sudo '
        printf '%s\n' "$*"
        return 0
    fi

    if [ "$use_sudo" = "1" ] && [ "$(id -u)" -ne 0 ]; then
        sudo -n true 2>/dev/null || sudo -v
        sudo "$@"
    else
        "$@"
    fi
}

# Run command strictly as root (sudo or direct)
run_root() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf "${YELLOW}[dry-run]${RESET} "
        [ "$(id -u)" -ne 0 ] && printf 'sudo '
        printf '%s\n' "$*"
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo -n "$@" 2>/dev/null || sudo "$@"
    fi
}

# Ensure sudo credentials once and keep timestamp refreshed in background
SUDO_LOOP_PID=""
ensure_sudo() {
    [ "${DRY_RUN:-0}" = "1" ] && return 0
    if [ "$(id -u)" -eq 0 ]; then
        ok "Ejecutando como usuario root — omitiendo comprobación de sudo."
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || {
        fail "Este script requiere 'sudo' para configurar servicios y dependencias (o ejecutar como root)."
        exit 1
    }

    if ! sudo -n true 2>/dev/null; then
        echo
        info "La instalación de BearsNPRMP necesita permisos de administrador (sudo)."
        echo "      Introduce tu contraseña cuando se pida (se mantendrá fresca durante la instalación)."
        if ! sudo -v; then
            fail "Autenticación sudo cancelada o fallida. Abortando."
            exit 1
        fi
    fi

    # Start background keepalive loop
    ( while true; do sudo -n true 2>/dev/null; sleep 45; kill -0 "$$" 2>/dev/null || exit 0; done ) &
    SUDO_LOOP_PID=$!
    trap 'cleanup_sudo_loop' EXIT INT TERM
    ok "Acceso sudo verificado y mantenido en segundo plano."
}

cleanup_sudo_loop() {
    if [ -n "$SUDO_LOOP_PID" ]; then
        kill "$SUDO_LOOP_PID" 2>/dev/null || true
    fi
}

# Fault-Tolerant retry runner
retry() {
    local max_attempts="$1"
    local count=0
    shift

    until "$@"; do
        count=$((count + 1))
        if [ "$count" -ge "$max_attempts" ]; then
            fail "Comando falló tras $max_attempts intentos: $*"
            return 1
        fi
        warn "Fallo en: $* — reintentando ($count/$max_attempts) en 3s..."
        sleep 3
    done
    return 0
}

# ------------------------------------------------------------
#  Service Port Mapping & Metadata
# ------------------------------------------------------------
declare -A SERVICE_PORT=(
  [php74]="9002" [php84]="9001" [php85]="9000"
  [mariadb10]="3307" [mariadb11]="3306"
  [postgres15]="5433" [postgres17]="5432"
  [redis]="6379" [mailpit]="8025" [roadrunner]="8080"
  [panel]="8088"
)

declare -A SERVICE_VERSION=(
  [php74]="PHP 7.4" [php84]="PHP 8.4" [php85]="PHP 8.5"
  [mariadb10]="MariaDB 10.11" [mariadb11]="MariaDB 11.4"
  [postgres15]="PostgreSQL 15" [postgres17]="PostgreSQL 17"
  [redis]="Redis 7" [mailpit]="Mailpit" [roadrunner]="RoadRunner 2025.x"
  [panel]="Panel Web"
)

declare -A NATIVE_SERVICE=(
  [php74]="php7.4-fpm" [php84]="php8.4-fpm" [php85]="php8.5-fpm"
  [mariadb10]="mariadb" [mariadb11]="mariadb"
  [postgres15]="postgresql@15-main" [postgres17]="postgresql@17-main"
  [redis]="redis-server" [nginx]="nginx"
)

PHP_FAMILY=(php74 php84 php85)
DB_FAMILY=(mariadb10 mariadb11)
PG_FAMILY=(postgres15 postgres17)

port_of() { echo "${SERVICE_PORT[$1]:-}"; }
version_of() { echo "${SERVICE_VERSION[$1]:-$1}"; }
native_service_of() { echo "${NATIVE_SERVICE[$1]:-}"; }

family_of() {
    case "$1" in
        php74|php84|php85) echo "php" ;;
        mariadb10|mariadb11) echo "db" ;;
        postgres15|postgres17) echo "pg" ;;
        *) echo "util" ;;
    esac
}

# ------------------------------------------------------------
#  Environment (.env) Configuration Manager
# ------------------------------------------------------------
load_env() {
    if [ ! -f "$ENV_FILE" ]; then
        PHP_CURRENT="php85"
        DB_CURRENT="mariadb11"
        PG_CURRENT="postgres17"
        NODE_CURRENT="22"
        PHP_MODE="container"
        DB_MODE="container"
        PG_MODE="container"
        save_env
        return
    fi
    # shellcheck disable=SC1090
    source "$ENV_FILE"
}

save_env() {
    mkdir -p "$(dirname "$ENV_FILE")"
    umask 077
    {
        echo "PHP_CURRENT=${PHP_CURRENT:-php85}"
        echo "DB_CURRENT=${DB_CURRENT:-mariadb11}"
        echo "PG_CURRENT=${PG_CURRENT:-postgres17}"
        echo "NODE_CURRENT=${NODE_CURRENT:-22}"
        echo "PHP_MODE=${PHP_MODE:-container}"
        echo "DB_MODE=${DB_MODE:-container}"
        echo "PG_MODE=${PG_MODE:-container}"
        echo "BEARS_DIR=${BEARS_DIR:-$HOME/bearsnprmp}"
        echo "WWW_DIR=${WWW_DIR:-/var/www}"
    } > "$ENV_FILE"
}

# ------------------------------------------------------------
#  Docker Compose Helper
# ------------------------------------------------------------
compose() {
    ( cd "$BEARS_DIR" && docker compose "$@" )
}

compose_ps() {
    compose ps -a --format '{{.Service}}\t{{.Status}}' 2>/dev/null
}

is_container_running() {
    local name="$1"
    compose_ps | awk -F'\t' -v s="$name" '$1==s && $2 ~ /^(Up|running|healthy|starting)/ {found=1} END {exit !found}'
}

# Network IP resolver
get_host_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}
