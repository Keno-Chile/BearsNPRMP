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
        }

        .badge-up { background: rgba(34, 197, 94, 0.15); color: var(--success); border: 1px solid rgba(34, 197, 94, 0.3); }
        .badge-down { background: rgba(239, 68, 68, 0.15); color: var(--danger); border: 1px solid rgba(239, 68, 68, 0.3); }

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
            <div>
                <button class="btn" onclick="location.reload()">🔄 Actualizar Estado</button>
            </div>
        </header>

        <div class="grid">
            <!-- PHP Services -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">🐘 PHP (Multi-versión)</div>
                </div>
                <div class="service-list">
                    <div class="service-item">
                        <div><strong>PHP 8.5</strong> <span class="code">:9000</span></div>
                        <span class="badge badge-up">Activo</span>
                    </div>
                    <div class="service-item">
                        <div><strong>PHP 8.4</strong> <span class="code">:9001</span></div>
                        <span class="badge badge-down">Inactivo</span>
                    </div>
                    <div class="service-item">
                        <div><strong>PHP 7.4</strong> <span class="code">:9002</span></div>
                        <span class="badge badge-down">Inactivo</span>
                    </div>
                </div>
            </div>

            <!-- Databases -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">🗄️ Bases de Datos</div>
                </div>
                <div class="service-list">
                    <div class="service-item">
                        <div><strong>MariaDB 11.4</strong> <span class="code">:3306</span></div>
                        <span class="badge badge-up">Activo</span>
                    </div>
                    <div class="service-item">
                        <div><strong>PostgreSQL 17</strong> <span class="code">:5432</span></div>
                        <span class="badge badge-up">Activo</span>
                    </div>
                    <div class="service-item">
                        <div><strong>Redis 7</strong> <span class="code">:6379</span></div>
                        <span class="badge badge-up">Activo</span>
                    </div>
                </div>
            </div>

            <!-- Utilities -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">⚡ Herramientas &amp; Workers</div>
                </div>
                <div class="service-list">
                    <div class="service-item">
                        <div><strong>Mailpit</strong> <span class="code">:8025</span></div>
                        <a href="http://127.0.0.1:8025" target="_blank" class="badge badge-up" style="text-decoration:none;">Abrir UI</a>
                    </div>
                    <div class="service-item">
                        <div><strong>RoadRunner</strong> <span class="code">:8080</span></div>
                        <span class="badge badge-up">Activo</span>
                    </div>
                    <div class="service-item">
                        <div><strong>Nginx</strong> <span class="code">:80</span></div>
                        <span class="badge badge-up">Activo</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Virtual Hosts Summary -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">🌐 Virtual Hosts (*.test)</div>
            </div>
            <p style="color: var(--text-muted); font-size: 0.9rem;">
                Administra tus dominios locales con el comando <code>vhost.sh create</code> o dirigiéndote a <code>/var/www/</code>.
            </p>
        </div>
    </div>
</body>
</html>
