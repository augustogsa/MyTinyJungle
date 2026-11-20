#!/usr/bin/env bash
# Raw App Store screens, one per hero feature, demo jungle, light mode, 9:41 status bar.
# Usage: Tools/appstore/capture.sh <kind> <simulator-udid> <path/to/MyTinyJungle.app>
#   kind: iphone69 (iPhone 18 Pro Max), duo (iPhone Duo open flat) or duoclosed (Duo closed, outer screen); set the posture first
# Writes Assets/AppStore/screenshots/raw/<lang>/<kind>/NN-feature.png; Tools/appstore/frame.py turns them into store shots.
set -uo pipefail
cd "$(dirname "$0")/../.."
kind=$1; D=$2; APP=$3
BID=com.simpleappscompany.mytinyjungle
case $kind in duo) DISP=--display=3;; duoclosed) DISP=--display=1;; *) DISP=;; esac
OUT=Assets/AppStore/screenshots/raw
PHOTOS="$PWD/Tools/demo-photos"
xcrun simctl boot "$D" 2>/dev/null; xcrun simctl bootstatus "$D" >/dev/null
xcrun simctl ui "$D" appearance light
xcrun simctl status_bar "$D" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --dataNetwork wifi
xcrun simctl install "$D" "$APP"
for lang in ${LANGS:-en-US pt-BR}; do
  case $lang in pt-BR) L='(pt-BR)';; *) L='(en)';; esac
  dir="$OUT/$lang/$kind"; mkdir -p "$dir"
  shot() { # name, wait, extra args...
    local name=$1 wait=$2; shift 2
    [ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $name "* ]] && return
    xcrun simctl terminate "$D" $BID 2>/dev/null
    xcrun simctl launch "$D" $BID -AppleLanguages "$L" -AppleLocale "${lang/-/_}" -demoPhotos "$PHOTOS" -plus -noAds -careReminders NO "$@" >/dev/null
    sleep "$wait"
    xcrun simctl io "$D" screenshot $DISP "$dir/$name.png" >/dev/null 2>&1
  }
  shot 00-warmup 30 -selectedTab 0; rm -f "$dir/00-warmup.png"
  shot 01-notes 22 -selectedTab 0 -demoOpen notes
  shot 02-jungle 22 -selectedTab 0 -demoOpen jungle
  shot 03-season 22 -selectedTab 2 -demoOpen season
  shot 04-doctor 22 -selectedTab 1 -demoOpen doctor
  shot 05-identify 20 -selectedTab 3 -demoOpen identify
  shot 06-scan 22 -selectedTab 3 -demoOpen none -demoScan
  shot 07-away 24 -selectedTab 2 -demoOpen trip
  shot 08-household 24 -selectedTab 0 -demoOpen none -householdDemo -openSharedJungle
  shot 09-digest 20 -selectedTab 2 -demoOpen digest
  shot 10-chat 24 -selectedTab 0 -demoOpen talk
  shot 11-widgets 20 -selectedTab 0 -demoOpen widgets
  shot 12-passport 28 -selectedTab 1 -demoOpen passport
  shot 13-guides 24 -selectedTab 4 -demoOpen guides
  shot 14-plus 20 -selectedTab 4 -demoOpen paywall
done
xcrun simctl status_bar "$D" clear
echo "done $kind"
