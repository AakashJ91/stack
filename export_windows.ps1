Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "EXPORTING ISO PENDULUM STACKER FOR WINDOWS DESKTOP" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

if (-not (Test-Path "build\windows")) {
    New-Item -ItemType Directory -Path "build\windows" -Force | Out-Null
}

$godotPath = "D:\GitHub\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"

if (-not (Test-Path $godotPath)) {
    Write-Host "[ERROR] Godot executable not found at: $godotPath" -ForegroundColor Red
    exit 1
}

Write-Host "Building Windows Executable..." -ForegroundColor Yellow
& $godotPath --headless --export-debug "Windows Desktop" "build/windows/StackAdventure.exe"

if ($LASTEXITCODE -eq 0 -and (Test-Path "build\windows\StackAdventure.exe")) {
    Copy-Item -Path "build\windows\StackAdventure.exe" -Destination "StackAdventure.exe" -Force
    $sizeMb = [math]::Round((Get-Item "StackAdventure.exe").Length / 1MB, 2)
    Write-Host "`n===================================================" -ForegroundColor Green
    Write-Host "SUCCESS! Windows executable generated: StackAdventure.exe ($sizeMb MB)" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Godot Windows export failed with code $LASTEXITCODE" -ForegroundColor Red
}
