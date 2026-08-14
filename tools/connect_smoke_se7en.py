import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

work = Path(os.environ["LOCALAPPDATA"]) / "GuruProxy" / "connect-smoke-se7en"
work.mkdir(parents=True, exist_ok=True)
(work / "data").mkdir(exist_ok=True)

# Use LIVE working Se7en overrides as ground truth
se7en_cfg = Path(os.environ["LOCALAPPDATA"]) / "Psiphon" / "tunnel-core" / "config.json"
net_path = Path(os.environ["LOCALAPPDATA"]) / "GuruProxy" / "network_config.json"
if not net_path.exists():
    net_path = Path(os.environ["LOCALAPPDATA"]) / "PsiphonUI" / "network_config.json"
net = json.loads(net_path.read_text(encoding="utf-8"))
se7en = json.loads(se7en_cfg.read_text(encoding="utf-8"))

src_exe = Path(r"C:\laragon\www\Se7en-Pro\GuruProxy_v2.2\assets\bin\psiphon-tunnel-core.exe")
src_srv = Path(r"C:\laragon\www\Se7en-Pro\GuruProxy_v2.2\assets\bin\server_entries.txt")
exe = work / "GuruProxy.Tunnel.exe"
srv = work / "server_entries.txt"
shutil.copy2(src_exe, exe)
shutil.copy2(src_srv, srv)

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
    "LocalHttpProxyPort": 18089,
    "LocalSocksProxyPort": 18088,
    "EgressRegion": "US",
    "AggressiveEstablishment": True,
    "LimitTunnelProtocols": se7en.get("LimitTunnelProtocols"),
    "DisableTactics": True,
    "FrontedMeekDialOverrides": se7en.get("FrontedMeekDialOverrides"),
    "FrontedMeekDialOverridesProbability": 1.0,
}

config_path = work / "config.json"
config_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
print("using Se7en overrides count", len(cfg["FrontedMeekDialOverrides"]))

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
start = time.time()
lines = []
while time.time() - start < 60:
    line = proc.stdout.readline()
    if not line and proc.poll() is not None:
        break
    if not line:
        time.sleep(0.05)
        continue
    line = line.strip()
    lines.append(line)
    if '"noticeType":"Tunnels"' in line.replace(" ", "") or '"noticeType": "Tunnels"' in line:
        if re.search(r'"count"\s*:\s*[1-9]', line) and "limitTunnelProtocols" not in line:
            connected = True
            break
    if "tunnel connected" in line.lower():
        connected = True
        break

(work / "smoke.log").write_text("\n".join(lines), encoding="utf-8")
if proc.poll() is None:
    proc.kill()
print("CONNECTED", connected, "SEC", round(time.time() - start, 1), "LINES", len(lines))
for L in lines:
    if "tunnel connected" in L.lower() or '"Tunnels"' in L:
        print(L[:220])
sys.exit(0 if connected else 1)
