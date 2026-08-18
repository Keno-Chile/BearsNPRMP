# ============================================================
#  🐻 BearsNPRMP — WSL Multi-Distro Test Orchestrator
# ============================================================
$ErrorActionPreference = "Continue"
$PSDefaultParameterValues['*:ErrorAction'] = 'SilentlyContinue'

$distros = @(
    @{ Name = "bear_debian"; Image = "debian:12"; Label = "Debian 12" },
    @{ Name = "bear_ubuntu"; Image = "ubuntu:24.04"; Label = "Ubuntu 24.04" },
    @{ Name = "bear_alpine"; Image = "alpine:latest"; Label = "Alpine Linux" },
    @{ Name = "bear_fedora"; Image = "fedora:latest"; Label = "Fedora Linux" },
    @{ Name = "bear_arch"; Image = "archlinux:latest"; Label = "Arch Linux" },
    @{ Name = "bear_opensuse"; Image = "opensuse/tumbleweed:latest"; Label = "openSUSE Tumbleweed" }
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tempBase = Join-Path $env:TEMP "bears_wsl_test"
if (Test-Path $tempBase) {
    Remove-Item -Path $tempBase -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempBase -Force | Out-Null

$results = @()

foreach ($d in $distros) {
    $distroName = $d.Name
    $imageName = $d.Image
    $label = $d.Label
    $distroDir = Join-Path $tempBase $distroName
    $tarPath = Join-Path $tempBase "$distroName.tar"

    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "🚀 Probando Distribucion: $label ($distroName)" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    try {
        # 1. Ensure any previous instance is unregistered
        & wsl --unregister $distroName 2>$null | Out-Null

        # 2. Export clean container rootfs
        Write-Host "📦 Extrayendo RootFS limpio de Docker ($imageName)..." -ForegroundColor DarkGray
        docker pull $imageName 2>&1 | Out-Null
        $containerId = (docker create $imageName sh 2>&1 | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($containerId)) {
            throw "No se pudo crear contenedor desde $imageName"
        }
        docker export $containerId -o $tarPath 2>&1 | Out-Null
        docker rm -f $containerId 2>&1 | Out-Null

        # 3. Create WSL Instance with 'bear_' prefix
        Write-Host "🐧 Importando nueva instancia WSL: $distroName..." -ForegroundColor DarkGray
        New-Item -ItemType Directory -Path $distroDir -Force | Out-Null
        & wsl --import $distroName $distroDir $tarPath --version 2
        Remove-Item $tarPath -Force -ErrorAction SilentlyContinue

        # 4. Prepare and run test script
        Write-Host "⚡ Ejecutando test suite dentro de $distroName..." -ForegroundColor Yellow

        $prepScript = @'
if command -v apk >/dev/null 2>&1; then apk update && apk add --no-cache bash curl; fi
if command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm bash curl which; fi
'@
        & wsl -d $distroName -u root -- sh -c $prepScript

        $wslDrive = $scriptDir[0].ToString().ToLower()
        $wslProjectPath = "/mnt/$wslDrive" + ($scriptDir.Substring(2) -replace '\\', '/')
        $cmd = "cd $wslProjectPath && chmod +x run_tests_wsl.sh && ./run_tests_wsl.sh"
        & wsl -d $distroName -u root -- bash -c $cmd

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Prueba en $label EXITOSA" -ForegroundColor Green
            $results += [PSCustomObject]@{ Distro = $label; WSL_Name = $distroName; Status = "PASS"; Details = "Instalacion, Nginx, Panel y VHost OK" }
        } else {
            Write-Host "❌ Prueba en $label FALLO (ExitCode: $LASTEXITCODE)" -ForegroundColor Red
            $results += [PSCustomObject]@{ Distro = $label; WSL_Name = $distroName; Status = "FAIL"; Details = "Fallo durante ejecucion" }
        }
    } catch {
        Write-Host "❌ Error en ${label}: $_" -ForegroundColor Red
        $results += [PSCustomObject]@{ Distro = $label; WSL_Name = $distroName; Status = "ERROR"; Details = $_.Exception.Message }
    } finally {
        # 5. Clean up temporary WSL instance
        Write-Host "🧹 Eliminando instancia WSL temporal: $distroName..." -ForegroundColor DarkGray
        & wsl --unregister $distroName 2>$null | Out-Null
        if (Test-Path $distroDir) {
            Remove-Item -Path $distroDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Cleanup base temp folder
Remove-Item -Path $tempBase -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "📊 RESUMEN FINAL DE PRUEBAS MULTI-DISTRO WSL" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize
