#!/bin/bash
# แพ็ก .app เป็น DMG แบบลากใส่ Applications พร้อมพื้นหลังสีส้ม
#   scripts/make_dmg.sh "build/Pood Di Wa.app" dist/PoodDiWa.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$1"
OUT="$2"
VOL="Pood Di Wa"
STAGE="build/dmg-stage"
RW="build/rw.dmg"

echo "▸ เตรียมไฟล์ DMG"
rm -rf "$STAGE" "$RW" "$OUT" && mkdir -p "$STAGE/.background" "$(dirname "$OUT")"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Resources/dmg-background.tiff "$STAGE/.background/background.tiff"

# ถ้ามี DMG ชื่อเดียวกันเมานต์ค้างอยู่ ถอดก่อน
[[ -d "/Volumes/$VOL" ]] && hdiutil detach "/Volumes/$VOL" -force -quiet || true

hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ -format UDRW -ov "$RW"
DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk '/Apple_HFS/ {print $1}')
sleep 1

echo "▸ จัดหน้าต่าง Finder"
APPNAME=$(basename "$APP")
if ! osascript <<EOF
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 568}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "$APPNAME" of container window to {170, 210}
    set position of item "Applications" of container window to {490, 210}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
then
  echo "  (จัดหน้าต่างไม่ได้ — DMG ยังใช้ได้ แค่ไม่มีพื้นหลัง)"
fi

# ไอคอนของตัว DMG เอง
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "/Volumes/$VOL/.VolumeIcon.icns"
  SetFile -a C "/Volumes/$VOL" 2>/dev/null || true
fi

sync
hdiutil detach "$DEV" -quiet || hdiutil detach "$DEV" -force -quiet
echo "▸ บีบอัด"
hdiutil convert "$RW" -quiet -format UDZO -imagekey zlib-level=9 -o "$OUT"
rm -f "$RW"
echo "✓ $OUT ($(du -h "$OUT" | cut -f1))"
