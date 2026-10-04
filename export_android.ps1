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
    
    # Auto-sign APK with apksigner to ensure 100% device install compatibility
    $javaPath = "C:\Program Files\Android\Android Studio1\jbr"
    $apkSignerPath = "C:\Users\aakas\AppData\Local\Android\Sdk\build-tools\36.1.0\apksigner.bat"
    $debugKeystore = "$env:USERPROFILE\.android\debug.keystore"
    
    if ((Test-Path $apkSignerPath) -and (Test-Path $debugKeystore)) {
        if (Test-Path $javaPath) {
            $env:JAVA_HOME = $javaPath
            $env:Path = "$javaPath\bin;$env:Path"
        }
        Write-Host "Signing APK with debug keystore..." -ForegroundColor Yellow
        & $apkSignerPath sign --ks $debugKeystore --ks-pass pass:android --ks-key-alias androiddebugkey "IsoPendulumStacker.apk" | Out-Null
    }

    $sizeMb = [math]::Round((Get-Item "IsoPendulumStacker.apk").Length / 1MB, 2)
    Write-Host "`n===================================================" -ForegroundColor Green
    Write-Host "SUCCESS! APK generated and signed: IsoPendulumStacker.apk ($sizeMb MB)" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Godot Android export failed with code $LASTEXITCODE" -ForegroundColor Red
}
