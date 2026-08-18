#!/bin/bash
# ============================================================
#  BearsNPRMP — Node.js & fnm (Fast Node Manager) Module
# ============================================================

install_node() {
    local node_ver="${1:-22}"
    info "Configurando Node.js (versión $node_ver) vía fnm..."

    # Install fnm if not available
    if ! command -v fnm >/dev/null 2>&1 && [ ! -x "$HOME/.local/share/fnm/fnm" ]; then
        info "Instalando fnm (Fast Node Manager)..."
        retry 3 curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    fi

    # Set PATH and shell environment for fnm
    export PATH="$HOME/.local/share/fnm:$HOME/.fnm:$PATH"

    local fnm_bin
    if command -v fnm >/dev/null 2>&1; then
        fnm_bin="fnm"
    elif [ -x "$HOME/.local/share/fnm/fnm" ]; then
        fnm_bin="$HOME/.local/share/fnm/fnm"
    else
        warn "No se pudo localizar el binario de fnm."
        return 1
    fi

    # Initialize environment
    eval "$("$fnm_bin" env 2>/dev/null)"

    # Install chosen Node.js version
    info "Instalando Node.js v$node_ver con fnm..."
    "$fnm_bin" install "$node_ver" 2>/dev/null && "$fnm_bin" default "$node_ver"

    # Add environment setup to user shell rc files (idempotent)
    local fnm_snippet='
# fnm (Fast Node Manager) - BearsNPRMP
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd 2>/dev/null)"
fi'

    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ] && ! grep -q "fnm (Fast Node Manager)" "$rc"; then
            echo "$fnm_snippet" >> "$rc"
        fi
    done

    ok "Node.js v$node_ver instalado y configurado como versión predeterminada."
}
