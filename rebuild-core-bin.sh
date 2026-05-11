#!/bin/bash
set -e

# Rebuild Fedarisha/v2rayN-core-bin: take upstream 2dust core-bin zips, swap
# xray.exe with the Fedarisha xray-builds binary, push to master.
#
# Requirements: bash, curl, python3, gh (authenticated), git

UPSTREAM_REPO="2dust/v2rayN-core-bin"
TARGET_REPO="Fedarisha/v2rayN-core-bin"
XRAY_REPO="Fedarisha/xray-builds"

# Allow override of xray release tag; default to latest.
XRAY_TAG="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$WORK_DIR"

if [ -z "$XRAY_TAG" ]; then
  XRAY_TAG="$(gh release view -R "$XRAY_REPO" --json tagName -q .tagName)"
fi
echo "Using xray tag: $XRAY_TAG"

# Architectures: <core-bin arch> <xray asset suffix>
PAIRS=(
  "64 windows-64"
  "arm64 windows-arm64-v8a"
)

for pair in "${PAIRS[@]}"; do
  CB_ARCH="${pair%% *}"
  XRAY_ARCH="${pair##* }"
  echo ""
  echo ">>> Rebuilding v2rayN-windows-${CB_ARCH}.zip"

  curl -fsSL "https://github.com/${UPSTREAM_REPO}/raw/refs/heads/master/v2rayN-windows-${CB_ARCH}.zip" \
    -o "upstream-${CB_ARCH}.zip"

  gh release download "$XRAY_TAG" -R "$XRAY_REPO" -p "Xray-${XRAY_ARCH}.zip" --clobber

  python3 - "$CB_ARCH" "Xray-${XRAY_ARCH}.zip" <<'PY'
import sys, zipfile, shutil, os

cb_arch = sys.argv[1]
xray_zip_path = sys.argv[2]
upstream_path = f"upstream-{cb_arch}.zip"
output_path = f"v2rayN-windows-{cb_arch}.zip"
top_dir = f"v2rayN-windows-{cb_arch}"
xray_member = f"{top_dir}/bin/xray/xray.exe"

with zipfile.ZipFile(xray_zip_path) as xz:
    new_xray = xz.read("xray.exe")

with zipfile.ZipFile(upstream_path) as src, \
     zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as dst:
    found = False
    for item in src.infolist():
        if item.filename == xray_member:
            found = True
            new_item = zipfile.ZipInfo(filename=item.filename, date_time=item.date_time)
            new_item.compress_type = zipfile.ZIP_DEFLATED
            new_item.external_attr = item.external_attr
            dst.writestr(new_item, new_xray)
        else:
            dst.writestr(item, src.read(item.filename))
    if not found:
        raise SystemExit(f"missing {xray_member} in {upstream_path}")

print(f"  wrote {output_path} ({os.path.getsize(output_path)/1024/1024:.1f} MB)")
PY
done

# Push to TARGET_REPO master
echo ""
echo ">>> Publishing to ${TARGET_REPO}"
rm -rf repo
git clone --depth=1 "git@github.com:${TARGET_REPO}.git" repo 2>/dev/null || {
  git init repo
  cd repo
  git remote add origin "git@github.com:${TARGET_REPO}.git"
  cd ..
}
cd repo
git checkout -B master

cp ../v2rayN-windows-64.zip .
cp ../v2rayN-windows-arm64.zip .

cat > README.md <<EOF
# v2rayN-core-bin (Fedarisha)

Repackaged \`${UPSTREAM_REPO}\` bundles with \`xray.exe\` replaced by the
[Fedarisha/xray-builds](https://github.com/${XRAY_REPO}) fork.

Current xray release: **${XRAY_TAG}**

Files are consumed by \`v2rayN/build-release.sh\` and the package-* scripts.
EOF

git add -A
if git diff --cached --quiet; then
  echo "    No changes to publish."
else
  git -c user.email="v.belobokin13@gmail.com" -c user.name="voltara13" \
    commit -m "Update bundle to xray ${XRAY_TAG}"
  git push -u origin master
  echo "    Published."
fi

echo ""
echo "=== Done ==="
