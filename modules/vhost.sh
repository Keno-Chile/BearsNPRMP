#!/bin/bash
# ============================================================
#  BearsNPRMP — Virtual Host Manager (Nginx *.test)
# ============================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/helpers.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/detect.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/ssl.sh"

load_env

NGINX_DIR="${NGINX_DIR:-/etc/nginx}"
SITES_AVAILABLE="$NGINX_DIR/sites-available"
SITES_ENABLED="$NGINX_DIR/sites-enabled"
TEMPLATES_DIR="$(dirname "${BASH_SOURCE[0]}")/../templates/nginx"

hosts_has() {
    local d="$1"
    awk -v d="$d" '{for(i=2;i<=NF;i++) if($i==d) f=1} END{exit !f}' /etc/hosts 2>/dev/null
}

win_hosts_add() {
    local d="$1"
    # ONLY available when running inside WSL
    if ! is_wsl; then return 0; fi

    local win_hosts="/mnt/c/Windows/System32/drivers/etc/hosts"
    if [ -f "$win_hosts" ]; then
        if grep -qE "(^|\s)$d(\s|$)" "$win_hosts" 2>/dev/null; then
            return 0
        fi
        if [ -w "$win_hosts" ]; then
            printf "\r\n127.0.0.1 %s\r\n" "$d" >> "$win_hosts" 2>/dev/null && ok "Dominio '$d' sincronizado con el archivo hosts de Windows." && return 0
        fi
    fi

    # Fallback via powershell.exe when running in WSL
    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -NonInteractive -Command "
            \$hostsPath = \"\$env:SystemRoot\System32\drivers\etc\hosts\";
            if (Test-Path \$hostsPath) {
                \$content = Get-Content \$hostsPath -Raw -ErrorAction SilentlyContinue;
                if (\$content -notmatch '(?m)^\s*127\.0\.0\.1\s+$d\b') {
                    try {
                        Add-Content -Path \$hostsPath -Value \"`r`n127.0.0.1 $d\" -ErrorAction Stop;
                        Write-Output 'OK';
                    } catch {}
                }
            }
        " 2>/dev/null | grep -q "OK" && ok "Dominio '$d' sincronizado automáticamente con Windows hosts." || true
    fi
}

win_hosts_del() {
    local d="$1"
    # ONLY available when running inside WSL
    if ! is_wsl; then return 0; fi

    local win_hosts="/mnt/c/Windows/System32/drivers/etc/hosts"
    if [ -f "$win_hosts" ] && [ -w "$win_hosts" ]; then
        sed -i "/127\.0\.0\.1\s\+$d/d" "$win_hosts" 2>/dev/null && ok "Dominio '$d' removido del archivo hosts de Windows." && return 0
    fi

    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -NonInteractive -Command "
            \$hostsPath = \"\$env:SystemRoot\System32\drivers\etc\hosts\";
            if (Test-Path \$hostsPath) {
                \$lines = (Get-Content \$hostsPath) | Where-Object { \$_ -notmatch '^\s*127\.0\.0\.1\s+$d\b' };
                try {
                    \$lines | Set-Content -Path \$hostsPath -ErrorAction Stop;
                } catch {}
            }
        " 2>/dev/null || true
    fi
}

hosts_add() {
    local d="$1"
    if ! hosts_has "$d"; then
        run_root sh -c "echo '127.0.0.1 $d' >> /etc/hosts"
        ok "Añadido a /etc/hosts local: 127.0.0.1 $d"
    fi

    # Synchronize with Windows hosts ONLY when running on WSL
    if is_wsl; then
        win_hosts_add "$d"
    fi
}

hosts_del() {
    local d="$1"
    if hosts_has "$d"; then
        local tmp
        tmp=$(mktemp)
        run_root awk -v d="$d" '{f=0; for(i=2;i<=NF;i++) if($i==d) f=1; if(!f) print}' /etc/hosts > "$tmp"
        run_root install -m 644 "$tmp" /etc/hosts
        rm -f "$tmp"
        ok "Eliminado de /etc/hosts local: $d"
    fi

    # Synchronize with Windows hosts ONLY when running on WSL
    if is_wsl; then
        win_hosts_del "$d"
    fi
}

