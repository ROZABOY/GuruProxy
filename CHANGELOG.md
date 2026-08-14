# GuruProxy Changelog

## v2.4.2 — connect fix + icon + signed APK (2026-08-14)

- **Fix crash:** invalid protocols `UNFRONTED-MEEK-HTTPS` / `SESSION-TICKET` → correct `-OSSH` names; strip `FRONTED-MEEK-CDN-OSSH` on Android (not in library).
- **Launcher icon:** brand shield from `assets/brand/app-icon.png` (no Flutter default).
- **Release signing key:** APK signed with GuruProxy release keystore (still sideload warning from Android for non-Play installs — normal).
- **Default fronts:** Cloudflare + Google (`216.239.38.120` / `www.google.com`) + Akamai + Fastly (+ extras) so dial list is never empty.

## v2.4.1

- White IP mobile layout; Android Psiphon library; SnackBars.

## v2.4.0

- App-focused mobile shell, notification, protocol checkboxes.
