import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

work = Path(os.environ["LOCALAPPDATA"]) / "GuruProxy" / "connect-smoke-ports"
work.mkdir(parents=True, exist_ok=True)
(work / "data").mkdir(exist_ok=True)

se7en = json.loads(
    (Path(os.environ["LOCALAPPDATA"]) / "Psiphon" / "tunnel-core" / "config.json").read_text(
        encoding="utf-8"
    )
)
netp = Path(os.environ["LOCALAPPDATA"]) / "GuruProxy" / "network_config.json"
if not netp.exists():
    netp = Path(os.environ["LOCALAPPDATA"]) / "PsiphonUI" / "network_config.json"
net = json.loads(netp.read_text(encoding="utf-8"))

exe = work / "t.exe"
srv = work / "server_entries.txt"
shutil.copy2(
    r"C:\laragon\www\Se7en-Pro\GuruProxy_v2.2\assets\bin\psiphon-tunnel-core.exe", exe
)
shutil.copy2(
    r"C:\laragon\www\Se7en-Pro\GuruProxy_v2.2\assets\bin\server_entries.txt", srv
)

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
    "EnableFeedbackUpload": True,
    "DataRootDirectory": str(work / "data"),
    "MigrateDataStoreDirectory": str(work / "data"),
    "UseIndistinguishableTLS": True,
    "EmitDiagnosticNotices": True,
    "EmitDiagnosticNetworkParameters": True,
    "EmitServerAlerts": True,
    "EmitBytesTransferred": True,
    "EstablishTunnelTimeoutSeconds": 90,
    "LocalHttpProxyPort": 17889,
    "LocalSocksProxyPort": 17888,
    "EgressRegion": "US",
    "AggressiveEstablishment": True,
    "LimitTunnelProtocols": se7en["LimitTunnelProtocols"],
    "DisableTactics": True,
    "FrontedMeekDialOverrides": se7en["FrontedMeekDialOverrides"],
    "FrontedMeekDialOverridesProbability": 1.0,
}
(work / "config.json").write_text(json.dumps(cfg), encoding="utf-8")

proc = subprocess.Popen(
    [str(exe), "--config", str(work / "config.json"), "--serverList", str(srv)],
    cwd=str(work),
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    encoding="utf-8",
    errors="replace",
)
ok = False
socks = 0
start = time.time()
while time.time() - start < 45:
    line = proc.stdout.readline()
    if not line and proc.poll() is not None:
        break
    if not line:
        time.sleep(0.05)
        continue
    if "ListeningSocksProxyPort" in line:
        m = re.search(r'"port"\s*:\s*(\d+)', line)
        if m:
            socks = int(m.group(1))
            print("SOCKS", socks)
    compact = line.replace(" ", "")
    if '"noticeType":"Tunnels"' in compact or '"noticeType": "Tunnels"' in line:
        if re.search(r'"count"\s*:\s*[1-9]', line) and "limitTunnelProtocols" not in line:
            ok = True
            break

print("CONNECTED", ok, "SEC", round(time.time() - start, 1), "SOCKS", socks)
if proc.poll() is None:
    proc.kill()
sys.exit(0 if ok and socks == 17888 else 1)
