#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build -c release --disable-sandbox -debug-info-format none
bin_dir="$(swift build -c release --show-bin-path --disable-sandbox)"
app="${GITMORNING_OUTPUT_DIR:-$PWD/dist}/GitMorning.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/GitMorning" "$app/Contents/MacOS/GitMorning"
cp Resources/Info.plist "$app/Contents/Info.plist"
mkdir -p "$app/Contents/Resources/Snapshots"
cp Sources/GitMorning/Resources/Snapshots/*.json "$app/Contents/Resources/Snapshots/"
cp Sources/GitMorning/Resources/Korean.json "$app/Contents/Resources/Korean.json"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
if [[ "${GITMORNING_CORE_ONLY:-0}" != 1 ]]; then
  framework=""
  if [[ -n "${GITMORNING_SPARKLE_XCFRAMEWORK:-}" ]]; then
    framework="$(find "$GITMORNING_SPARKLE_XCFRAMEWORK" -type d -name Sparkle.framework -print -quit)"
  elif [[ -d .build/artifacts ]]; then
    framework="$(find .build/artifacts -type d -name Sparkle.framework -print -quit)"
  fi
  [[ -n "$framework" ]] || { print -u2 'Sparkle.framework not found; refusing to ship without updater'; exit 1; }
  mkdir -p "$app/Contents/Frameworks"
  ditto "$framework" "$app/Contents/Frameworks/Sparkle.framework"
fi
python3 scripts/configure-bundle.py "$app/Contents/Info.plist"
# Ad-hoc signing is for local/free builds. Developer ID is optional and supplied explicitly.
identity="${GITMORNING_SIGN_IDENTITY:--}"
if [[ -d "$app/Contents/Frameworks/Sparkle.framework" ]]; then
  # Sign nested code before its containing framework and main application.
  while IFS= read -r nested; do
    codesign --force --sign "$identity" "$nested"
  done < <(find "$app/Contents/Frameworks/Sparkle.framework" -depth \( -name '*.xpc' -o -name '*.app' \) -type d)
  autoupdate="$app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
  [[ ! -f "$autoupdate" ]] || codesign --force --sign "$identity" "$autoupdate"
  codesign --force --sign "$identity" "$app/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign "$identity" "$app"
codesign --verify --deep --strict "$app"
print "Built: $app"
