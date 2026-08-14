import json
import os
import shutil
import subprocess
import time
from pathlib import Path

work = Path(os.environ["TEMP"]) / "guruproxy_win_smoke_244b"
work.mkdir(exist_ok=True)
(work / "data").mkdir(exist_ok=True)
app = Path(r"C:\laragon\www\Se7en-Pro\GuruProxy_v2.4_app_focused")
shutil.copy2(app / "assets/bin/psiphon-tunnel-core.exe", work / "GuruProxy.Tunnel.exe")
shutil.copy2(app / "assets/bin/server_entries.txt", work / "server_entries.txt")
net = json.loads((app / "assets/bin/network_config.json").read_text(encoding="utf-8"))
cfg = {
    "ClientPlatform": "Windows_10.0",
    "ClientVersion": str(net.get("ClientVersion") or "1"),
    "PropagationChannelId": net["PropagationChannelId"],
    "SponsorId": net["SponsorId"],
    "RemoteServerListURLs": net["RemoteServerListURLs"],
    "ObfuscatedServerListRootURLs": net.get("ObfuscatedServerListRootURLs") or [],
    "RemoteServerListSignaturePublicKey": net["RemoteServerListSignaturePublicKey"],
    "ServerEntrySignaturePublicKey": net.get("ServerEntrySignaturePublicKey") or "",
    "FeedbackUploadURLs": net.get("FeedbackUploadURLs") or [],
    "FeedbackEncryptionPublicKey": net.get("FeedbackEncryptionPublicKey") or "",
    "DataRootDirectory": str(work / "data"),
    "MigrateDataStoreDirectory": str(work / "data"),
    "EmitDiagnosticNotices": True,
    "LocalSocksProxyPort": 17898,
    "LocalHttpProxyPort": 17899,
    "EstablishTunnelTimeoutSeconds": 90,
    "LimitTunnelProtocols": [
        "OSSH",
        "QUIC-OSSH",
        "FRONTED-MEEK-OSSH",
        "FRONTED-MEEK-HTTP-OSSH",
    ],
    "UseIndistinguishableTLS": True,
}
(work / "config.json").write_text(json.dumps(cfg), encoding="utf-8")
p = subprocess.Popen(
    [
        str(work / "GuruProxy.Tunnel.exe"),
        "--config",
        str(work / "config.json"),
        "--serverList",
        str(work / "server_entries.txt"),
    ],
    cwd=str(work),
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    encoding="utf-8",
    errors="replace",
)
ok = False
lines: list[str] = []
t0 = time.time()
while time.time() - t0 < 75:
    line = p.stdout.readline() if p.stdout else ""
    if not line:
        if p.poll() is not None:
            break
        time.sleep(0.05)
        continue
    line = line.rstrip()
    lines.append(line)
    if '"count":1' in line or "ActiveTunnel" in line:
        print("HIT", line[:220])
        ok = True
        break
print("WIN_OK" if ok else "WIN_FAIL")
for L in lines[-10:]:
    print(L[:220])
try:
    p.kill()
except Exception:
    pass
