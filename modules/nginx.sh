#!/bin/bash
# ============================================================
#  BearsNPRMP — Nginx Universal Installer & Configurator
# ============================================================

install_nginx() {
    info "Instalando y configurando Nginx en $OS_NAME..."

    local nginx_pkg
    nginx_pkg="$(pkg_get_nginx_package)"

    if ! command -v nginx >/dev/null 2>&1; then
        info "Instalando paquete $nginx_pkg..."
        pkg_install "$nginx_pkg"
    else
        ok "Nginx ya está instalado."
    fi

    local nginx_dir="/etc/nginx"
    local sites_available="$nginx_dir/sites-available"
    local sites_enabled="$nginx_dir/sites-enabled"

    # Ensure sites-available / sites-enabled directories exist
    run_root mkdir -p "$sites_available" "$sites_enabled"

    # Ensure nginx.conf includes sites-enabled (standard on Debian/Ubuntu, requires setup on RHEL/Arch)
    local conf_file="$nginx_dir/nginx.conf"
    if [ -f "$conf_file" ]; then
        if ! grep -q "sites-enabled" "$conf_file"; then
            info "Configurando inclusión de sites-enabled en $conf_file..."
            # Insert before the last closing brace of http block
            if grep -q "http {" "$conf_file"; then
                run_root sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' "$conf_file"
            else
                run_root sh -c "echo 'include /etc/nginx/sites-enabled/*;' >> $conf_file"
            fi
        fi
    fi

    # Ensure /var/www exists and has correct permissions
    run_root mkdir -p "$WWW_DIR"
    
    # Resolve web server group (www-data on Debian/Ubuntu, nginx on RHEL/Fedora/Arch)
    local web_group="www-data"
    if getent group www-data >/dev/null 2>&1; then
        web_group="www-data"
    elif getent group nginx >/dev/null 2>&1; then
        web_group="nginx"
    else
        run_root groupadd www-data 2>/dev/null || true
        web_group="www-data"
    fi

    run_root chgrp -R "$web_group" "$WWW_DIR" 2>/dev/null || true
    run_root chmod -R 2775 "$WWW_DIR" 2>/dev/null || true
    if [ "$(id -u)" -ne 0 ]; then
        run_root usermod -aG "$web_group" "$USER" 2>/dev/null || true
    fi

    # Create default autoindex welcome page if /var/www is empty
    if [ ! -f "$WWW_DIR/index.php" ] && [ ! -f "$WWW_DIR/index.html" ]; then
        run_root sh -c "cat > $WWW_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>BearsNPRMP — Stack Activo</title>
    <style>
        body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
        .card { background: #1e293b; padding: 2.5rem; border-radius: 1rem; border: 1px solid #334155; max-width: 600px; text-align: center; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }
        h1 { color: #38bdf8; margin-top: 0; }
        p { color: #94a3b8; line-height: 1.6; }
        .btn { display: inline-block; background: #0284c7; color: white; padding: 0.75rem 1.5rem; border-radius: 0.5rem; text-decoration: none; font-weight: bold; margin-top: 1rem; }
        .btn:hover { background: #0369a1; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🐻 BearsNPRMP Stack</h1>
        <p>¡El stack de desarrollo web está funcionando correctamente!</p>
        <p>Coloca tus proyectos en <code>/var/www/&lt;tu-carpeta&gt;</code> y crea un virtual host con <code>vhost.sh</code> o desde el panel de control.</p>
        <a href="http://127.0.0.1:8088" class="btn">Abrir Panel Web</a>
    </div>
</body>
</html>
EOF
    fi

    # Verify Nginx configuration and start service
    if run_root nginx -t 2>/dev/null; then
        if is_systemd; then
            run_root systemctl enable nginx 2>/dev/null || true
            run_root systemctl restart nginx 2>/dev/null || true
        elif [ "$INIT_SYSTEM" = "openrc" ]; then
            run_root rc-update add nginx default 2>/dev/null || true
            run_root service nginx restart 2>/dev/null || true
        fi
        ok "Nginx instalado, configurado y activo."
    else
        warn "Nginx instalado pero la prueba de configuración falló. Revisa: sudo nginx -t"
    fi
}
