#!/bin/bash
# สร้าง "Pood Di Wa.app" (Universal: Apple Silicon + Intel) แล้วแพ็กเป็น DMG
#   ./build.sh          → build/Pood Di Wa.app + dist/PoodDiWa-<version>.dmg
#   ./build.sh --no-dmg → เฉพาะ .app
set -euo pipefail
cd "$(dirname "$0")"

NAME="Pood Di Wa"
EXE="PoodDiWa"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
APP="build/$NAME.app"
SDK=$(xcrun --show-sdk-path)

echo "▸ คอมไพล์ $NAME $VERSION"
rm -rf "$APP" build/obj && mkdir -p build/obj "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -sdk "$SDK" -target "$arch-apple-macos13.0" \
    Sources/*.swift -o "build/obj/$EXE-$arch"
done
lipo -create build/obj/$EXE-* -output "$APP/Contents/MacOS/$EXE"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"   # ฟอนต์ Anuphan (OFL) + ไฟล์สัญญาอนุญาต
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ เซ็นแอป (ad-hoc)"
codesign --force --deep --sign - --identifier app.pooddiwa.PoodDiWa "$APP"
codesign --verify --strict "$APP"

[[ "${1:-}" == "--no-dmg" ]] && { echo "✓ $APP"; exit 0; }

./scripts/make_dmg.sh "$APP" "dist/PoodDiWa-$VERSION.dmg"
