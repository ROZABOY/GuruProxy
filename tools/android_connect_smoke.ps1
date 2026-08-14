# Android connect smoke loop for GuruProxy.
# Usage (from repo root or this folder):
#   powershell -ExecutionPolicy Bypass -File tools\android_connect_smoke.ps1
# Requires: ANDROID_HOME, emulator running, flutter on PATH.

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $PSScriptRoot '..\pubspec.yaml'))) {
  $App = Join-Path (Split-Path $PSScriptRoot -Parent) '.'
} else {
  $App = Resolve-Path (Join-Path $PSScriptRoot '..')
}
$App = (Resolve-Path $App).Path

if (-not $env:ANDROID_HOME) {
  $env:ANDROID_HOME = 'E:\Programs\Programming\AndroidStudio\SDK'
}
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
$pkg = 'com.guruproxy.guruproxy'
$timeoutSec = 120

Write-Host "App root: $App"
Write-Host "Device:"
& $adb devices -l

Push-Location $App
try {
  Write-Host "Building + launching with GURU_AUTO_CONNECT..."
  $log = Join-Path $env:TEMP 'guruproxy_android_smoke_flutter.log'
  $proc = Start-Process -FilePath 'flutter' -ArgumentList @(
    'run', '-d', 'emulator-5554', '--release',
    '--dart-define=GURU_AUTO_CONNECT=true'
  ) -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError "$log.err"

  # Wait until package is installed / process alive
  $deadline = (Get-Date).AddMinutes(8)
  do {
    $out = & $adb shell pm path $pkg 2>$null
    if ($out -match 'package:') { break }
    if ($proc.HasExited -and $proc.ExitCode -ne 0) {
      Get-Content $log -Tail 40 -ErrorAction SilentlyContinue
      Get-Content "$log.err" -Tail 40 -ErrorAction SilentlyContinue
      throw "flutter run exited early ($($proc.ExitCode))"
    }
    Start-Sleep 5
  } while ((Get-Date) -lt $deadline)

  Write-Host "App present. Watching logcat GuruProxy + smoke status..."
  & $adb logcat -c | Out-Null
  $logcatFile = Join-Path $env:TEMP 'guruproxy_android_smoke_logcat.txt'
  $logcat = Start-Process -FilePath $adb -ArgumentList @('logcat', '-s', 'GuruProxy:I', 'flutter:I') `
    -PassThru -NoNewWindow -RedirectStandardOutput $logcatFile

  $ok = $false
  $end = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $end) {
    $lc = Get-Content $logcatFile -ErrorAction SilentlyContinue | Select-Object -Last 80
    if ($lc -match 'CONNECTED socks=') {
      Write-Host "SUCCESS: connected seen in logcat"
      $ok = $true
      break
    }
    if ($lc -match 'invalid tunnel protocol') {
      Write-Host "FAIL: invalid tunnel protocol"
      $lc | Select-Object -Last 30 | ForEach-Object { Write-Host $_ }
      break
    }
    # Try pull status via run-as (debuggable) — release may fail; logcat is primary.
    $status = & $adb shell "run-as $pkg cat files/GuruProxy/connect_smoke_status.txt 2>/dev/null" 2>$null
    if (-not $status) {
      $status = & $adb shell "run-as $pkg cat app_flutter/GuruProxy/connect_smoke_status.txt 2>/dev/null" 2>$null
    }
    if ($status -match 'connected') {
      Write-Host "SUCCESS: $status"
      $ok = $true
      break
    }
    if ($status -match 'timeout|error') {
      Write-Host "STATUS: $status"
    }
    Start-Sleep 5
  }

  if (-not $ok) {
    Write-Host "---- last logcat ----"
    Get-Content $logcatFile -Tail 60 -ErrorAction SilentlyContinue
    throw "Connect smoke timed out after ${timeoutSec}s"
  }

  Write-Host "Android connect smoke OK"
  exit 0
}
finally {
  Pop-Location
}
