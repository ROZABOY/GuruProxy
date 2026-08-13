# GuruProxy v2

Flutter desktop/mobile client for CDN-fronted Psiphon tunneling.

Local folder name on developer machines may be `GuruProxy_v2`; this repository
and all releases are versioned from **v2** onward (`v2.0.0`, `v2.0.1`, …).

## Requirements
- Flutter 3.12+
- Windows (tunnel process today); Android/iOS UI scaffolding later
- Network credentials in `%LOCALAPPDATA%\GuruProxy\network_config.json`
  (imported from official Psiphon / legacy PsiphonUI if present)

## Run
```bat
flutter pub get
flutter run -d windows
```

Release:
```bat
flutter build windows --release
```

## Bundled tunnel binary
Place `psiphon-tunnel-core.exe` and `server_entries.txt` under `assets/bin/`
locally (not committed). Without them, Connect cannot start the tunnel.

## CDN preference
Default dial order: **Cloudflare → Google → Akamai**.

## License
UI © GuruProxy authors. Tunnel engine is Psiphon tunnel-core (GPLv3).
Thanks to the Psiphon team.
