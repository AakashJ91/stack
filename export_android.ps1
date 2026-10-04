Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "EXPORTING ISO PENDULUM STACKER FOR ANDROID" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build" | Out-Null
}

$godotPath = "D:\GitHub\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"

if (-not (Test-Path $godotPath)) {
    Write-Host "[ERROR] Godot executable not found at: $godotPath" -ForegroundColor Red
    exit 1
}

Write-Host "Building Android APK..." -ForegroundColor Yellow
& $godotPath --headless --export-debug "Android" "build/IsoPendulumStacker.apk"

if ($LASTEXITCODE -eq 0 -and (Test-Path "build/IsoPendulumStacker.apk")) {
    Copy-Item -Path "build/IsoPendulumStacker.apk" -Destination "IsoPendulumStacker.apk" -Force
    $sizeMb = [math]::Round((Get-Item "IsoPendulumStacker.apk").Length / 1MB, 2)
    Write-Host "`n===================================================" -ForegroundColor Green
    Write-Host "SUCCESS! APK generated successfully: IsoPendulumStacker.apk ($sizeMb MB)" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Godot Android export failed with code $LASTEXITCODE" -ForegroundColor Red
}
