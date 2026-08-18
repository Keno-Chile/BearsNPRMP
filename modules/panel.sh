#!/bin/bash
# ============================================================
#  BearsNPRMP — CLI Control Panel
# ============================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/helpers.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/detect.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/services.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/vhost.sh"

load_env

svc_status_icon() {
    if is_svc_running "$1"; then
        printf "%s" "${GREEN}⬆ UP${RESET}"
    else
        printf "%s" "${RED}⬇ DOWN${RESET}"
    fi
}

cmd_status() {
    hr
    printf "   🟢  %sBEARS-NPRMP — ESTADO DEL STACK%s  (%s)\n" "$BOLD" "$RESET" "$(get_host_ip)"
    hr
    printf "  %-14s %-16s %-8s %s\n" "SERVICIO" "VERSIÓN" "PUERTO" "ESTADO"
    sep
    for svc in "${PHP_FAMILY[@]}" "${DB_FAMILY[@]}" "${PG_FAMILY[@]}" redis mailpit roadrunner; do
        printf "  %-14s %-16s %-8s %b\n" "$svc" "$(version_of "$svc")" "$(port_of "$svc")" "$(svc_status_icon "$svc")"
    done
    sep
    printf "  Activos actual → PHP: %s%s%s | MariaDB: %s%s%s | Postgres: %s%s%s | Node: %s%s%s\n" \
        "$GREEN" "$PHP_CURRENT" "$RESET" "$GREEN" "$DB_CURRENT" "$RESET" "$GREEN" "$PG_CURRENT" "$RESET" "$GREEN" "$NODE_CURRENT" "$RESET"
    hr
}

cmd_panel_server() {
    local action="${1:-status}"
    local webpanel_dir="$(dirname "${BASH_SOURCE[0]}")/../webpanel"
    local token_file="$CONFIG_DIR/panel_token"

    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$token_file" ]; then
        if command -v openssl >/dev/null 2>&1; then
            openssl rand -hex 16 > "$token_file"
        else
            date +%s%N | sha256sum | head -c 32 > "$token_file"
        fi
        chmod 600 "$token_file"
    fi

    case "$action" in
        start)
            if pgrep -f "php.*router.php" >/dev/null 2>&1; then
                ok "El panel web ya está en ejecución."
            else
                info "Iniciando servidor del panel web en el puerto 8088..."
                nohup php -S 0.0.0.0:8088 -t "$webpanel_dir" "$webpanel_dir/router.php" >/dev/null 2>&1 &
                sleep 1
                ok "Panel web activo en: http://127.0.0.1:8088"
            fi
            ;;
        stop)
            pkill -f "php.*router.php" 2>/dev/null && ok "Panel web detenido." || warn "El panel web no estaba corriendo."
            ;;
        token)
            printf "🔑 Token de seguridad del panel: %s%s%s\n" "$GREEN" "$(cat "$token_file")" "$RESET"
            printf "   Acceso directo: http://127.0.0.1:8088/?token=%s\n" "$(cat "$token_file")"
            ;;
        status|*)
            if pgrep -f "php.*router.php" >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8088/api/ping >/dev/null 2>&1; then
                ok "Panel Web: Activo → http://127.0.0.1:8088"
            else
                warn "Panel Web: Detenido (usa: panel.sh --panel start)"
            fi
            ;;
    esac
}

ssl_menu() {
    echo
    hr
    printf "   🔒  %sGESTIÓN SSL%s\n" "$BOLD" "$RESET"
    hr
    printf "  [1] Generar certificado para un dominio\n"
    printf "  [2] Generar wildcard (*.test)\n"
    printf "  [3] Listar certificados\n"
    printf "  [4] Eliminar certificado\n"
    printf "  [5] Instalar mkcert (recomendado)\n"
    printf "  [6] Eliminar todos los certificados\n"
    printf "  [V] Volver al menú principal\n"
    hr
    echo -n "Selecciona una opción: "
    read -r ssl_op
    case "$ssl_op" in
        1) echo -n "Dominio (ej: api.test): "; read -r d; ssl_detect_backend; ssl_generate_cert "$d" ;;
        2) ssl_detect_backend; ssl_generate_wildcard ;;
        3) ssl_list ;;
        4) echo -n "Dominio a eliminar: "; read -r d; ssl_delete_cert "$d" ;;
        5) ssl_install_mkcert ;;
        6) ssl_purge ;;
        [Vv]) return ;;
    esac
    echo -n "Presiona enter para continuar..."; read -r
}

