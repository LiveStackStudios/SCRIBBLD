#!/bin/bash
# Pull the PNGs the screenshot UI test attached out of an .xcresult bundle.
# Usage: tools/extract-screenshots.sh <result.xcresult> <output-dir>
set -euo pipefail
RESULT="${1:-/tmp/scribbld-shots.xcresult}"
OUT="${2:-Assets/AppStore}"
mkdir -p "$OUT"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/_raw" >/dev/null 2>&1
# The manifest maps generated filenames back to the names set in the test.
python3 - "$OUT" <<'PY'
import json, os, shutil, sys
out = sys.argv[1]
raw = os.path.join(out, "_raw")
man = os.path.join(raw, "manifest.json")
if not os.path.exists(man):
    print("no manifest — nothing exported"); sys.exit(0)
n = 0
for entry in json.load(open(man)):
    for a in entry.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or a.get("exportedFileName")
        src = os.path.join(raw, a["exportedFileName"])
        if not name.lower().endswith(".png"):
            name += ".png"
        if os.path.exists(src):
            shutil.copy(src, os.path.join(out, name)); n += 1
print(f"extracted {n} screenshots to {out}")
PY
rm -rf "$OUT/_raw"
