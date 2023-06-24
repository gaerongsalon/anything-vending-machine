#!/bin/bash

set -euo pipefail

if [ -z "${DEPLOY_TOKEN}" ]; then
  echo "Error: Set DEPLOY_TOKEN first."
  exit 1
fi

APP_NAME="anything_vending_machine"
DEBUG=""

usage() {
  echo "$0 [-s SERIAL] [-m SLACK_MESSAGE] [-d]"
  exit 0
}

log() {
  echo "[$(date)] $@"
}

while getopts ":s:m:d" o; do
  case "${o}" in
    s) SERIAL="${OPTARG}"   ;;
    m) MESSAGE="${OPTARG}"  ;;
    d) DEBUG="1"            ;;
    *) usage                ;;
  esac
done

SERIAL="${SERIAL:-"$(date +"%Y%m%d_%H%M%S")"}"
MESSAGE="${MESSAGE:-"버그 수정"}"

log "Start to deploy"
log " - SERIAL=${SERIAL}"
log " - MESSAGE=${MESSAGE}"

# https://github.com/yingyeothon/binary-distribution-api
DEPLOY_SERVICE="https://api.yyt.life/d/${APP_NAME}"

build_and_upload() {
  local BUILD_NAME="$1"
  local BUILD_OUTPUT="$2"
  shift 2

  flutter build $@ && \
    curl -T "${BUILD_OUTPUT}" "$( \
      curl -s -XPUT \
        "${DEPLOY_SERVICE}/android/${BUILD_NAME}" \
        -H "X-Auth-Token: ${DEPLOY_TOKEN}" \
      | tr -d '"')" && \
    curl -s -XGET "${DEPLOY_SERVICE}?count=1" | jq -r '.platforms.android[].url'
}

BUILD_GRADLE="android/app/build.gradle"
ANDROID_MANIFEST="android/app/src/main/AndroidManifest.xml"

git restore -- "${BUILD_GRADLE}" "${ANDROID_MANIFEST}"

log "Build debug apk."
sed -i 's/me.hoppipolla.anything_vending_machine/me.hoppipolla.anything_vending_machine_debug/g' "${BUILD_GRADLE}"
sed -i 's/뭐든지 자판기/뭐든지 자판기_debug/g' "${ANDROID_MANIFEST}"
DEBUG_APK="$(build_and_upload "${APP_NAME}-${SERIAL}-debug.apk" "build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk" "apk --debug --split-per-abi --target-platform android-arm64" | tail -n1)"
LINKS="- <${DEBUG_APK}|DEBUG> 🎉"
sed -i 's/me.hoppipolla.anything_vending_machine_debug/me.hoppipolla.anything_vending_machine/g' "${BUILD_GRADLE}"
sed -i 's/뭐든지 자판기_debug/뭐든지 자판기/g' "${ANDROID_MANIFEST}"

if [ -z "${DEBUG}" ]; then
  log "Build release apk."
  RELEASE_APK="$(build_and_upload "${APP_NAME}-${SERIAL}-release.apk" "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" "apk --release --split-per-abi --target-platform android-arm64" | tail -n1)"
  LINKS="${LINKS}\n- <${RELEASE_APK}|RELEASE> 🎉"

  log "Build appbundle."
  APPBUNDLE="$(build_and_upload "${APP_NAME}-${SERIAL}.aab" "build/app/outputs/bundle/release/app-release.aab" "appbundle --release" | tail -n1)"
  LINKS="${LINKS}\n- <${APPBUNDLE}|APPBUNDLE> 🎉"
fi

log "Notify via Slack."
if [ ! -z "${SLACK_HOOK_URL}" ]; then
  MESSAGE_FILE="$(mktemp)"
  cat <<EOF > "${MESSAGE_FILE}"
*뭐든지 자판기 새 버전 출시!* 👏👏👏
${MESSAGE}

${LINKS}
EOF
  curl -XPOST "${SLACK_HOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"앱 배포\",\"channel\":\"C0146N9AUGK\",\"icon_emoji\":\":man-running:\",\"text\":\"$(cat "${MESSAGE_FILE}")\"}"
  rm -f "${MESSAGE_FILE}"
fi
