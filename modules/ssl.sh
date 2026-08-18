#!/bin/bash
# ============================================================
#  BearsNPRMP — SSL/TLS Module for Local Development
#  Supports:
#    - Self-signed CA + certificates (openssl)
#    - mkcert (trusted by browsers, requires nss tools on Linux)
#  Generates certs per domain and configures Nginx SSL vhosts
# ============================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/helpers.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../core/detect.sh"

SSL_DIR="${SSL_DIR:-$HOME/.config/bearsnprmp/ssl}"
CA_DIR="$SSL_DIR/ca"
CERTS_DIR="$SSL_DIR/certs"
USE_MKCERT=0

# Detect mkcert availability
ssl_detect_backend() {
    if command -v mkcert >/dev/null 2>&1; then
        USE_MKCERT=1
        info "Backend SSL: mkcert (certificados confiables por el navegador)"
    else
        USE_MKCERT=0
        info "Backend SSL: OpenSSL (certificados autofirmados)"
    fi
}

# Ensure SSL directories exist
ssl_init() {
    run_root mkdir -p "$CA_DIR" "$CERTS_DIR"
}

# Install mkcert if not present (best-effort)
ssl_install_mkcert() {
    if command -v mkcert >/dev/null 2>&1; then
        ok "mkcert ya está instalado."
        return 0
    fi

    info "Intentando instalar mkcert..."

    case "${PKG_MGR:-}" in
        apt)
            # mkcert needs libnss3-tools for certutil
            pkg_install mkcert libnss3-tools 2>/dev/null || {
                # Manual install fallback
                retry 3 curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64" -o /usr/local/bin/mkcert
                run_root chmod +x /usr/local/bin/mkcert
            }
            ;;
        dnf|yum)
            pkg_install mkcert nss-tools 2>/dev/null || {
                retry 3 curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64" -o /usr/local/bin/mkcert
                run_root chmod +x /usr/local/bin/mkcert
            }
            ;;
        pacman)
            pkg_install mkcert nss 2>/dev/null || {
                retry 3 curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64" -o /usr/local/bin/mkcert
                run_root chmod +x /usr/local/bin/mkcert
            }
            ;;
        *)
            retry 3 curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64" -o /tmp/mkcert
            run_root install -m 755 /tmp/mkcert /usr/local/bin/mkcert
            rm -f /tmp/mkcert
            ;;
    esac

    if command -v mkcert >/dev/null 2>&1; then
        # Install the local CA
        mkcert -install 2>/dev/null || warn "No se pudo instalar la CA local de mkcert (puede requerir sudo)."
        ok "mkcert instalado correctamente."
        USE_MKCERT=1
        return 0
    else
        warn "No se pudo instalar mkcert. Usando OpenSSL (certificados autofirmados)."
        USE_MKCERT=0
        return 1
    fi
}

# Generate self-signed CA (OpenSSL only)
ssl_create_ca() {
    local ca_key="$CA_DIR/bears-ca.key"
    local ca_cert="$CA_DIR/bears-ca.crt"

    if [ -f "$ca_key" ] && [ -f "$ca_cert" ]; then
        ok "CA local ya existe: $ca_cert"
        return 0
    fi

    info "Generando Autoridad de Certificación (CA) local..."

    openssl genrsa -out "$ca_key" 2048 2>/dev/null
    openssl req -x509 -new -nodes -key "$ca_key" -sha256 -days 3650 \
        -out "$ca_cert" \
        -subj "/C=CL/ST=Santiago/L=Santiago/O=BearsNPRMP/CN=BearsNPRMP Local CA" 2>/dev/null

    chmod 600 "$ca_key"
    ok "CA local generada: $ca_cert"
}

