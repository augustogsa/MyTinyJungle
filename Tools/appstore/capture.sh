#!/usr/bin/env bash
# App Store / TestFlight screenshots: ten features, en-US and pt-BR, demo jungle, 9:41 status bar.
# Usage: Tools/appstore/capture.sh <kind> <simulator-udid> <path/to/MyTinyJungle.app>
#   kind: iphone69 (iPhone 18 Pro Max) or duo (iPhone Duo, open flat; set the posture first)
set -uo pipefail
cd "$(dirname "$0")/../.."
kind=$1; D=$2; APP=$3
BID=com.simpleappscompany.mytinyjungle
# The Duo has two displays: capture the inner one (open flat, landscape).
[ "$kind" = duo ] && DISP=--display=3 || DISP=
OUT=Assets/AppStore/screenshots
PHOTOS="$PWD/Tools/demo-photos"
xcrun simctl boot "$D" 2>/dev/null; xcrun simctl bootstatus "$D" >/dev/null
xcrun simctl status_bar "$D" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --dataNetwork wifi
xcrun simctl install "$D" "$APP"
for lang in en-US pt-BR; do
  [ "$lang" = pt-BR ] && L='(pt-BR)' || L='(en)'
  mkdir -p "$OUT/$lang/$kind"; rm -f "$OUT/$lang/$kind"/*.png
  shot() { # name, wait, extra args...
    local name=$1 wait=$2; shift 2
    xcrun simctl terminate "$D" $BID 2>/dev/null
    xcrun simctl launch "$D" $BID -AppleLanguages "$L" -AppleLocale "${lang/-/_}" -demoPhotos "$PHOTOS" -plus -noAds -careReminders NO "$@" >/dev/null
    sleep "$wait"
    xcrun simctl io "$D" screenshot $DISP "$OUT/$lang/$kind/$name.png" >/dev/null 2>&1
  }
  shot 00-warmup 20 -selectedTab 0; rm -f "$OUT/$lang/$kind/00-warmup.png"
  shot 01-today 20 -selectedTab 0
  shot 02-plants 20 -selectedTab 1
  shot 03-plant 24 -selectedTab 1 -demoOpen plant
  shot 04-chat 24 -selectedTab 0 -demoOpen chat
  shot 05-care 20 -selectedTab 2
  shot 06-scan 22 -selectedTab 3 -demoScan
  shot 07-shared 24 -selectedTab 0 -householdDemo -openSharedJungle
  shot 08-setup 16 -setupChat -onboarded NO
  shot 09-guides 24 -selectedTab 4 -demoOpen guides
  shot 10-me 20 -selectedTab 4
done
xcrun simctl status_bar "$D" clear
echo "done $kind"
