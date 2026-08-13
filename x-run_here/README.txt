GuruProxy v2.2.1 — run from here
================================
Windows: unzip/open GuruProxy-v2.2.1-windows\guruproxy.exe
  (or use the zip from GitHub Releases)

Android: install GuruProxy-v2.2.1-universal.apk
  (arm / arm64 / x86_64 fat APK)

Note: tunnel connect uses psiphon-tunnel-core on Windows.
Android APK is UI + scanner; VPN tunnel for Android needs a follow-up Psiphon Android core build.

v2.2.1 fix: Akamai dial edges always use SNI a248.e.akamai.net
(previously Cloudflare SNI poisoned Meek → 400/404).
