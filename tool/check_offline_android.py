"""Smoke-test the release APK on an emulator; restore its airplane-mode state.

Run after flutter build apk --release:
    python tool/check_offline_android.py emulator-5556
Only the emulator's connectivity is changed; the host connection is untouched.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
SDK = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", "")))
ADB = SDK / "platform-tools/adb.exe"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('device', help='Explicit QA emulator serial; no default device is modified.')
parser.add_argument('--settle-seconds', type=int, default=30,
                    help='Allow bundled SQLite seeding/font layout before visual review (1-60).')
parser.add_argument('--artifact-dir', type=Path, default=ROOT / 'build/screenshots',
                    help='Directory for the screenshot and JSON result.')
args = parser.parse_args()
if not 1 <= args.settle_seconds <= 60:
    parser.error('--settle-seconds must be 1-60')
device = args.device
if not device.startswith("emulator-"):
    raise SystemExit("This smoke test only changes connectivity on Android emulators.")

def adb(*args, binary=False):
    return subprocess.check_output([str(ADB), "-s", device, *args], text=not binary)

apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
aapt = sorted((SDK / "build-tools").glob("*/aapt.exe"))[-1]
permissions = subprocess.check_output([str(aapt), "dump", "permissions", str(apk)], text=True)
assert "android.permission.INTERNET" not in permissions, permissions
print("PASS: Release APK does not request Internet permission.")
print(adb("install", "-r", str(apk)).strip())
original = adb("shell", "cmd", "connectivity", "airplane-mode").strip()
assert original in ("enabled", "disabled"), original
artifacts = args.artifact_dir
artifacts.mkdir(parents=True, exist_ok=True)
try:
    adb("shell", "am", "force-stop", "dev.mlpath.ml_path")
    adb("shell", "cmd", "connectivity", "airplane-mode", "enable")
    assert adb("shell", "cmd", "connectivity", "airplane-mode").strip() == "enabled"
    print(adb("shell", "am", "start", "-n", "dev.mlpath.ml_path/.MainActivity").strip())
    # Allow cold SQLite content seeding and first font layout before capture.
    time.sleep(args.settle_seconds)
    pid = adb("shell", "pidof", "dev.mlpath.ml_path").strip()
    assert pid, "Application did not remain running."
    (artifacts / "05-release-offline.png").write_bytes(adb("exec-out", "screencap", "-p", binary=True))
    result = {"device": device, "internet_permission": False, "airplane_mode_at_launch": True, "running_pid": pid, "settle_seconds": args.settle_seconds, "screenshot": "05-release-offline.png"}
    (artifacts / "offline-check.json").write_text(json.dumps(result, indent=2))
    print("PASS: Release app launched and remained running in airplane mode.")
finally:
    adb("shell", "cmd", "connectivity", "airplane-mode", "enable" if original == "enabled" else "disable")
    print("Restored the emulator's previous airplane-mode state.")
