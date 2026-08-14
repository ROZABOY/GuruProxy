# GuruProxy Changelog

## v2.4.0 — app-focused (2026-08-14)

Folder: `GuruProxy_v2.4_app_focused`

### Mobile layout
- Safe areas: top bar clears camera / status icons; bottom nav clears system gesture bar.
- Connect page is single-column: status panel moved **below** the connect button (no side column clipping).
- Desktop keeps Session/Tools/Help menu; phones/tablets use bottom tabs (Connect, White IP, Settings, Log) + overflow for Help/About.

### Session notification (VPN-style)
- Ongoing Android notification while connecting/connected with live ↑/↓ speed.
- **Stop** action on the notification to disconnect without opening the app.
- Implemented via native MethodChannel (no extra Gradle plugin) + `POST_NOTIFICATIONS`.

### Protocols
- Checkbox list for individual tunnel protocols (fronted Meek, QUIC, unfronted Meek, OSSH, SSH, TLS-OSSH, …).
- **Auto-protocol** toggle: platform-optimized defaults (Android/iOS prefer QUIC + unfronted/fronted Meek; Windows CDN keeps Se7en-identical OSSH set).

### Notes
- Tunnel binary remains Windows-first in this tree; phone UI/settings/White IP are fully usable. Connection on Android/iOS still needs a mobile tunnel backend later.

## v2.3.0

- Se7en-identical CDN dials, ports 17888/17889, proxy listen + stable profile.
- GitHub release: Windows zip + universal APK UI.
