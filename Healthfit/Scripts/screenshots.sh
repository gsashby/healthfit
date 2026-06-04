#!/usr/bin/env bash
# screenshots.sh — capture App Store screenshots for HealthFit
#
# Usage:
#   bash Scripts/screenshots.sh
#
# Output: ~/Desktop/HealthfitScreenshots/*.png
#
# Required simulator: iPhone 16 Pro Max (6.9" — required by App Store)
# The script also captures iPad Pro 13" if the simulator is available.

set -euo pipefail

PROJECT="Healthfit.xcodeproj"
SCHEME="Healthfit"
TEST_TARGET="HealthfitUITests"
TEST_CLASS="ScreenshotTests"

IPHONE_SIM="iPhone 17 Pro Max"
IPAD_SIM="iPad Pro 13-inch (M5)"

OUTPUT_DIR="$HOME/Desktop/HealthfitScreenshots"
mkdir -p "$OUTPUT_DIR"

echo "📸 HealthFit Screenshot Capture"
echo "Output → $OUTPUT_DIR"
echo ""

run_screenshots() {
  local DESTINATION="$1"
  local LABEL="$2"

  echo "▶ Running screenshots on $LABEL..."
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:"$TEST_TARGET/$TEST_CLASS" \
    -resultBundlePath "/tmp/healthfit-screenshots-$LABEL.xcresult" \
    INFOPLIST_KEY_UIStatusBarStyle_iphoneos=UIStatusBarStyleLightContent \
    2>&1 | grep -E "✓|✗|error:|ScreenshotTests|Snapshot:|screenshot" || true

  echo "✅ Done: $LABEL"
  echo ""
}

# iPhone 16 Pro Max — required for App Store submission
run_screenshots \
  "platform=iOS Simulator,name=$IPHONE_SIM" \
  "iPhone16ProMax"

# iPad Pro 13" — required if app supports iPad
run_screenshots \
  "platform=iOS Simulator,name=$IPAD_SIM" \
  "iPadPro13"

echo "📁 Extracting screenshots from test result bundle..."
RESULT=$(ls -t ~/Library/Developer/Xcode/DerivedData/Healthfit-*/Logs/Test/*.xcresult 2>/dev/null | head -1)
if [ -z "$RESULT" ]; then
  echo "  ⚠ No xcresult bundle found. Check xcodebuild output above."
  exit 1
fi

NAMES=("01-Today-Readiness" "02-Today-Session" "03-Plan" "04-Eat" "05-Coach")
count=0
for f in "$RESULT/Data/data."*; do
  if file "$f" 2>/dev/null | grep -q "PNG"; then
    name="${NAMES[$count]:-screenshot-$count}"
    cp "$f" "$OUTPUT_DIR/${name}.png"
    dims=$(python3 -c "import struct; d=open('$f','rb').read(); w,h=struct.unpack('>II',d[16:24]); print(f'{w}x{h}')")
    echo "  ✓ ${name}.png ($dims)"
    count=$((count + 1))
  fi
done

echo ""
echo "📁 $count screenshots → $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  1. Open Finder → $OUTPUT_DIR to review screenshots"
echo "  2. Upload to App Store Connect → My Apps → HealthFit → iOS App → Screenshots"
echo "  3. Required: 6.9\" iPhone (iPhone 17 Pro Max = 1320×2868) ✓"
echo "  4. Required if supporting iPad: 13\" iPad Pro"
