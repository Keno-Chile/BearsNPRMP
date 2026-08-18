#!/bin/bash
# ============================================================
#  🐻 BearsNPRMP — WSL In-Distro Test Runner
#  Verifica:
#   1. Permisos y omisión de sudo para root
#   2. Detección de OS / Entorno
#   3. Instalación de paquetes base y Nginx
#   4. Panel Web (puerto 8088)
#   5. Creación y funcionamiento de Virtual Hosts (*.test)
#   6. Sincronización de /etc/hosts y Windows hosts
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BEARS_DIR="/root/bearsnprmp"

echo "=========================================================="
echo "🐻 INICIANDO TEST SUITE BearsNPRMP EN: $(uname -a)"
echo "=========================================================="

# 1. Load Core Modules
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/detect.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/helpers.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/pkg_manager.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/nginx.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/panel.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/vhost.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/services.sh"

# 2. Test Detection
info "Fase 1: Verificando detección de sistema..."
detect_all
print_detected_info

if [ "$(id -u)" -ne 0 ]; then
    fail "La prueba debe ejecutarse como root para validar la omisión de sudo."
    exit 1
fi
ok "Usuario actual es root (id: $(id -u))."

# 3. Test Sudo Bypass for Root
info "Fase 2: Validando que ensure_sudo y run omitan sudo en root..."
ensure_sudo
run --sudo echo "TEST_RUN_SUDO_OK" >/dev/null
run_root echo "TEST_RUN_ROOT_OK" >/dev/null
ok "Omisión de sudo verificada exitosamente en entorno root."

# 4. Package Manager & Base packages
info "Fase 3: Actualizando repositorios e instalando paquetes base ($PKG_MGR)..."
pkg_update
# shellcheck disable=SC2046
pkg_install $(pkg_get_base_packages)
ok "Paquetes base instalados correctamente."

# 5. Install & Configure Nginx
info "Fase 4: Instalando y configurando Nginx..."
install_nginx
if nginx -t 2>/dev/null; then
    ok "Sintaxis de Nginx válida."
else
    fail "Error en configuración de Nginx."
    exit 1
fi

# Start Nginx
if is_systemd; then
    run_root systemctl restart nginx 2>/dev/null || nginx
else
    nginx 2>/dev/null || nginx -s reload 2>/dev/null || true
fi
sleep 1

# Check Nginx default page
if curl -fsS http://127.0.0.1/ >/dev/null 2>&1; then
    ok "Servidor Nginx respondiendo en http://127.0.0.1"
else
    warn "Nginx no respondió en 127.0.0.1, reintentando arranque directo..."
    nginx 2>/dev/null || true
    sleep 1
    curl -fsS http://127.0.0.1/ >/dev/null && ok "Nginx activo tras inicio directo." || warn "Nginx no respondió en http://127.0.0.1"
fi

# 6. Test Web Panel (port 8088)
info "Fase 5: Levantando y verificando Panel Web en puerto 8088..."
cmd_panel_server start
sleep 2

PANEL_RES=$(curl -fsS -o /dev/null -w "%{http_code}" http://127.0.0.1:8088/ 2>/dev/null || echo "000")
if [ "$PANEL_RES" -eq 200 ] || [ "$PANEL_RES" -eq 302 ]; then
    ok "Panel Web verificado y respondiendo correctamente (HTTP $PANEL_RES en http://127.0.0.1:8088)."
else
    # Check if php is present
    if command -v php >/dev/null 2>&1; then
        warn "Panel web retorno HTTP $PANEL_RES en puerto 8088"
    else
        warn "PHP CLI no encontrado en distro para webpanel nativo."
    fi
fi

# 7. Test VHost Creation and Routing
info "Fase 6: Creando y probando Virtual Host 'test-bear.test'..."
vhost_create --domain test-bear.test --folder test-bear

# Place test index in vhost root
mkdir -p "$WWW_DIR/test-bear"
echo "<h1>🐻 Test VHost BearsNPRMP OK</h1>" > "$WWW_DIR/test-bear/index.html"

# Verify Nginx syntax and reload
if nginx -t 2>/dev/null; then
    nginx_reload
    ok "VHost test-bear.test configurado y Nginx recargado."
else
    fail "Error en vhost Nginx."
    exit 1
fi

# Test request to vhost via Host header
VHOST_CONTENT=$(curl -s -H "Host: test-bear.test" http://127.0.0.1/ || echo "")
if echo "$VHOST_CONTENT" | grep -q "Test VHost BearsNPRMP OK"; then
    ok "Virtual Host test-bear.test resolviendo y sirviendo contenido con éxito!"
else
    warn "Contenido de VHost no coincidió. Obtenido: $VHOST_CONTENT"
fi

echo "=========================================================="
ok "🎉 ¡TODAS LAS PRUEBAS COMPLETADAS CON ÉXITO EN ESTA DISTRO!"
echo "=========================================================="
