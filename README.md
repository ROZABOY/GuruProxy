# GuruProxy v2.5 — gPRC / HTTP/2 fronting

Folder name: **`GuruProxy_v2.5_gPRC`** — keep this tree when comparing Windows vs Android across releases.

## Run locally

```bash
cd GuruProxy_v2.5_gPRC
flutter pub get
flutter run -d windows
# or
flutter run -d <android-device>
```

Release builds land in `x_run_here_x/`:

- `GuruProxy-v2.5.0-android.apk`
- `GuruProxy-v2.5.0-windows/` (+ zip)

## Notes

- Requires private `assets/bin/network_config.json` + `server_entries.txt` (gitignored).
- Optional Settings → **HTTP/2 fronting (gRPC-friendly)**.
- GitHub: https://github.com/ROZABOY/GuruProxy/releases
