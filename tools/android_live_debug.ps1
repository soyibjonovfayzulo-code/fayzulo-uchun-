<#
.SYNOPSIS
    Godot 4.7 Android Live Debug, Wireless ADB & Hot-Reload File Watcher for Russian Zombie Survival.

.DESCRIPTION
    Automates:
    1. USB & Wireless ADB connection (`connect-usb`, `connect-wifi -DeviceIp <IP>`).
    2. Port forwarding (`adb reverse tcp:6007 tcp:6007` for Godot Remote Debug / Small Deploy with Network FS,
       and `adb reverse tcp:8090 tcp:8090` for the local Hot Update PCK server).
    3. `watch` mode: Monitors `scripts/`, `scenes/`, `shaders/`, and `resources/` on your PC.
       Whenever you save a file, it builds a tiny delta `.pck` (~10–40 KB) in ~1 second using Godot's
       `PCKPacker` and pushes it directly to the Android device's `user://live_sync/` directory via `adb push`
       so the running game on your phone hot-reloads the change WITHOUT rebuilding or reinstalling the APK!

.EXAMPLE
    .\tools\android_live_debug.ps1 -Action status
    .\tools\android_live_debug.ps1 -Action connect-usb
    .\tools\android_live_debug.ps1 -Action connect-wifi -DeviceIp 192.168.1.45
    .\tools\android_live_debug.ps1 -Action watch
#>

param(
    [ValidateSet("status", "connect-usb", "connect-wifi", "push-live", "watch", "restart-app")]
    [string]$Action = "status",
    [string]$DeviceIp = "",
    [int]$AdbPort = 5555,
    [switch]$RestartScene = $true
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Adb = "C:\Users\USTAFON\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$Godot = "C:\Users\USTAFON\Godot\4.7\Godot_v4.7-stable_win64_console.exe"
$PackageName = "com.rzs.survival"
$AndroidSyncDir = "/sdcard/Android/data/$PackageName/files/live_sync"
$InternalSyncDir = "files/live_sync"

function Setup-PortForwarding {
    Write-Host "[ADB] Setting up reverse port forwarding (6007 -> Remote Debug/FS, 8090 -> Hot Update)..." -ForegroundColor Cyan
    & $Adb reverse tcp:6007 tcp:6007
    & $Adb reverse tcp:6008 tcp:6008
    & $Adb reverse tcp:8090 tcp:8090
}

function Push-LiveDelta {
    param([string[]]$ChangedFiles)
    if (-not $ChangedFiles -or $ChangedFiles.Count -eq 0) {
        $ChangedFiles = @("res://launcher/versions.json")
    }
    $FileList = ($ChangedFiles -join ",")
    $OutPck = Join-Path $ProjectRoot "updates\live_patch.pck"
    Write-Host "[LiveSync] Building delta PCK for: $FileList" -ForegroundColor Yellow
    & $Godot --headless --path $ProjectRoot -s "res://tools/pck_builder.gd" -- "--out=res://updates/live_patch.pck" "--files=$FileList" | Out-Host

    $Stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $ManifestObj = @{
        timestamp = $Stamp
        pck_file = "live_patch.pck"
        scripts = $ChangedFiles
        restart_scene = [bool]$RestartScene
    }
    $ManifestPath = Join-Path $ProjectRoot "updates\sync_manifest.json"
    $ManifestObj | ConvertTo-Json -Compress | Set-Content -Path $ManifestPath -Encoding UTF8

    # Also copy to local PC user://live_sync/ so local test instances hot-reload too
    $LocalUserSync = Join-Path $env:APPDATA "Godot\app_userdata\Russian Zombie Survival\live_sync"
    New-Item -ItemType Directory -Force -Path $LocalUserSync | Out-Null
    Copy-Item -Path $OutPck -Destination (Join-Path $LocalUserSync "live_patch.pck") -Force
    Copy-Item -Path $ManifestPath -Destination (Join-Path $LocalUserSync "sync_manifest.json") -Force

    # Push to connected Android device if available
    $Devices = (& $Adb devices) -match "\tdevice$"
    if ($Devices) {
        Write-Host "[ADB] Pushing delta PCK & manifest to Android device..." -ForegroundColor Green
        & $Adb push $OutPck "/data/local/tmp/live_patch.pck" | Out-Null
        & $Adb push $ManifestPath "/data/local/tmp/sync_manifest.json" | Out-Null
        & $Adb shell "run-as $PackageName mkdir -p $InternalSyncDir && run-as $PackageName cp /data/local/tmp/live_patch.pck $InternalSyncDir/live_patch.pck && run-as $PackageName cp /data/local/tmp/sync_manifest.json $InternalSyncDir/sync_manifest.json"
        Write-Host "[OK] Live update pushed to phone at $Stamp (no APK rebuild needed!)" -ForegroundColor Green
    } else {
        Write-Host "[OK] Live update synced to local user://live_sync/ (connect phone via ADB to push to Android)." -ForegroundColor Cyan
    }
}

switch ($Action) {
    "status" {
        Write-Host "=== Godot 4.7 Android Live Debug Status ===" -ForegroundColor Cyan
        & $Adb devices -l
    }
    "connect-usb" {
        & $Adb wait-for-device
        Setup-PortForwarding
        Write-Host "[OK] USB ADB connected and ports 6007/8090 forwarded." -ForegroundColor Green
    }
    "connect-wifi" {
        if (-not $DeviceIp) {
            Write-Host "ERROR: Please specify -DeviceIp <phone_ip_address>" -ForegroundColor Red
            exit 1
        }
        & $Adb tcpip $AdbPort
        Start-Sleep -Seconds 2
        & $Adb connect "${DeviceIp}:${AdbPort}"
        Setup-PortForwarding
        Write-Host "[OK] Connected to Wireless ADB at ${DeviceIp}:${AdbPort}." -ForegroundColor Green
    }
    "push-live" {
        Push-LiveDelta -ChangedFiles @("res://scripts/interaction/door.gd", "res://scripts/ui/inventory_ui.gd")
    }
    "restart-app" {
        & $Adb shell am force-stop $PackageName
        & $Adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1
    }
    "watch" {
        Setup-PortForwarding
        Write-Host "[Watcher] Watching scripts/, scenes/, shaders/ for changes (Press Ctrl+C to stop)..." -ForegroundColor Green
        $Watcher = New-Object System.IO.FileSystemWatcher
        $Watcher.Path = $ProjectRoot
        $Watcher.IncludeSubdirectories = $true
        $Watcher.EnableRaisingEvents = $true
        $LastRun = [DateTime]::MinValue
        while ($true) {
            $Res = $Watcher.WaitForChanged([System.IO.WatcherChangeTypes]::Changed -bor [System.IO.WatcherChangeTypes]::Created, 1000)
            if (-not $Res.TimedOut) {
                $Name = $Res.Name.Replace("\", "/")
                if ($Name -match "^(scripts|scenes|shaders|resources|launcher)/.*\.(gd|tscn|gdshader|tres)$") {
                    $Now = [DateTime]::Now
                    if (($Now - $LastRun).TotalMilliseconds -gt 900) {
                        $LastRun = $Now
                        $ResPath = "res://$Name"
                        Push-LiveDelta -ChangedFiles @($ResPath)
                    }
                }
            }
        }
    }
}

