# GuruProxy Changelog

## v2.5.0 — gPRC / HTTP/2 fronting line (2026-08-14)

Local tree: **`GuruProxy_v2.5_gPRC`** (trace folder for this release line).

### Highlights
- **Android connect fixed:** bundled `server_entries.txt` is loaded into Psiphon `startTunneling` (was empty before). File is read on-device to avoid Binder ~1MB limits.
- **Optional HTTP/2 fronting (gRPC-friendly):** Settings toggle prefers Fronted Meek HTTP. Psiphon has **no native gRPC tunnel protocol** — this is the closest supported bias for HTTP/2 / gRPC-like traffic.
- Notification permission deferred until session notification shows (doesn’t block Connect).
- Connect smoke helpers: `--dart-define=GURU_AUTO_CONNECT=true`, `tools/android_connect_smoke.ps1`, `tools/windows_connect_smoke.py`.
- Verified on emulator **Medium API37 Android17 (2)** (LIVE / US / OSSH) and Windows tunnel-core smoke (`Tunnels` count 1).

### Artifacts (every release ships both)
- Windows: `GuruProxy-v2.5.0-windows.zip`
- Android: `GuruProxy-v2.5.0-android.apk`
- Local copies under each version’s `x_run_here_x/` for side-by-side tracing.

## v2.4.4 — Android server list + connect smoke (2026-08-14)

- Critical Android server list load; HTTP/2 preference; auto-connect smoke.

## v2.4.3 — identity + connect hard-fix (2026-08-14)

- Removed every user-facing Se7en/Se7ven mention. About thanks Psiphon only.
- Hard protocol allow-list before Start; Auto-protocol refresh on phones (schema 10).

## v2.4.2

- Protocol `-OSSH` rename attempt, icon, signing, multi-CDN defaults.

## v2.4.1 / v2.4.0

- Mobile shell, Psiphon Android library, White IP layout.
