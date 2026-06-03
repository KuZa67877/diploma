# Performance automation

## What is collected

- cold startup trace from `flutter run --profile --trace-startup`
- `auth -> home` UI latency
- `dashboard -> analytics` UI latency
- `analytics -> export` UI latency
- frame timings: average build/raster/total frame duration and jank count
- direct local model timings for Harvard, sleep quality, stress, physiology anomaly, baseline forecast
- Android memory snapshot via `adb shell dumpsys meminfo`
- APK size

## Files

- `integration_test/app_perf_test.dart`
- `integration_test/perf_driver.dart`
- `tool/run_android_perf.sh`
- `tool/merge_perf_reports.dart`

## Prerequisites

1. Run `flutter pub get` after the new `integration_test` dependency is added.
2. Connect a physical Android device with USB debugging enabled.
3. Make sure the app can run in local mode:
   `ENABLE_FIREBASE_SYNC=false`

## Run

```bash
bash tool/run_android_perf.sh <device_id>
```

If `device_id` is omitted, Flutter/adb will use the default connected device.

## Output

The aggregated report is written to:

```text
artifacts/perf/performance_summary.json
```

The raw pieces are also saved in `artifacts/perf/`:

- `perf_response_data.json`
- `startup_info.json`
- `android_meminfo.txt`