# Detect Nginx major.minor version (e.g. "1.22")
nginx_version() {
    nginx -v 2>&1 | sed -n 's|.*nginx/\([0-9]*\.[0-9]*\).*|\1|p' || echo "0.0"
}

# Fix http2 directive for Nginx < 1.25
fix_ssl_config() {
    local conf_file="$1"
    local ver
    ver=$(nginx_version)
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)

    if [ "$major" -lt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -lt 25 ]; }; then
        # Nginx < 1.25: 'listen 443 ssl http2' is the only supported syntax
        local tmp
        tmp=$(mktemp)
        awk '
            /listen 443 ssl;/ { gsub(/listen 443 ssl;/, "listen 443 ssl http2;") }
            /listen \[::\]:443 ssl;/ { gsub(/listen \[::\]:443 ssl;/, "listen [::]:443 ssl http2;") }
            /http2 on;/ { next }
            { print }
        ' "$conf_file" > "$tmp"
        run_root install -m 644 "$tmp" "$conf_file"
        rm -f "$tmp"
    fi
}

nginx_reload() {
    if ! run_root nginx -t 2>/dev/null; then
        fail "La configuración de Nginx contiene errores de sintaxis."
        return 1
    fi
    if is_systemd; then
        run_root systemctl reload nginx 2>/dev/null || run_root systemctl restart nginx 2>/dev/null
    else
        run_root nginx -s reload 2>/dev/null
    fi
    ok "Nginx recargado correctamente."
}

vhost_create() {
    local domain="" folder="" backend="fpm" php_ver="" is_laravel=0 use_ssl=1

    while [ $# -gt 0 ]; do
        case "$1" in
            --domain) domain="$2"; shift 2 ;;
            --folder) folder="$2"; shift 2 ;;
            --backend) backend="$2"; shift 2 ;;
            --php) php_ver="$2"; shift 2 ;;
            --laravel) is_laravel=1; shift ;;
            --no-ssl) use_ssl=0; shift ;;
            *) shift ;;
        esac
    done

    # Interactive prompts if arguments are missing
    if [ -z "$domain" ]; then
        echo -n "Dominio del vhost (ej: mi-proyecto.test): "
        read -r domain
    fi
    [ -z "$domain" ] && { fail "El dominio no puede estar vacío."; return 1; }

    if [ -z "$folder" ]; then
        echo -n "Carpeta dentro de /var/www (ej: mi-proyecto): "
        read -r folder
    fi
    [ -z "$folder" ] && folder="$domain"

    local root_path="$WWW_DIR/$folder"
    if [ "$is_laravel" -eq 1 ]; then
        root_path="$WWW_DIR/$folder/public"
    fi

    # Ensure directory exists
    run_root mkdir -p "$root_path"

    local php_port="9000"
    if [ -n "$php_ver" ]; then
        case "$php_ver" in
            74|7.4) php_port="9002" ;;
            84|8.4) php_port="9001" ;;
            85|8.5) php_port="9000" ;;
        esac
    else
        php_port=$(port_of "$PHP_CURRENT")
    fi

    local target_conf="$SITES_AVAILABLE/$domain"
    local tpl="$TEMPLATES_DIR/vhost_fpm.conf"
    [ "$backend" = "roadrunner" ] && tpl="$TEMPLATES_DIR/vhost_roadrunner.conf"

    if [ ! -f "$tpl" ]; then
        fail "Plantilla no encontrada: $tpl"
        return 1
    fi

    # SSL setup
    local ssl_cert="" ssl_key=""
    if [ "$use_ssl" -eq 1 ]; then
        ssl_detect_backend
        ssl_generate_cert "$domain"
        ssl_cert="$CERTS_DIR/$domain/$domain.crt"
        ssl_key="$CERTS_DIR/$domain/$domain.key"
    fi

    # Render config
    local rendered
    rendered=$(sed \
        -e "s|{{DOMAIN}}|$domain|g" \
        -e "s|{{ROOT_PATH}}|$root_path|g" \
        -e "s|{{PHP_PORT}}|$php_port|g" \
        -e "s|{{SSL_CERT}}|$ssl_cert|g" \
        -e "s|{{SSL_KEY}}|$ssl_key|g" \
        "$tpl")
    
    printf '%s\n' "$rendered" > /tmp/.bears_vhost_$$.conf
    run_root install -m 644 /tmp/.bears_vhost_$$.conf "$target_conf"
    rm -f /tmp/.bears_vhost_$$.conf

    # Fix http2 directive for Nginx version compatibility
    [ "$use_ssl" -eq 1 ] && fix_ssl_config "$target_conf"

    run_root ln -sf "$target_conf" "$SITES_ENABLED/$domain"

    nginx_reload || return 1
    hosts_add "$domain"

    hr
    local proto="http"
    [ "$use_ssl" -eq 1 ] && proto="https"
    ok "Virtual Host creado exitosamente: ${proto}://$domain"
    info "Ruta raíz : $root_path"
    info "Backend   : $backend (puerto $php_port)"
    [ "$use_ssl" -eq 1 ] && info "SSL       : Habilitado (autofirmado)"
    if is_wsl; then
        info "En Windows, añade a C:\\Windows\\System32\\drivers\\etc\\hosts:"
        printf "  %s  %s\n" "127.0.0.1" "$domain"
    fi
    hr
}

