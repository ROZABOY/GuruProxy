# GuruProxy v2.6 — new features

Folder: **`GuruProxy_v2.6_newFeatures`**

## Highlights
- Android system VPN + per-app include/exclude
- Iran ISP presets, Meek health-check, server list refresh
- Clear censored vs open protocol modes
- Export diagnostics
- Dual artifacts every release (`x_run_here_x` + GitHub)

## Build
```bash
cd GuruProxy_v2.6_newFeatures
flutter pub get
flutter build apk --release
flutter build windows --release
```

gRPC / MahsaVPN integration remains a future hook (HTTP/2 preference setting).
