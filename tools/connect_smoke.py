import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

work = Path(os.environ["LOCALAPPDATA"]) / "GuruProxy" / "connect-smoke"
work.mkdir(parents=True, exist_ok=True)
(work / "data").mkdir(exist_ok=True)

net = json.loads(
    Path(os.environ["LOCALAPPDATA"], "GuruProxy", "network_config.json").read_text(
        encoding="utf-8"
    )
)
src_exe = Path(r"C:\laragon\www\Se7en-Pro\GuruProxy_v2\assets\bin\psiphon-tunnel-core.exe")
src_srv = Path(r"C:\laragon\www\Se7en-Pro\GuruProxy_v2\assets\bin\server_entries.txt")
exe = work / "GuruProxy.Tunnel.exe"
srv = work / "server_entries.txt"
shutil.copy2(src_exe, exe)
shutil.copy2(src_srv, srv)

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
    {
        "OverrideID": "edge-a-1",
        "MatchDialAddressRegexes": [".*"],
        "DialAddresses": ["23.215.0.206"],
        "SNIServerName": "a248.e.akamai.net",
        "VerifyServerNames": ["a248.e.akamai.net", "23.215.0.206", "a.akamaized.net"],
        "ALPNProtocols": ["http/1.1"],
        "TLSProfile": "Chrome-83",
    },
    {
        "OverrideID": "edge-a-2",
        "MatchDialAddressRegexes": [".*"],
        "DialAddresses": ["23.215.0.203"],
        "SNIServerName": "a248.e.akamai.net",
        "VerifyServerNames": ["a248.e.akamai.net", "23.215.0.203", "a.akamaized.net"],
        "ALPNProtocols": ["http/1.1"],
        "TLSProfile": "Chrome-83",
    },
    {
        "OverrideID": "edge-b-1",
        "MatchDialAddressRegexes": [".*"],
        "DialAddresses": ["23.212.250.91"],
        "SNIServerName": "a248.e.akamai.net",
        "VerifyServerNames": ["a248.e.akamai.net", "23.212.250.91", "a.akamaized.net"],
        "ALPNProtocols": ["http/1.1"],
        "TLSProfile": "Chrome-83",
    },
    {
        "OverrideID": "edge-b-2",
        "MatchDialAddressRegexes": [".*"],
        "DialAddresses": ["23.212.250.78"],
        "SNIServerName": "a248.e.akamai.net",
        "VerifyServerNames": ["a248.e.akamai.net", "23.212.250.78", "a.akamaized.net"],
        "ALPNProtocols": ["http/1.1"],
        "TLSProfile": "Chrome-83",
    },
    {
        "OverrideID": "edge-c-1",
        "MatchDialAddressRegexes": [".*"],
        "DialAddresses": ["23.12.147.13"],
        "SNIServerName": "a248.e.akamai.net",
        "VerifyServerNames": ["a248.e.akamai.net", "23.12.147.13", "a.akamaized.net"],
        "ALPNProtocols": ["http/1.1"],
        "TLSProfile": "Chrome-83",
    },
    {
        "OverrideID": "edge-d-1",
        "MatchDialAddressRegexes": [".*"],
        "DialAddresses": ["23.73.207.8"],
        "SNIServerName": "a248.e.akamai.net",
        "VerifyServerNames": ["a248.e.akamai.net", "23.73.207.8", "a.akamaized.net"],
        "ALPNProtocols": ["http/1.1"],
        "TLSProfile": "Chrome-83",
    },
    {
        "OverrideID": "edge-original",
        "MatchDialAddressRegexes": [".*"],
        "DialAddresses": ["92.123.102.43"],
        "SNIServerName": "a248.e.akamai.net",
        "VerifyServerNames": ["a248.e.akamai.net", "92.123.102.43", "a.akamaized.net"],
        "ALPNProtocols": ["http/1.1"],
        "TLSProfile": "Chrome-83",
    },
]

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
    "LocalHttpProxyPort": 18081,
    "LocalSocksProxyPort": 11081,
    "EgressRegion": "US",
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
    if "Tunnels" in line and re.search(r'"count"\s*:\s*[1-9]', line):
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
print(
    "CONNECTED",
    connected,
    "SOCKS",
    socks,
    "REGION",
    region,
    "EXIT",
    proc.poll(),
    "LINES",
    len(lines),
)
keys = (
    "Tunnels",
    "ListeningSocks",
    "ConnectedServer",
    "unexpected status",
    "403",
    "failed to connect",
    "error processing",
    "Upstream",
    "Warning",
    "Establish",
    "ListeningHttp",
)
for L in lines:
    if any(k in L for k in keys):
        print(L[:260])