vhost_list() {
    local json_output=0
    [ "${1:-}" = "--json" ] && json_output=1

    shopt -s nullglob
    local confs=("$SITES_AVAILABLE"/*)
    shopt -u nullglob

    if [ "$json_output" -eq 1 ]; then
        local out="["
        local first=1
        for conf in "${confs[@]}"; do
            [ -f "$conf" ] || continue
            local dom enabled="false" root=""
            dom=$(basename "$conf")
            [ -L "$SITES_ENABLED/$dom" ] && enabled="true"
            root=$(grep -m1 '^\s*root ' "$conf" 2>/dev/null | awk '{print $2}' | tr -d ';')
            [ "$first" -eq 0 ] && out="$out,"
            out="$out{\"domain\":\"$dom\",\"enabled\":$enabled,\"root\":\"$root\"}"
            first=0
        done
        out="$out]"
        echo "$out"
        return 0
    fi

    hr
    printf "   📋  VIRTUAL HOSTS REGISTRADOS  (%s)\n" "$NGINX_DIR"
    hr
    if [ ${#confs[@]} -eq 0 ]; then
        echo "   No hay virtual hosts creados aún."
        hr
        return 0
    fi

    for conf in "${confs[@]}"; do
        [ -f "$conf" ] || continue
        local dom st="❌ Inactivo" root=""
        dom=$(basename "$conf")
        [ -L "$SITES_ENABLED/$dom" ] && st="✅ Activo"
        root=$(grep -m1 '^\s*root ' "$conf" 2>/dev/null | awk '{print $2}' | tr -d ';')
        printf "  • http://%-25s [%s]\n    Raíz: %s\n" "$dom" "$st" "$root"
    done
    hr
}

vhost_delete() {
    local domain="$1"
    [ -z "$domain" ] && { fail "Especifica el dominio a eliminar."; return 1; }

    run_root rm -f "$SITES_ENABLED/$domain" "$SITES_AVAILABLE/$domain"
    hosts_del "$domain"
    nginx_reload
    ok "Virtual Host '$domain' eliminado."
}

# CLI dispatcher if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        create) shift; vhost_create "$@" ;;
        list) shift; vhost_list "$@" ;;
        delete) shift; vhost_delete "$@" ;;
        reload) nginx_reload ;;
        *) echo "Uso: vhost.sh create|list|delete|reload"; exit 1 ;;
    esac
fi
