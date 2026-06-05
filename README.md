# MediConnect

Flutter clinic app with Firebase Realtime Database sync across patient and doctor portals.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.11+ (`flutter doctor` should pass)
- Firebase project: **mediconnect-26** (Realtime Database in `asia-southeast1`)
- **Android:** `android/app/google-services.json` (already included)
- **iOS/macOS:** run `flutterfire configure` and add `GoogleService-Info.plist` for production iOS builds

## Run on your machine

### Windows (recommended options)

| Target | Command | Notes |
|--------|---------|--------|
| **Chrome (easiest)** | `flutter run -d chrome` | No Visual Studio / Firebase C++ SDK needed |
| **Windows desktop** | `flutter run -d windows` | Needs Visual Studio + C++ workload |
| **Android** | `flutter run -d android` | Emulator or USB device |

PowerShell helper:

```powershell
.\scripts\run.ps1 chrome
.\scripts\run.ps1 windows
```

### If Windows desktop build fails (Firebase CMake error)

This usually means the Firebase C++ SDK zip did not extract fully (common when the project lives under **OneDrive**):

```powershell
.\scripts\fix_windows_firebase_build.ps1
```

Or manually delete `build\windows` and run `flutter build windows` again on a stable network. Prefer keeping the project in a local folder such as `C:\dev\TechMedicos_Project` instead of OneDrive-synced Desktop.

### Linux / macOS

```bash
flutter pub get
flutter run -d linux    # or macos
```

### Web production build

```bash
flutter build web
```

## Tests

```bash
flutter test
flutter analyze
```

## Platform notes

- **Patient/doctor ID generation** uses Firebase transactions on mobile/web and safe optimistic writes on desktop (Windows, Linux, macOS).
- **Offline persistence** is enabled only on Android and iOS.
- **Desktop + Web** rely on live Firebase connectivity; use Chrome on Windows if native desktop build is problematic.