show_menu() {
    clear
    hr
    printf "          🐻  %sBEARS-NPRMP CONTROL PANEL%s  🐻\n" "$BOLD" "$RESET"
    hr
    printf "  [1] Versión PHP       → Actual: %s%s%s (modo %s)\n" "$GREEN" "$PHP_CURRENT" "$RESET" "$PHP_MODE"
    printf "  [2] Versión MariaDB   → Actual: %s%s%s (modo %s)\n" "$GREEN" "$DB_CURRENT" "$RESET" "$DB_MODE"
    printf "  [3] Versión Postgres  → Actual: %s%s%s (modo %s)\n" "$GREEN" "$PG_CURRENT" "$RESET" "$PG_MODE"
    printf "  [4] Versión Node.js   → Actual: %s%s%s\n" "$GREEN" "$NODE_CURRENT" "$RESET"
    sep
printf "  [5] 🌐 Crear Virtual Host       [6] 📋 Listar Virtual Hosts\n"
printf "  [7] 🌍 Panel Web (Abrir/Token)  [8] 🩺 Ver Estado Completo\n"
printf "  [9] 🔒 Gestión SSL              [0] ❌ Salir\n"
    sep
    printf "  [I] Iniciar Todo   [D] Detener Todo   [R] Reiniciar   [X] Salir\n"
    hr
    echo -n "Selecciona una opción: "
}

menu_loop() {
    while true; do
        show_menu
        read -r op
        case "$op" in
            1)
                echo "1) PHP 7.4 (9002)   2) PHP 8.4 (9001)   3) PHP 8.5 (9000)"
                echo -n "Selecciona: "; read -r pv
                case "$pv" in 1) switch_version php php74 ;; 2) switch_version php php84 ;; *) switch_version php php85 ;; esac
                sleep 1 ;;
            2)
                echo "1) MariaDB 10.11 (3307)   2) MariaDB 11.4 (3306)"
                echo -n "Selecciona: "; read -r mv
                case "$mv" in 1) switch_version db mariadb10 ;; *) switch_version db mariadb11 ;; esac
                sleep 1 ;;
            3)
                echo "1) Postgres 15 (5433)   2) Postgres 17 (5432)"
                echo -n "Selecciona: "; read -r pgv
                case "$pgv" in 1) switch_version pg postgres15 ;; *) switch_version pg postgres17 ;; esac
                sleep 1 ;;
            4)
                echo -n "Versión de Node.js a activar (ej: 20, 22): "; read -r nv
                if command -v fnm >/dev/null 2>&1; then
                    fnm use "$nv" && NODE_CURRENT="$nv" && save_env
                fi
                sleep 1 ;;
            5) vhost_create; echo -n "Presiona enter para continuar..."; read -r ;;
            6) vhost_list; echo -n "Presiona enter para continuar..."; read -r ;;
            7) cmd_panel_server start; cmd_panel_server token; echo -n "Presiona enter para continuar..."; read -r ;;
            8) cmd_status; echo -n "Presiona enter para continuar..."; read -r ;;
            [Ii]) start_stack; sleep 1 ;;
            [Dd]) stop_stack; sleep 1 ;;
            [Rr]) restart_stack; sleep 1 ;;
            [Xx]) clear; exit 0 ;;
            [0]) clear; exit 0 ;;
            9) ssl_menu ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --status) cmd_status ;;
        --up|--start) start_stack ;;
        --down|--stop) stop_stack ;;
        --restart) restart_stack ;;
        --panel) cmd_panel_server "${2:-status}" ;;
        --switch) switch_version "$2" "$3" ;;
        *) menu_loop ;;
    esac
fi
