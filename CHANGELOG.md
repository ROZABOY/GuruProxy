# GuruProxy Changelog

## v2.6.0 — new features line (2026-08-14)

Local tree: **`GuruProxy_v2.6_newFeatures`**

### Shipping rule
Every release includes **Windows zip + Android APK** in GitHub Releases and `x_run_here_x/`.

### New
- **Android system VPN (VpnService)** — whole-device routing via TUN → local SOCKS (hev-socks5-tunnel), with **per-app include/exclude**.
- **Foreground service + wake lock** while VPN/session is active.
- **Per-ISP Iran presets** (MCI / Irancell / Rightel / mixed) for Meek fronts.
- **Meek health-check** before applying White IPs (TLS-ok ≠ Psiphon front).
- **Server list refresh** — re-copy bundled entries + clear stale tunnel datastore.
- **Clearer protocol modes** — Censored (CDN fronting) vs Open net (OSSH/QUIC).
- **Export diagnostics** — sanitized last-N log share from Log tab.
- **Windows app exclude list** kept for future TUN / manual proxy bypass (exe names).
- **gRPC / MahsaVPN** — HTTP/2 preference retained as a future hook; no native gRPC tunnel yet.

### Carry-forward from v2.5
- Android `server_entries` load into `startTunneling`.
- Auto-protocol sanitize on Android.

## v2.5.0 — gPRC / HTTP/2 fronting line

See prior release notes.
