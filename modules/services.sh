#!/bin/bash
# ============================================================
#  BearsNPRMP — Services Lifecycle & Mode Manager
#  Supports:
#    - Docker mode (docker compose)
#    - Native mode (systemd / OpenRC)
#    - Hybrid mode (per family configuration)
# ============================================================

# Ensure core modules are loaded
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/helpers.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/detect.sh"

load_env

# Determine effective mode for a service family (php, db, pg)
family_mode() {
    case "$1" in
        php) echo "${PHP_MODE:-container}" ;;
        db)  echo "${DB_MODE:-container}" ;;
        pg)  echo "${PG_MODE:-container}" ;;
        *)   echo "container" ;;
    esac
}

svc_mode() {
    local f
    f=$(family_of "$1")
    [ "$f" = "util" ] && { echo "container"; return; }
    family_mode "$f"
}

is_svc_running() {
    local svc="$1"
    local mode
    mode=$(svc_mode "$svc")

    if [ "$mode" = "native" ]; then
        local ns
        ns=$(native_service_of "$svc")
        if [ -n "$ns" ]; then
            if is_systemd; then
                systemctl is-active --quiet "$ns" 2>/dev/null
            elif [ "$INIT_SYSTEM" = "openrc" ]; then
                rc-service "$ns" status >/dev/null 2>&1
            fi
        else
            return 1
        fi
    else
        is_container_running "$svc"
    fi
}

svc_start() {
    local svc="$1"
    local mode
    mode=$(svc_mode "$svc")

    if [ "$mode" = "native" ]; then
        local ns
        ns=$(native_service_of "$svc")
        if [ -n "$ns" ]; then
            if is_systemd; then
                run_root systemctl start "$ns" 2>/dev/null || {
                    warn "No se pudo iniciar servicio nativo: $ns"
                    return 1
                }
            elif [ "$INIT_SYSTEM" = "openrc" ]; then
                run_root service "$ns" start 2>/dev/null || return 1
            fi
        fi
    else
        if ! compose up -d "$svc" >/dev/null 2>&1; then
            warn "No se pudo iniciar contenedor Docker: $svc"
            return 1
        fi
    fi
    return 0
}

svc_stop() {
    local svc="$1"
    local mode
    mode=$(svc_mode "$svc")

    if [ "$mode" = "native" ]; then
        local ns
        ns=$(native_service_of "$svc")
        if [ -n "$ns" ]; then
            if is_systemd; then
                run_root systemctl stop "$ns" 2>/dev/null || true
            elif [ "$INIT_SYSTEM" = "openrc" ]; then
                run_root service "$ns" stop 2>/dev/null || true
            fi
        fi
    else
        compose stop "$svc" >/dev/null 2>&1 || true
    fi
}

start_stack() {
    info "Iniciando servicios activos del stack..."
    load_env
    svc_start "$PHP_CURRENT"
    svc_start "$DB_CURRENT"
    svc_start "$PG_CURRENT"
    compose up -d redis mailpit roadrunner >/dev/null 2>&1 || true
    ok "Stack iniciado con éxito."
}

stop_stack() {
    info "Deteniendo servicios del stack..."
    load_env
    svc_stop "$PHP_CURRENT"
    svc_stop "$DB_CURRENT"
    svc_stop "$PG_CURRENT"
    compose stop redis mailpit roadrunner >/dev/null 2>&1 || true
    ok "Stack detenido."
}

restart_stack() {
    stop_stack
    sleep 1
    start_stack
}

switch_version() {
    local family="$1"
    local version="$2"
    local list=()

    case "$family" in
        php) list=("${PHP_FAMILY[@]}"); PHP_CURRENT="$version" ;;
        db)  list=("${DB_FAMILY[@]}");  DB_CURRENT="$version" ;;
        pg)  list=("${PG_FAMILY[@]}");  PG_CURRENT="$version" ;;
        *)   fail "Familia inválida: $family (usa php, db, pg)"; return 1 ;;
    esac

    for s in "${list[@]}"; do
        [ "$s" != "$version" ] && svc_stop "$s"
    done

    save_env
    svc_start "$version"
    ok "Versión cambiada: $family ahora es $version (modo: $(svc_mode "$version"))"
}
