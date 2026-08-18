<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BearsNPRMP — Panel de Control Web</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #0b0f19;
            --surface: #131b2e;
            --surface-hover: #1c2742;
            --border: #1e293b;
            --primary: #38bdf8;
            --primary-dark: #0284c7;
            --text: #f8fafc;
            --text-muted: #94a3b8;
            --success: #22c55e;
            --danger: #ef4444;
            --warning: #f59e0b;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
            padding: 2rem 1.5rem;
            display: flex;
            justify-content: center;
        }

        .container {
            width: 100%;
            max-width: 1200px;
            display: flex;
            flex-direction: column;
            gap: 1.75rem;
        }

        header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: var(--surface);
            padding: 1.25rem 2rem;
            border-radius: 1.25rem;
            border: 1px solid var(--border);
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 1.25rem;
        }

        .logo-img {
            width: 54px;
            height: 54px;
            border-radius: 50%;
            border: 2px solid var(--primary);
        }

        .brand-title {
            font-size: 1.5rem;
            font-weight: 800;
            letter-spacing: -0.5px;
            color: var(--text);
        }

        .brand-sub {
            font-size: 0.85rem;
            color: var(--primary);
            font-weight: 600;
            letter-spacing: 0.5px;
        }

        .header-actions {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .last-updated {
            font-size: 0.8rem;
            color: var(--text-muted);
            font-family: 'JetBrains Mono', monospace;
        }

        .btn {
            background: var(--primary-dark);
            color: white;
            padding: 0.6rem 1.2rem;
            border-radius: 0.5rem;
            border: none;
            cursor: pointer;
            font-weight: 600;
            font-family: inherit;
            transition: background 0.2s;
        }
        .btn:hover { background: var(--primary); }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 1.25rem;
        }

        .card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 1rem;
            padding: 1.5rem;
            display: flex;
            flex-direction: column;
            gap: 1rem;
            transition: transform 0.2s, border-color 0.2s;
        }

        .card:hover {
            border-color: #334155;
            transform: translateY(-2px);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .card-title {
            font-size: 1.1rem;
            font-weight: 700;
        }

        .badge {
            font-size: 0.75rem;
            font-weight: 700;
            padding: 0.25rem 0.6rem;
            border-radius: 9999px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            transition: all 0.3s ease;
        }

        .badge-up { background: rgba(34, 197, 94, 0.15); color: var(--success); border: 1px solid rgba(34, 197, 94, 0.3); }
        .badge-down { background: rgba(239, 68, 68, 0.15); color: var(--danger); border: 1px solid rgba(239, 68, 68, 0.3); }
        .badge-loading { background: rgba(148, 163, 184, 0.15); color: var(--text-muted); border: 1px solid rgba(148, 163, 184, 0.3); }

        .service-list {
            display: flex;
            flex-direction: column;
            gap: 0.75rem;
        }

        .service-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem 1rem;
            background: rgba(15, 23, 42, 0.6);
            border-radius: 0.75rem;
            border: 1px solid rgba(255, 255, 255, 0.04);
            font-size: 0.9rem;
        }

        .service-item span.code {
            font-family: 'JetBrains Mono', monospace;
            color: var(--text-muted);
            font-size: 0.8rem;
        }

        .card-info {
            color: var(--text-muted);
            font-size: 0.9rem;
            line-height: 1.6;
        }

        .card-info code {
            background: rgba(15, 23, 42, 0.8);
            padding: 0.15rem 0.4rem;
            border-radius: 0.25rem;
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.85rem;
        }

        .pulse {
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .spinner {
            display: inline-block;
            width: 12px;
            height: 12px;
            border: 2px solid var(--text-muted);
            border-top-color: var(--primary);
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .error-banner {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(239, 68, 68, 0.3);
            border-radius: 0.75rem;
            padding: 1rem 1.5rem;
            color: var(--danger);
            font-size: 0.9rem;
            display: none;
        }

        .error-banner.visible { display: block; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="brand">
                <img src="/assets/logo.svg" alt="BearsNPRMP Logo" class="logo-img" onerror="this.style.display='none'">
                <div>
                    <h1 class="brand-title">BearsNPRMP</h1>
                    <div class="brand-sub">OS-AWARE &amp; MODULAR DEV STACK</div>
                </div>
            </div>
            <div class="header-actions">
                <span class="last-updated" id="lastUpdated">Cargando...</span>
                <button class="btn" id="refreshBtn" onclick="fetchStatus()">🔄 Actualizar</button>
            </div>
        </header>

        <div class="error-banner" id="errorBanner"></div>

        <div class="grid">
            <!-- PHP Services -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">🐘 PHP (Multi-versión)</div>
                </div>
                <div class="service-list" id="phpServices">
                    <div class="service-item">
                        <div><strong>PHP 8.5</strong> <span class="code">:9000</span></div>
                        <span class="badge badge-loading" id="php85">—</span>
                    </div>
                    <div class="service-item">
                        <div><strong>PHP 8.4</strong> <span class="code">:9001</span></div>
                        <span class="badge badge-loading" id="php84">—</span>
                    </div>
                    <div class="service-item">
                        <div><strong>PHP 7.4</strong> <span class="code">:9002</span></div>
                        <span class="badge badge-loading" id="php74">—</span>
                    </div>
                </div>
            </div>

            <!-- Databases -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">🗄️ Bases de Datos</div>
                </div>
                <div class="service-list" id="dbServices">
                    <div class="service-item">
                        <div><strong>MariaDB 11.4</strong> <span class="code">:3306</span></div>
                        <span class="badge badge-loading" id="mariadb11">—</span>
                    </div>
                    <div class="service-item">
                        <div><strong>PostgreSQL 17</strong> <span class="code">:5432</span></div>
                        <span class="badge badge-loading" id="postgres17">—</span>
                    </div>
                    <div class="service-item">
                        <div><strong>Redis 7</strong> <span class="code">:6379</span></div>
                        <span class="badge badge-loading" id="redis">—</span>
                    </div>
                </div>
            </div>

            <!-- Utilities -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">⚡ Herramientas &amp; Workers</div>
                </div>
                <div class="service-list" id="utilServices">
                    <div class="service-item">
                        <div><strong>Mailpit</strong> <span class="code">:8025</span></div>
                        <span class="badge badge-loading" id="mailpit">—</span>
                    </div>
                    <div class="service-item">
                        <div><strong>RoadRunner</strong> <span class="code">:8080</span></div>
                        <span class="badge badge-loading" id="roadrunner">—</span>
                    </div>
                    <div class="service-item">
                        <div><strong>Nginx</strong> <span class="code">:80</span></div>
                        <span class="badge badge-loading" id="nginx">—</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Active Versions -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">⚙️ Versiones Activas</div>
            </div>
            <div id="activeVersions" class="card-info">Cargando configuración...</div>
        </div>

        <!-- Virtual Hosts Summary -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">🌐 Virtual Hosts (*.test)</div>
            </div>
            <div id="vhostsList" class="card-info">
                <span class="spinner"></span> Cargando virtual hosts...
            </div>
        </div>
    </div>

    <script>
        const SERVICE_LABELS = {
            php74: { name: 'PHP 7.4', port: 9002 },
            php84: { name: 'PHP 8.4', port: 9001 },
            php85: { name: 'PHP 8.5', port: 9000 },
            mariadb10: { name: 'MariaDB 10.11', port: 3307 },
            mariadb11: { name: 'MariaDB 11.4', port: 3306 },
            postgres15: { name: 'PostgreSQL 15', port: 5433 },
            postgres17: { name: 'PostgreSQL 17', port: 5432 },
            redis: { name: 'Redis 7', port: 6379 },
            mailpit: { name: 'Mailpit', port: 8025 },
            roadrunner: { name: 'RoadRunner', port: 8080 }
        };

        let apiToken = null;
        let refreshInterval = null;

        async function getToken() {
            try {
                const res = await fetch('/api/token');
                const data = await res.json();
                apiToken = data.token || '';
                return apiToken;
            } catch (e) {
                apiToken = '';
                return '';
            }
        }

        function updateBadge(id, running) {
            const el = document.getElementById(id);
            if (!el) return;
            el.className = 'badge ' + (running ? 'badge-up' : 'badge-down');
            el.textContent = running ? 'Activo' : 'Inactivo';
        }

        function showSpinner(id) {
            const el = document.getElementById(id);
            if (!el) return;
            el.className = 'badge badge-loading';
            el.textContent = '...';
        }

        function showError(msg) {
            const banner = document.getElementById('errorBanner');
            banner.textContent = '⚠ ' + msg;
            banner.classList.add('visible');
        }

        function hideError() {
            document.getElementById('errorBanner').classList.remove('visible');
        }

        async function fetchStatus() {
            const btn = document.getElementById('refreshBtn');
            btn.disabled = true;
            btn.textContent = '⏳ Actualizando...';

            // Show spinners
            Object.keys(SERVICE_LABELS).forEach(id => showSpinner(id));

            try {
                const tokenParam = apiToken ? '?token=' + encodeURIComponent(apiToken) : '';
                const res = await fetch('/api/status' + tokenParam);

                if (res.status === 401) {
                    showError('Token inválido. Regenera el token con: bears --panel token');
                    return;
                }

                if (!res.ok) throw new Error('HTTP ' + res.status);

                const data = await res.json();

                // Update service badges
                if (data.services) {
                    for (const [svc, info] of Object.entries(data.services)) {
                        updateBadge(svc, info.running);
                    }
                }

                // Update active versions
                if (data.env) {
                    const env = data.env;
                    const versionsHtml = [
                        `PHP: <strong>${(env.PHP_CURRENT || 'php85').replace('php', 'PHP ')}</strong> <span class="code">(modo ${env.PHP_MODE || 'container'})</span>`,
                        `MariaDB: <strong>${(env.DB_CURRENT || 'mariadb11').replace('mariadb', 'MariaDB ')}</strong> <span class="code">(modo ${env.DB_MODE || 'container'})</span>`,
                        `PostgreSQL: <strong>${(env.PG_CURRENT || 'postgres17').replace('postgres', 'PostgreSQL ')}</strong> <span class="code">(modo ${env.PG_MODE || 'container'})</span>`,
                        `Node.js: <strong>v${env.NODE_CURRENT || '22'}</strong>`
                    ].join(' &nbsp;·&nbsp; ');
                    document.getElementById('activeVersions').innerHTML = versionsHtml;
                }

                // Update timestamp
                const now = new Date();
                document.getElementById('lastUpdated').textContent =
                    'Actualizado: ' + now.toLocaleTimeString('es-CL');

                hideError();

            } catch (e) {
                showError('Error al conectar con la API: ' + e.message);
                document.getElementById('lastUpdated').textContent = 'Error de conexión';
            } finally {
                btn.disabled = false;
                btn.textContent = '🔄 Actualizar';
            }
        }

        async function fetchVHosts() {
            try {
                const tokenParam = apiToken ? '?token=' + encodeURIComponent(apiToken) : '';
                const res = await fetch('/api/vhosts' + tokenParam);
                if (!res.ok) return;
                const data = await res.json();
                const vhosts = data.vhosts || [];
                const el = document.getElementById('vhostsList');

                if (vhosts.length === 0) {
                    el.innerHTML = 'No hay virtual hosts creados aún. Crea uno con: <code>bears-vhost create --domain mi-sitio.test</code>';
                    return;
                }

                el.innerHTML = vhosts.map(v =>
                    `<div class="service-item" style="margin-bottom:0.5rem">
                        <div>
                            <strong>${v.domain}</strong>
                            <span class="code">${v.root || ''}</span>
                        </div>
                        <span class="badge ${v.enabled ? 'badge-up' : 'badge-down'}">${v.enabled ? 'Activo' : 'Inactivo'}</span>
                    </div>`
                ).join('');
            } catch (e) {
                // Silent fail for vhosts
            }
        }

        async function init() {
            await getToken();
            await fetchStatus();
            await fetchVHosts();
            // Auto-refresh every 15 seconds
            refreshInterval = setInterval(() => {
                fetchStatus();
                fetchVHosts();
            }, 15000);
        }

        init();
    </script>
</body>
</html>
