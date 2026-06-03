#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${1:-}"
FLAVOR="${FLAVOR:-dev}"
APP_ID="${APP_ID:-com.example.medi_ai.dev}"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts/perf}"
PERF_REPORT_PATH="${ARTIFACT_DIR}/perf_response_data.json"
MEMINFO_PATH="${ARTIFACT_DIR}/android_meminfo.txt"
STARTUP_JSON_PATH="${ARTIFACT_DIR}/startup_info.json"
STARTUP_RUN_LOG_PATH="${ARTIFACT_DIR}/startup_run.log"
SUMMARY_PATH="${ARTIFACT_DIR}/performance_summary.json"
APK_PATH="${APK_PATH:-app-dev-release.apk}"

mkdir -p "${ARTIFACT_DIR}"

DEVICE_ARGS=()
if [[ -n "${DEVICE_ID}" ]]; then
  DEVICE_ARGS=(-d "${DEVICE_ID}")
fi

ADB_ARGS=()
if [[ -n "${DEVICE_ID}" ]]; then
  ADB_ARGS=(-s "${DEVICE_ID}")
fi

adb "${ADB_ARGS[@]}" shell pm clear "${APP_ID}" >/dev/null || true

rm -f build/startup_info.json "${STARTUP_JSON_PATH}" "${PERF_REPORT_PATH}" "${MEMINFO_PATH}"

set +e
flutter run \
  "${DEVICE_ARGS[@]}" \
  --profile \
  --flavor "${FLAVOR}" \
  --trace-startup \
  --no-dds \
  --dart-define=ENABLE_FIREBASE_SYNC=false \
  --dart-define=ENABLE_SOCIAL_AUTH=false \
  --dart-define=ENABLE_AUTH_BYPASS=false \
  -t lib/main.dart > "${STARTUP_RUN_LOG_PATH}" 2>&1 &
STARTUP_RUN_PID=$!

for _ in $(seq 1 90); do
  if [[ -f build/startup_info.json ]]; then
    break
  fi
  sleep 1
done

kill -INT "${STARTUP_RUN_PID}" >/dev/null 2>&1 || true
wait "${STARTUP_RUN_PID}" >/dev/null 2>&1 || true
set -e

if [[ -f build/startup_info.json ]]; then
  cp build/startup_info.json "${STARTUP_JSON_PATH}"
fi

adb "${ADB_ARGS[@]}" shell pm clear "${APP_ID}" >/dev/null || true

PERF_REPORT_PATH="${PERF_REPORT_PATH}" flutter drive \
  "${DEVICE_ARGS[@]}" \
  --profile \
  --no-dds \
  --keep-app-running \
  --flavor "${FLAVOR}" \
  --driver integration_test/perf_driver.dart \
  --target integration_test/app_perf_test.dart \
  --dart-define=ENABLE_FIREBASE_SYNC=false \
  --dart-define=ENABLE_SOCIAL_AUTH=false \
  --dart-define=ENABLE_AUTH_BYPASS=false

adb "${ADB_ARGS[@]}" shell dumpsys meminfo "${APP_ID}" > "${MEMINFO_PATH}" || true
adb "${ADB_ARGS[@]}" shell am force-stop "${APP_ID}" >/dev/null 2>&1 || true

dart tool/merge_perf_reports.dart \
  --perf "${PERF_REPORT_PATH}" \
  --startup "${STARTUP_JSON_PATH}" \
  --meminfo "${MEMINFO_PATH}" \
  --apk "${APK_PATH}" \
  --output "${SUMMARY_PATH}"
