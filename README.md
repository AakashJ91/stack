# 🏗️ Iso Stacker 3D (Godot 4.7)

A 3D Isometric box stacking arcade game with side-sliding cube mechanics, landing projection guides, combo streaks, and responsive Windows & Android support.

---

## 🎮 Gameplay & Features

- **Side-Sliding Cube Mechanics**:
  - Cubes glide smoothly across the tower from the side with harmonic oscillation.
  - Alternates slide axes every block (X-axis and Z-axis) for rhythmic timing.
  - Features a subtle footprint projection guide on the top of the tower beneath the sliding cube.
  - Tap, click, or press Space to drop the cube directly onto the stack!
- **Isometric Projection**:
  - Angled orthographic 3D camera (`-35.264°`, `45°`, `0°`) delivering true isometric projection.
  - Real-time directional lighting, soft ambient occlusion, and box bevel highlights.
- **Stacking Physics & Tolerance**:
  - **Perfect Alignment** ($dist \le 0.22$): Snaps directly into place, triggers golden sparkle burst, plays ascending pentatonic chimes, and awards bonus points!
  - **Good Alignment** ($dist \le 1.15$): Lands securely on the tower with impact dust and squash & stretch bounce.
  - **Overhang / Miss**: Center of mass is unsupported — box tumbles dynamically off the tower into the abyss with screen shake and game over!
- **Juice & Aesthetics**:
  - Dynamic gradient palette cycling (each box is smoothly tinted through an HSV gradient).
  - Tactile squash-and-stretch landing bounce.
  - Screen shake and haptic feedback on Android.
  - Procedural sound synthesizer (bell chimes, landing thuds, swoosh drop sound) — requires zero external audio files.
  - High score persistent saving (`user://high_score.save`).

---

## 📱 Android Support

- Configured for portrait mode (`720x1280`, auto-expand stretch).
- Full touch input support (`InputEventScreenTouch` & mouse emulation).
- Tactile haptic vibration on Android devices.
- `export_presets.cfg` ready for 1-click APK exports.

### 📦 Build Android APK

To build the Android APK, run either:

```cmd
export_android.bat
```

or in PowerShell:

```powershell
.\export_android.ps1
```

The output APK will be generated at:
```
IsoPendulumStacker.apk
```

To install directly to a connected Android phone or emulator:
```cmd
adb install -r IsoPendulumStacker.apk
```

---

## 💻 Windows Desktop Support

- Native standalone 64-bit Windows executable (`IsoPendulumStacker.exe`) with embedded resources.
- Optimized window size (`540x960` windowed by default, fully resizable and scalable).
- Keyboard shortcuts:
  - `Space` / `Enter`: Drop box / Restart when Game Over
  - `Left Click`: Drop box / Restart
  - `R`: Quick Restart
  - `M`: Toggle Sound Mute
  - `F11`: Toggle Fullscreen mode

### 📦 Build Windows Executable

To export the Windows `.exe`, run:

```cmd
export_windows.bat
```

or in PowerShell:

```powershell
.\export_windows.ps1
```

The output executable will be generated at:
```
IsoPendulumStacker.exe
```

---

## 🎮 Controls Summary

| Action | Android (Mobile) | Windows (PC) |
|---|---|---|
| **Drop Box** | Tap screen | Left Click or `Space` / `Enter` |
| **Restart Game** | Tap screen / Tap button | Left Click / `R` / `Space` |
| **Toggle Mute** | Tap speaker icon | Tap speaker icon or press `M` |
| **Fullscreen** | System Default | Press `F11` |

