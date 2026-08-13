import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

work = Path(os.environ["LOCALAPPDATA"]) / "GuruProxy" / "connect-smoke-v22"
work.mkdir(parents=True, exist_ok=True)
(work / "data").mkdir(exist_ok=True)

net_path = Path(os.environ["LOCALAPPDATA"]) / "GuruProxy" / "network_config.json"
if not net_path.exists():
    # fall back to PsiphonUI
    net_path = Path(os.environ["LOCALAPPDATA"]) / "PsiphonUI" / "network_config.json"
net = json.loads(net_path.read_text(encoding="utf-8"))
print("net from", net_path)

src_exe = Path(r"C:\laragon\www\Se7en-Pro\GuruProxy_v2.2\assets\bin\psiphon-tunnel-core.exe")
src_srv = Path(r"C:\laragon\www\Se7en-Pro\GuruProxy_v2.2\assets\bin\server_entries.txt")
exe = work / "GuruProxy.Tunnel.exe"
srv = work / "server_entries.txt"
shutil.copy2(src_exe, exe)
shutil.copy2(src_srv, srv)

# Overrides — verify Akamai edges keep Akamai SNI even when CF custom SNI is set
cf_ips = ["104.16.7.36", "162.159.82.102"]
akamai = [
    ("edge-a-1", "23.215.0.206"),
    ("edge-a-2", "23.215.0.203"),
    ("edge-b-1", "23.212.250.91"),
    ("edge-b-2", "23.212.250.78"),
    ("edge-c-1", "23.12.147.13"),
    ("edge-d-1", "23.73.207.8"),
    ("edge-original", "92.123.102.43"),
]

overrides = [
    {
        "OverrideID": "fastly-provider",
        "MatchFrontingProviderIDRegexes": ["(?i)fastly"],
        "DialAddresses": ["pypi.org"],
        "SNIServerName": "pypi.org",
        "VerifyServerNames": ["www.python.org", "pypi.org", "fastly.com"],
        "ALPNProtocols": ["h2", "http/1.1"],
        "TLSProfile": "Chrome-83",
    },
]
for i, ip in enumerate(cf_ips, 1):
    overrides.append(
        {
            "OverrideID": f"cf-user-{i}",
            "MatchFrontingProviderIDRegexes": ["(?i)cloudflare"],
            "MatchDialAddressRegexes": [r"(?i)(cloudflare|cdnjs|workers\.dev)"],
            "DialAddresses": [ip],
            "SNIServerName": "www.cloudflare.com",
            "VerifyServerNames": ["www.cloudflare.com", ip, "cdnjs.cloudflare.com"],
            "ALPNProtocols": ["h2", "http/1.1"],
            "TLSProfile": "Chrome-83",
        }
    )
for oid, ip in akamai:
    overrides.append(
        {
            "OverrideID": oid,
            "MatchDialAddressRegexes": [".*"],
            "DialAddresses": [ip],
            # CRITICAL: must be Akamai SNI, never www.cloudflare.com
            "SNIServerName": "a248.e.akamai.net",
            "VerifyServerNames": [
                "a248.e.akamai.net",
                ip,
                "a.akamaized.net",
                "a.akamaihd.net",
            ],
            "ALPNProtocols": ["http/1.1"],
            "TLSProfile": "Chrome-83",
        }
    )

ver = sys.getwindowsversion()
cfg = {
    "ClientPlatform": f"Windows_{ver.major}.{ver.minor}",
    "ClientVersion": str(net.get("ClientVersion") or "1"),
    "PropagationChannelId": net["PropagationChannelId"],
    "SponsorId": net["SponsorId"],
    "RemoteServerListURLs": net["RemoteServerListURLs"],
    "ObfuscatedServerListRootURLs": net.get("ObfuscatedServerListRootURLs") or [],
    "RemoteServerListSignaturePublicKey": net["RemoteServerListSignaturePublicKey"],
    "ServerEntrySignaturePublicKey": net.get("ServerEntrySignaturePublicKey") or "",
    "FeedbackUploadURLs": net.get("FeedbackUploadURLs") or [],
    "FeedbackEncryptionPublicKey": net.get("FeedbackEncryptionPublicKey") or "",
    "EnableFeedbackUpload": True,
    "DataRootDirectory": str(work / "data"),
    "MigrateDataStoreDirectory": str(work / "data"),
    "UseIndistinguishableTLS": True,
    "EmitDiagnosticNotices": True,
    "EmitDiagnosticNetworkParameters": True,
    "EmitServerAlerts": True,
    "EmitBytesTransferred": True,
    "EstablishTunnelTimeoutSeconds": 90,
    "LocalHttpProxyPort": 18082,
    "LocalSocksProxyPort": 11082,
    "EgressRegion": "US",
    "AggressiveEstablishment": True,
    "LimitTunnelProtocols": [
        "FRONTED-MEEK-CDN-OSSH",
        "FRONTED-MEEK-OSSH",
        "FRONTED-MEEK-HTTP-OSSH",
        "FRONTED-MEEK-QUIC-OSSH",
    ],
    "DisableTactics": True,
    "FrontedMeekDialOverrides": overrides,
    "FrontedMeekDialOverridesProbability": 1.0,
}

config_path = work / "config.json"
config_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
log_path = work / "smoke.log"
if log_path.exists():
    log_path.unlink()

proc = subprocess.Popen(
    [str(exe), "--config", str(config_path), "--serverList", str(srv)],
    cwd=str(work),
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    encoding="utf-8",
    errors="replace",
)
print("pid", proc.pid)
connected = False
socks = 0
region = ""
proto = ""
start = time.time()
lines = []
while time.time() - start < 95:
    line = proc.stdout.readline()
    if not line and proc.poll() is not None:
        break
    if not line:
        time.sleep(0.05)
        continue
    line = line.strip()
    lines.append(line)
    if "Tunnels" in line and '"noticeType":"Tunnels"' in line.replace(" ", "") or (
        '"noticeType": "Tunnels"' in line
    ):
        if re.search(r'"count"\s*:\s*[1-9]', line):
            connected = True
            break
    # robust: noticeType Tunnels with count>=1
    if '"Tunnels"' in line and re.search(r'"count"\s*:\s*[1-9]', line) and "limitTunnelProtocols" not in line:
        connected = True
        break
    if "ListeningSocksProxyPort" in line:
        m = re.search(r'"port"\s*:\s*(\d+)', line)
        if m:
            socks = int(m.group(1))
    if "ConnectedServerRegion" in line:
        m = re.search(r'"region"\s*:\s*"([^"]+)"', line)
        if m:
            region = m.group(1)

log_path.write_text("\n".join(lines), encoding="utf-8")
if proc.poll() is None:
    proc.kill()
elapsed = round(time.time() - start, 1)
print(
    "CONNECTED",
    connected,
    "SOCKS",
    socks,
    "REGION",
    region,
    "SEC",
    elapsed,
    "EXIT",
    proc.poll(),
    "LINES",
    len(lines),
)
keys = (
    "Tunnels",
    "ListeningSocks",
    "ConnectedServer",
    "tunnel connected",
    "Tunnel established",
    "beast mode",
    "Connecting (",
    "unexpected status",
    "403",
    "failed to connect",
    "Upstream",
    "Establish",
)
shown = 0
for L in lines:
    if any(k in L for k in keys):
        print(L[:260])
        shown += 1
        if shown > 40:
            break
if not connected:
    print("FAIL — last 15 lines:")
    for L in lines[-15:]:
        print(L[:260])
    sys.exit(1)
print("OK")
