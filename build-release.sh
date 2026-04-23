#!/bin/bash
set -e

# === Configuration ===
VERSION="1.0.8"
CORE_BIN_REPO="2dust/v2rayN-core-bin"  # Change to your repo if you have custom core-bin
RELEASE_TAG="v${VERSION}"
SEVENZ="/c/Program Files/7-Zip/7z.exe"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building v2rayN ${VERSION} ==="

# Update version in Directory.Build.props
sed -i "s|<Version>.*</Version>|<Version>${VERSION}</Version>|" v2rayN/Directory.Build.props
echo "    Version set to ${VERSION} in Directory.Build.props"

# Clean previous builds
rm -rf publish-win64 publish-win-arm64 publish-linux64 publish-linux-arm64
rm -f v2rayN-windows-64-desktop.zip v2rayN-windows-arm64.zip v2rayN-linux-64.zip v2rayN-linux-arm64.zip

# === Build Windows x64 ===
echo ""
echo ">>> Building Windows x64..."
cd v2rayN
dotnet publish v2rayN.Desktop/v2rayN.Desktop.csproj -c Release -r win-x64 -p:SelfContained=true -o ../publish-win64
dotnet publish ./AmazTool/AmazTool.csproj -c Release -r win-x64 -p:SelfContained=true -p:PublishTrimmed=true -o ../publish-win64
cd ..

# === Build Windows ARM64 ===
echo ""
echo ">>> Building Windows ARM64..."
cd v2rayN
dotnet publish v2rayN.Desktop/v2rayN.Desktop.csproj -c Release -r win-arm64 -p:SelfContained=true -o ../publish-win-arm64
dotnet publish ./AmazTool/AmazTool.csproj -c Release -r win-arm64 -p:SelfContained=true -p:PublishTrimmed=true -o ../publish-win-arm64
cd ..

# === Download core binaries ===
echo ""
echo ">>> Downloading core binaries..."
curl -sL "https://github.com/${CORE_BIN_REPO}/raw/refs/heads/master/v2rayN-windows-64.zip" -o core-bin-win64.zip
curl -sL "https://github.com/${CORE_BIN_REPO}/raw/refs/heads/master/v2rayN-windows-arm64.zip" -o core-bin-win-arm64.zip

# === Package Windows x64 ===
echo ""
echo ">>> Packaging Windows x64..."
rm -rf v2rayN-windows-64-desktop
mkdir -p v2rayN-windows-64-desktop
cp -r publish-win64/* v2rayN-windows-64-desktop/
# Extract core-bin to a temp dir, then flatten its single top-level folder into the package
rm -rf core-bin-win64-extracted
"$SEVENZ" x core-bin-win64.zip -o"./core-bin-win64-extracted" -y > /dev/null
cp -r ./core-bin-win64-extracted/*/. v2rayN-windows-64-desktop/
rm -rf core-bin-win64-extracted
# Now v2rayN-windows-64-desktop/bin/ has xray, geo files etc.
"$SEVENZ" a -tZip "v2rayN-windows-64-desktop.zip" "./v2rayN-windows-64-desktop" -mx1 > /dev/null
echo "    Created: v2rayN-windows-64-desktop.zip"

# === Package Windows ARM64 ===
echo ""
echo ">>> Packaging Windows ARM64..."
rm -rf v2rayN-windows-arm64
mkdir -p v2rayN-windows-arm64
cp -r publish-win-arm64/* v2rayN-windows-arm64/
rm -rf core-bin-win-arm64-extracted
"$SEVENZ" x core-bin-win-arm64.zip -o"./core-bin-win-arm64-extracted" -y > /dev/null
cp -r ./core-bin-win-arm64-extracted/*/. v2rayN-windows-arm64/
rm -rf core-bin-win-arm64-extracted
"$SEVENZ" a -tZip "v2rayN-windows-arm64.zip" "./v2rayN-windows-arm64" -mx1 > /dev/null
echo "    Created: v2rayN-windows-arm64.zip"

# === Cleanup ===
rm -f core-bin-win64.zip core-bin-win-arm64.zip
rm -rf publish-win64 publish-win-arm64 v2rayN-windows-64-desktop v2rayN-windows-arm64

echo ""
echo "=== Build complete! ==="
echo "Files ready for release:"
ls -lh v2rayN-windows-*.zip
echo ""
echo "To create a GitHub release:"
echo "  gh release create ${RELEASE_TAG} v2rayN-windows-*.zip --title '${RELEASE_TAG}' --prerelease"
