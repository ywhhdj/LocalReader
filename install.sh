#!/usr/bin/env bash
# 安装 debug APK 到已连接设备
set -e
cd "$(dirname "$0")"
APK="app/build/outputs/apk/debug/app-debug.apk"
if [[ ! -f "$APK" ]]; then
  echo "未找到 $APK，请先执行 ./build.sh debug"
  exit 1
fi
adb install -r "$APK"
adb shell am start -n com.demo/.MainActivity
