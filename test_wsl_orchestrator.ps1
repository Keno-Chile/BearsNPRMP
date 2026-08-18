# ============================================================
#  🐻 BearsNPRMP — WSL Multi-Distro Test Orchestrator
#  PowerShell 7+ required (pwsh)
# ============================================================
$ErrorActionPreference = "Continue"
$PSDefaultParameterValues['*:ErrorAction'] = 'SilentlyContinue'

$distros = @(
    @{ Name = "bear_debian";   Image = "debian:12";           Label = "Debian 12" },
    @{ Name = "bear_ubuntu";   Image = "ubuntu:24.04";        Label = "Ubuntu 24.04" },
    @{ Name = "bear_alpine";   Image = "alpine:latest";       Label = "Alpine Linux" },
    @{ Name = "bear_fedora";   Image = "fedora:latest";       Label = "Fedora Linux" },
    @{ Name = "bear_arch";     Image = "archlinux:latest";    Label = "Arch Linux" },
    @{ Name = "bear_opensuse"; Image = "opensuse/tumbleweed:latest"; Label = "openSUSE Tumbleweed" }
)

# Auto-detect project directory (portable, no hardcoded paths)
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

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

        # 3. Create WSL Instance
        Write-Host "🐧 Importando nueva instancia WSL: $distroName..." -ForegroundColor DarkGray
        New-Item -ItemType Directory -Path $distroDir -Force | Out-Null
        & wsl --import $distroName $distroDir $tarPath --version 2
        Remove-Item $tarPath -Force -ErrorAction SilentlyContinue

        # 4. Prepare environment inside WSL
        Write-Host "⚡ Preparando entorno base en $distroName..." -ForegroundColor Yellow
        $prepScript = @'
if command -v apk >/dev/null 2>&1; then apk update && apk add --no-cache bash curl openssl; fi
if command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm bash curl which openssl; fi
if command -v apt-get >/dev/null 2>&1; then apt-get update -qq && apt-get install -y -qq curl openssl ca-certificates >/dev/null 2>&1; fi
if command -v dnf >/dev/null 2>&1; then dnf install -y -q curl openssl ca-certificates >/dev/null 2>&1; fi
if command -v zypper >/dev/null 2>&1; then zypper install -y -q curl openssl ca-certificates >/dev/null 2>&1; fi
'@
        & wsl -d $distroName -u root -- sh -c $prepScript

        # 5. Convert Windows path to WSL mount path
        $wslDrive = $scriptDir[0].ToString().ToLower()
        $wslProjectPath = "/mnt/$wslDrive" + ($scriptDir.Substring(2) -replace '\\', '/')

        # 6. Run test suite
        Write-Host "⚡ Ejecutando test suite dentro de $distroName..." -ForegroundColor Yellow
        $cmd = "cd $wslProjectPath && chmod +x run_tests_wsl.sh && ./run_tests_wsl.sh"
        & wsl -d $distroName -u root -- bash -c $cmd

        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Host "✅ Prueba en $label EXITOSA" -ForegroundColor Green
            $results += [PSCustomObject]@{ Distro = $label; WSL_Name = $distroName; Status = "PASS"; Details = "All phases passed" }
        } else {
            Write-Host "❌ Prueba en $label FALLO (ExitCode: $exitCode)" -ForegroundColor Red
            $results += [PSCustomObject]@{ Distro = $label; WSL_Name = $distroName; Status = "FAIL"; Details = "ExitCode: $exitCode" }
        }
    } catch {
        Write-Host "❌ Error en ${label}: $_" -ForegroundColor Red
        $results += [PSCustomObject]@{ Distro = $label; WSL_Name = $distroName; Status = "ERROR"; Details = $_.Exception.Message }
    } finally {
        # 7. Clean up
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

$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -ne "PASS" }).Count
Write-Host "`nResultados: $passed/$($results.Count) distros pasaron" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })

if ($failed -gt 0) {
    Write-Host "Distro con fallos:" -ForegroundColor Red
    $results | Where-Object { $_.Status -ne "PASS" } | ForEach-Object {
        Write-Host "  - $($_.Distro): $($_.Details)" -ForegroundColor Red
    }
}
