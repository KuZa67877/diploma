#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pickle
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from scipy.signal import find_peaks

# WESAD label mapping: 1 baseline, 2 stress, 3 amusement, 4 meditation
VALID_LABELS = {1: 0, 2: 1}


def rolling_slope(x: np.ndarray) -> float:
    if len(x) < 2 or np.allclose(x, x[0]):
        return 0.0
    t = np.arange(len(x), dtype=float)
    a, _ = np.polyfit(t, x, 1)
    return float(a)


def estimate_hr_and_sdnn(bvp: np.ndarray, fs: float) -> tuple[float, float, float, float, float]:
    if len(bvp) < fs * 10:
        return np.nan, np.nan, np.nan, np.nan, np.nan
    peaks, _ = find_peaks(bvp, distance=max(1, int(fs * 0.4)), prominence=np.std(bvp) * 0.05)
    if len(peaks) < 3:
        return np.nan, np.nan, np.nan, np.nan, np.nan
    rr = np.diff(peaks) / fs
    hr = 60.0 / rr
    return float(np.mean(hr)), float(np.std(hr)), float(np.min(hr)), float(np.max(hr)), float(np.std(rr) * 1000.0)


def build_rows_for_subject(subject_dir: Path, window_seconds: int = 300) -> List[Dict[str, object]]:
    pkl_path = subject_dir / f"{subject_dir.name}.pkl"
    with pkl_path.open("rb") as f:
        data = pickle.load(f, encoding="latin1")

    label = np.asarray(data["label"]).reshape(-1)
    wrist = data["signal"]["wrist"]
    chest = data["signal"].get("chest", {})

    bvp = np.asarray(wrist.get("BVP", [])).reshape(-1)
    acc = np.asarray(wrist.get("ACC", []))
    temp = np.asarray(wrist.get("TEMP", [])).reshape(-1)
    resp = np.asarray(chest.get("Resp", [])).reshape(-1) if "Resp" in chest else np.array([])

    # Official WESAD rates
    label_fs = 700.0
    bvp_fs = 64.0
    acc_fs = 32.0
    temp_fs = 4.0
    resp_fs = 700.0 if len(resp) else None

    total_seconds = int(len(label) / label_fs)
    rows = []
    prev_hr = np.nan

    for start_s in range(0, total_seconds - window_seconds + 1, window_seconds):
        end_s = start_s + window_seconds
        label_slice = label[int(start_s * label_fs):int(end_s * label_fs)]
        if len(label_slice) == 0:
            continue
        uniq, counts = np.unique(label_slice, return_counts=True)
        dominant = int(uniq[np.argmax(counts)])
        if dominant not in VALID_LABELS:
            continue

        bvp_slice = bvp[int(start_s * bvp_fs):int(end_s * bvp_fs)]
        acc_slice = acc[int(start_s * acc_fs):int(end_s * acc_fs)] if len(acc) else np.empty((0, 3))
        temp_slice = temp[int(start_s * temp_fs):int(end_s * temp_fs)] if len(temp) else np.array([])
        resp_slice = resp[int(start_s * resp_fs):int(end_s * resp_fs)] if resp_fs else np.array([])

        hr_mean, hr_std, hr_min, hr_max, sdnn_ms = estimate_hr_and_sdnn(bvp_slice, bvp_fs)
        acc_mag = np.linalg.norm(acc_slice, axis=1) if len(acc_slice) else np.array([])

        hour = ((start_s / 3600.0) % 24.0)
        activity_load = float(np.nanmean(acc_mag)) if len(acc_mag) else np.nan
        phys_strain = np.nanmean([hr_mean, np.nanmean(resp_slice) if len(resp_slice) else np.nan])

        row = {
            "subject_id": subject_dir.name,
            "window_start": pd.Timestamp("2024-01-01") + pd.Timedelta(seconds=start_s),
            "label": VALID_LABELS[dominant],
            "hr_mean": hr_mean,
            "hr_std": hr_std,
            "hr_min": hr_min,
            "hr_max": hr_max,
            "hr_slope": rolling_slope(bvp_slice[::max(1, int(bvp_fs))]) if len(bvp_slice) else np.nan,
            "hr_delta_prev": np.nan if np.isnan(prev_hr) or np.isnan(hr_mean) else hr_mean - prev_hr,
            "resting_hr_mean": np.nan,
            "hr_over_rhr": np.nan,
            "hrv_sdnn_mean": sdnn_ms,
            "hrv_sdnn_std": 0.0 if not np.isnan(sdnn_ms) else np.nan,
            "resp_rate_mean": float(np.nanmean(resp_slice)) if len(resp_slice) else np.nan,
            "resp_rate_std": float(np.nanstd(resp_slice)) if len(resp_slice) else np.nan,
            "steps_sum": np.nan,
            "distance_sum": np.nan,
            "active_energy_sum": np.nan,
            "exercise_time_sum": np.nan,
            "body_temp_mean": float(np.nanmean(temp_slice)) if len(temp_slice) else np.nan,
            "wrist_temp_mean": float(np.nanmean(temp_slice)) if len(temp_slice) else np.nan,
            "spo2_mean": np.nan,
            "coverage_ratio": float(np.mean(~np.isnan([hr_mean, sdnn_ms]))),
            "minutes_since_workout": np.nan,
            "recent_sleep_score": np.nan,
            "recent_activity_score": np.nan,
            "hour_sin": math.sin(2 * math.pi * hour / 24.0),
            "hour_cos": math.cos(2 * math.pi * hour / 24.0),
            "activity_load_proxy": activity_load,
            "physiological_strain_proxy": phys_strain,
        }

        prev_hr = hr_mean
        missing_map = {
            "hr_mean": "missing_hr",
            "resting_hr_mean": "missing_resting_hr",
            "hrv_sdnn_mean": "missing_hrv_sdnn",
            "resp_rate_mean": "missing_resp_rate",
            "steps_sum": "missing_steps",
            "distance_sum": "missing_distance",
            "active_energy_sum": "missing_active_energy",
            "exercise_time_sum": "missing_exercise_time",
            "body_temp_mean": "missing_body_temp",
            "wrist_temp_mean": "missing_wrist_temp",
            "spo2_mean": "missing_spo2",
        }
        for src, dst in missing_map.items():
            row[dst] = float(pd.isna(row[src]))

        row["sample_weight"] = max(0.25, row["coverage_ratio"])
        rows.append(row)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wesad_root", required=True)
    parser.add_argument("--out_csv", required=True)
    args = parser.parse_args()

    root = Path(args.wesad_root)
    all_rows: List[Dict[str, object]] = []
    for sub in sorted(root.glob("S*")):
        pkl_path = sub / f"{sub.name}.pkl"
        if pkl_path.exists():
            all_rows.extend(build_rows_for_subject(sub))

    if not all_rows:
        raise SystemExit("No WESAD subject files found")

    df = pd.DataFrame(all_rows)
    df.to_csv(args.out_csv, index=False)
    print(f"Saved {len(df)} rows to {args.out_csv}")


if __name__ == "__main__":
    main()
