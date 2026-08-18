#!/bin/bash
# ============================================================
#  BearsNPRMP — Docker & Docker Compose Universal Installer
# ============================================================

install_docker() {
    info "Verificando disponibilidad de Docker Engine y Docker Compose..."

    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        ok "Docker Engine y Docker Compose ya están instalados."
    else
        info "Instalando Docker Engine para $OS_NAME ($PKG_MGR)..."

        case "$PKG_MGR" in
            apt|dnf|yum|zypper)
                # Official Docker install script works flawlessly on Debian/Ubuntu/Fedora/RHEL/SUSE
                info "Ejecutando instalador oficial de Docker (get.docker.com)..."
                retry 3 curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
                run --sudo sh /tmp/get-docker.sh
                rm -f /tmp/get-docker.sh
                ;;
            pacman)
                pkg_install docker docker-compose
                ;;
            apk)
                pkg_install docker docker-cli-compose
                ;;
            *)
                fail "Distribución no soportada automáticamente para Docker: $OS_ID"
                return 1
                ;;
        esac
    fi

    # Configure Docker group
    if [ "$(id -u)" -ne 0 ]; then
        if ! getent group docker >/dev/null 2>&1; then
            run --sudo groupadd docker 2>/dev/null || true
        fi
        if ! id -nG "$USER" | grep -qw docker; then
            info "Añadiendo usuario '$USER' al grupo docker..."
            run --sudo usermod -aG docker "$USER" 2>/dev/null || run --sudo adduser "$USER" docker 2>/dev/null || true
            ok "Usuario añadido al grupo docker (se aplicará en nuevas sesiones)."
        fi
    fi

    # Start and enable Docker service according to init system
    if is_systemd; then
        info "Habilitando servicio Docker vía systemd..."
        run --sudo systemctl enable docker 2>/dev/null || true
        run --sudo systemctl start docker 2>/dev/null || true
    elif [ "$INIT_SYSTEM" = "openrc" ]; then
        info "Habilitando servicio Docker vía OpenRC..."
        run --sudo rc-update add docker default 2>/dev/null || true
        run --sudo service docker start 2>/dev/null || true
    fi

    # Test docker daemon connectivity
    local _i=0 docker_ready=0
    while [ "$_i" -lt 15 ]; do
        if run --sudo docker info >/dev/null 2>&1; then
            docker_ready=1
            break
        fi
        sleep 2
        _i=$((_i + 1))
    done

    if [ "$docker_ready" = "1" ]; then
        ok "Docker daemon activo y listo."
    else
        warn "Docker instalado pero el daemon no respondió de inmediato. Puede requerir reiniciar la sesión."
    fi
}
