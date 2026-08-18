<?php
// ============================================================
//  BearsNPRMP — Web Panel REST API
// ============================================================

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Token');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$bearsDir = getenv('BEARS_DIR') ?: (getenv('HOME') . '/bearsnprmp');
$configDir = getenv('CONFIG_DIR') ?: (getenv('HOME') . '/.config/bearsnprmp');
$tokenFile = $configDir . '/panel_token';

// Simple Token Verification
$validToken = file_exists($tokenFile) ? trim(file_get_contents($tokenFile)) : '';
$providedToken = $_GET['token'] ?? $_SERVER['HTTP_X_TOKEN'] ?? $_POST['token'] ?? '';

$action = $_GET['action'] ?? basename(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));

if ($action === 'ping') {
    echo json_encode(['status' => 'ok', 'timestamp' => time()]);
    exit;
}

if ($action === 'token') {
    echo json_encode(['token' => $validToken]);
    exit;
}

if ($validToken !== '' && $providedToken !== $validToken) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized: Invalid token']);
    exit;
}

switch ($action) {
    case 'status':
        $envFile = $bearsDir . '/.env';
        $env = file_exists($envFile) ? parse_ini_file($envFile) : [];
        
        $output = [];
        exec("cd {$bearsDir} && docker compose ps -a --format '{{.Service}}\t{{.Status}}' 2>/dev/null", $dockerPs);
        $containers = [];
        foreach ($dockerPs as $line) {
            $parts = explode("\t", $line);
            if (count($parts) >= 2) {
                $containers[$parts[0]] = str_starts_with($parts[1], 'Up') || str_starts_with($parts[1], 'running');
            }
        }

        echo json_encode([
            'env' => $env,
            'services' => [
                'php74' => ['port' => 9002, 'running' => $containers['php74'] ?? false],
                'php84' => ['port' => 9001, 'running' => $containers['php84'] ?? false],
                'php85' => ['port' => 9000, 'running' => $containers['php85'] ?? false],
                'mariadb10' => ['port' => 3307, 'running' => $containers['mariadb10'] ?? false],
                'mariadb11' => ['port' => 3306, 'running' => $containers['mariadb11'] ?? false],
                'postgres15' => ['port' => 5433, 'running' => $containers['postgres15'] ?? false],
                'postgres17' => ['port' => 5432, 'running' => $containers['postgres17'] ?? false],
                'redis' => ['port' => 6379, 'running' => $containers['redis'] ?? false],
                'mailpit' => ['port' => 8025, 'running' => $containers['mailpit'] ?? false],
                'roadrunner' => ['port' => 8080, 'running' => $containers['roadrunner'] ?? false],
            ]
        ]);
        break;

    case 'vhosts':
        $vhostScript = $bearsDir . '/modules/vhost.sh';
        $vhosts = [];
        if (file_exists($vhostScript)) {
            $json = shell_exec("bash {$vhostScript} list --json 2>/dev/null");
            $vhosts = json_decode($json, true) ?: [];
        }
        echo json_encode(['vhosts' => $vhosts]);
        break;

    case 'service_control':
        $svc = $_POST['service'] ?? '';
        $op = $_POST['op'] ?? '';
        if ($svc && in_array($op, ['start', 'stop', 'restart'])) {
            $cmd = "cd {$bearsDir} && docker compose {$op} {$svc} 2>&1";
            exec($cmd, $out, $ret);
            echo json_encode(['success' => $ret === 0, 'output' => implode("\n", $out)]);
        } else {
            echo json_encode(['error' => 'Invalid parameters']);
        }
        break;

    default:
        echo json_encode(['message' => 'BearsNPRMP API ready', 'action' => $action]);
        break;
}