# Generate certificate for a specific domain
ssl_generate_cert() {
    local domain="$1"
    local cert_dir="$CERTS_DIR/$domain"
    local cert_file="$cert_dir/$domain.crt"
    local key_file="$cert_dir/$domain.key"
    local csr_file="$cert_dir/$domain.csr"

    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
        ok "Certificado ya existe para: $domain"
        return 0
    fi

    ssl_init

    if [ "$USE_MKCERT" -eq 1 ]; then
        info "Generando certificado con mkcert para: $domain"
        run_root mkdir -p "$cert_dir"
        mkcert -cert-file "$cert_file" -key-file "$key_file" \
            "$domain" "localhost" "127.0.0.1" "::1" 2>/dev/null
    else
        info "Generando certificado autofirmado para: $domain"

        # Ensure CA exists
        ssl_create_ca

        run_root mkdir -p "$cert_dir"

        # Generate private key
        openssl genrsa -out "$key_file" 2048 2>/dev/null

        # Create SAN config
        local san_config="$cert_dir/san.cnf"
        cat > "$san_config" <<EOFCNF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
req_extensions = v3_req

[dn]
C = CL
ST = Santiago
L = Santiago
O = BearsNPRMP
CN = $domain

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = localhost
DNS.3 = *.${domain#*.}
IP.1 = 127.0.0.1
IP.2 = ::1
EOFCNF

        # Generate CSR
        openssl req -new -key "$key_file" -out "$csr_file" -config "$san_config" 2>/dev/null

        # Sign with CA
        openssl x509 -req -in "$csr_file" \
            -CA "$CA_DIR/bears-ca.crt" \
            -CAkey "$CA_DIR/bears-ca.key" \
            -CAcreateserial \
            -out "$cert_file" \
            -days 365 -sha256 \
            -extensions v3_req \
            -extfile "$san_config" 2>/dev/null

        rm -f "$csr_file" "$san_config"
    fi

    chmod 600 "$key_file"
    chmod 644 "$cert_file"

    ok "Certificado SSL generado para: $domain"
    info "  Cert: $cert_file"
    info "  Key:  $key_file"

    if [ "$USE_MKCERT" -eq 0 ]; then
        warn "Certificado autofirmado. Para evitar alertas del navegador, instala la CA en tu sistema."
        info "  CA: $CA_DIR/bears-ca.crt"
    fi
}

# Generate wildcard certificate for *.test domains
ssl_generate_wildcard() {
    local base_domain="${1:-bearsnprmp.test}"
    local cert_dir="$CERTS_DIR/wildcard"
    local cert_file="$cert_dir/wildcard.crt"
    local key_file="$cert_dir/wildcard.key"

    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
        ok "Wildcard certificate ya existe para: *.$base_domain"
        return 0
    fi

    ssl_init

    if [ "$USE_MKCERT" -eq 1 ]; then
        info "Generando wildcard certificate con mkcert: *.$base_domain"
        run_root mkdir -p "$cert_dir"
        mkcert -cert-file "$cert_file" -key-file "$key_file" \
            "*.$base_domain" "$base_domain" "localhost" 2>/dev/null
    else
        ssl_create_ca

        info "Generando wildcard certificate autofirmado: *.$base_domain"
        run_root mkdir -p "$cert_dir"

        openssl genrsa -out "$key_file" 2048 2>/dev/null

        local san_config="$cert_dir/san.cnf"
        cat > "$san_config" <<EOFCNF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
req_extensions = v3_req

[dn]
C = CL
ST = Santiago
L = Santiago
O = BearsNPRMP
CN = *.$base_domain

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.$base_domain
DNS.2 = $base_domain
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOFCNF

        openssl req -new -key "$key_file" -out "$cert_dir/wildcard.csr" -config "$san_config" 2>/dev/null

        openssl x509 -req -in "$cert_dir/wildcard.csr" \
            -CA "$CA_DIR/bears-ca.crt" \
            -CAkey "$CA_DIR/bears-ca.key" \
            -CAcreateserial \
            -out "$cert_file" \
            -days 365 -sha256 \
            -extensions v3_req \
            -extfile "$san_config" 2>/dev/null

        rm -f "$cert_dir/wildcard.csr" "$san_config"
    fi

    chmod 600 "$key_file"
    chmod 644 "$cert_file"

    ok "Wildcard certificate generado: *.$base_domain"
}

# List all certificates
ssl_list() {
    hr
    printf "   🔒  CERTIFICADOS SSL  (%s)\n" "$SSL_DIR"
    hr

    if [ ! -d "$CERTS_DIR" ] || [ -z "$(ls -A "$CERTS_DIR" 2>/dev/null)" ]; then
        echo "   No hay certificados generados aún."
        hr
        return 0
    fi

    for d in "$CERTS_DIR"/*/; do
        [ -d "$d" ] || continue
        local name
        name=$(basename "$d")
        local cert="$d/$name.crt"
        [ "$name" = "wildcard" ] && cert="$d/wildcard.crt"
        if [ -f "$cert" ]; then
            local expiry
            expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
            printf "  • %-25s expira: %s\n" "$name" "$expiry"
        fi
    done
    hr
}

# Delete certificate for a domain
ssl_delete_cert() {
    local domain="$1"
    [ -z "$domain" ] && { fail "Especifica el dominio."; return 1; }

    local cert_dir="$CERTS_DIR/$domain"
    if [ -d "$cert_dir" ]; then
        run_root rm -rf "$cert_dir"
        ok "Certificado eliminado para: $domain"
    else
        warn "No se encontró certificado para: $domain"
    fi
}

# Delete everything (CA + all certs)
ssl_purge() {
    info "Eliminando todos los certificados y la CA local..."
    run_root rm -rf "$SSL_DIR"
    ok "Todos los certificados SSL eliminados."
}

# CLI dispatcher
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init)       ssl_detect_backend; ssl_init ;;
        gen)        ssl_detect_backend; ssl_generate_cert "${2:-}" ;;
        wildcard)   ssl_detect_backend; ssl_generate_wildcard "${2:-bearsnprmp.test}" ;;
        list)       ssl_list ;;
        delete)     ssl_delete_cert "${2:-}" ;;
        purge)      ssl_purge ;;
        install-mkcert) ssl_install_mkcert ;;
        *)
            echo "Uso: ssl.sh {init|gen <domain>|wildcard [domain]|list|delete <domain>|purge|install-mkcert}"
            exit 1
            ;;
    esac
fi
