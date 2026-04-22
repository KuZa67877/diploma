#!/usr/bin/env python3
"""External dataset adapters for sleep student self-supervised pretraining.

This module provides health-contract-compatible feature extraction for external
sources used only in representation pretraining.
"""

from __future__ import annotations

import re
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Sequence, Tuple

import numpy as np
import pandas as pd
import requests

SLEEP_ACCEL_BASE = "https://physionet.org/files/sleep-accel/1.0.0"
MMASH_BASE = "https://physionet.org/files/mmash/1.0.0"

SLEEP_ACCEL_DIRS = ("heart_rate", "steps", "motion")


@dataclass
class ExternalSourcePayload:
    source: str
    features: pd.DataFrame
    groups: np.ndarray
    sample_weights: np.ndarray
    metadata: Dict[str, object]


@dataclass
class ExternalPretrainBundle:
    features: pd.DataFrame
    groups: np.ndarray
    sample_weights: np.ndarray
    modality_targets: np.ndarray
    metadata: Dict[str, object]


def load_external_pretrain_bundle(
    *,
    dataset_dir: Path,
    sources: Sequence[str],
    allow_download: bool,
    health_contract_features: Sequence[str],
) -> ExternalPretrainBundle:
    requested_sources = [name.strip().lower() for name in sources if name.strip()]
    normalized_sources: List[str] = []
    for source in requested_sources:
        if source not in normalized_sources:
            normalized_sources.append(source)

    source_payloads: List[ExternalSourcePayload] = []
    skipped_sources: Dict[str, str] = {}

    for source in normalized_sources:
        try:
            if source == "sleep_accel":
                payload = _load_sleep_accel_pretrain(
                    dataset_dir=dataset_dir,
                    allow_download=allow_download,
                )
            elif source == "mmash":
                payload = _load_mmash_pretrain(
                    dataset_dir=dataset_dir,
                    allow_download=allow_download,
                )
            else:
                skipped_sources[source] = "unsupported_source"
                continue
        except Exception as error:  # pragma: no cover - defensive path
            skipped_sources[source] = str(error)
            continue

        if payload.features.empty:
            skipped_sources[source] = "empty_after_preprocessing"
            continue
        source_payloads.append(payload)

    modality_feature_names = [
        name for name in health_contract_features if name.endswith("_missing")
    ]

    if not source_payloads:
        empty_frame = pd.DataFrame(columns=list(health_contract_features))
        empty_modality = np.zeros((0, len(modality_feature_names)), dtype=np.float64)
        metadata = {
            "requested_sources": normalized_sources,
            "loaded_sources": [],
            "skipped_sources": skipped_sources,
            "rows_by_source": {},
            "groups_by_source": {},
            "total_rows": 0,
            "total_groups": 0,
            "modality_feature_names": modality_feature_names,
        }
        return ExternalPretrainBundle(
            features=empty_frame,
            groups=np.array([], dtype=object),
            sample_weights=np.array([], dtype=np.float64),
            modality_targets=empty_modality,
            metadata=metadata,
        )

    combined_features = pd.concat(
        [payload.features for payload in source_payloads],
        ignore_index=True,
        sort=False,
    )
    combined_groups = np.concatenate([payload.groups for payload in source_payloads])
    combined_weights = np.concatenate(
        [payload.sample_weights for payload in source_payloads]
    ).astype(np.float64)
    combined_weights = np.where(np.isfinite(combined_weights), combined_weights, 1.0)
    combined_weights = np.clip(combined_weights, 0.1, 5.0)

    projected = _project_health_contract(
        features=combined_features,
        health_contract_features=health_contract_features,
    )
    modality_targets = _extract_modality_targets(
        features=projected,
        modality_feature_names=modality_feature_names,
    )

    rows_by_source = {
        payload.source: int(len(payload.features)) for payload in source_payloads
    }
    groups_by_source = {
        payload.source: int(len(np.unique(payload.groups))) for payload in source_payloads
    }
    metadata = {
        "requested_sources": normalized_sources,
        "loaded_sources": [payload.source for payload in source_payloads],
        "skipped_sources": skipped_sources,
        "rows_by_source": rows_by_source,
        "groups_by_source": groups_by_source,
        "total_rows": int(len(projected)),
        "total_groups": int(len(np.unique(combined_groups))),
        "modality_feature_names": modality_feature_names,
        "source_metadata": {
            payload.source: payload.metadata for payload in source_payloads
        },
    }

    return ExternalPretrainBundle(
        features=projected,
        groups=combined_groups,
        sample_weights=combined_weights,
        modality_targets=modality_targets,
        metadata=metadata,
    )


def _project_health_contract(
    *,
    features: pd.DataFrame,
    health_contract_features: Sequence[str],
) -> pd.DataFrame:
    projected = pd.DataFrame(index=features.index)
    for name in health_contract_features:
        projected[name] = features[name] if name in features.columns else np.nan
    return projected


def _extract_modality_targets(
    *,
    features: pd.DataFrame,
    modality_feature_names: Sequence[str],
) -> np.ndarray:
    if not modality_feature_names:
        return np.zeros((len(features), 0), dtype=np.float64)
    matrix = (
        features[list(modality_feature_names)]
        .apply(pd.to_numeric, errors="coerce")
        .to_numpy(dtype=np.float64)
    )
    matrix = np.where(np.isfinite(matrix), matrix, 1.0)
    return np.clip(matrix, 0.0, 1.0)


def _load_sleep_accel_pretrain(
    *,
    dataset_dir: Path,
    allow_download: bool,
) -> ExternalSourcePayload:
    accel_dir = dataset_dir / "sleep_accel"
    accel_dir.mkdir(parents=True, exist_ok=True)
    _ensure_sleep_accel_files(accel_dir, allow_download=allow_download)

    hr_files = sorted((accel_dir / "heart_rate").glob("*_heartrate.txt"))
    if not hr_files:
        raise RuntimeError("sleep_accel heart_rate files are missing")

    rows: List[Dict[str, float]] = []
    groups: List[str] = []
    sample_weights: List[float] = []

    for hr_file in hr_files:
        subject = hr_file.name.split("_", 1)[0]
        steps_file = accel_dir / "steps" / f"{subject}_steps.txt"
        motion_file = accel_dir / "motion" / f"{subject}_acceleration.txt"

        hr = pd.read_csv(
            hr_file,
            names=["offset_s", "hr"],
            engine="python",
            sep=r"\s+|,",
        )
        if hr.empty:
            continue
        hr["offset_s"] = pd.to_numeric(hr["offset_s"], errors="coerce")
        hr["hr"] = pd.to_numeric(hr["hr"], errors="coerce")
        hr = hr.dropna(subset=["offset_s", "hr"])
        if hr.empty:
            continue

        if steps_file.exists():
            steps = pd.read_csv(
                steps_file,
                names=["offset_s", "steps"],
                engine="python",
                sep=r"\s+|,",
            )
            steps["offset_s"] = pd.to_numeric(steps["offset_s"], errors="coerce")
            steps["steps"] = pd.to_numeric(steps["steps"], errors="coerce")
            steps = steps.dropna(subset=["offset_s", "steps"])
        else:
            steps = pd.DataFrame(columns=["offset_s", "steps"])

        if motion_file.exists():
            motion = pd.read_csv(
                motion_file,
                names=["offset_s", "acc_x", "acc_y", "acc_z"],
                engine="python",
                sep=r"\s+|,",
            )
            motion["offset_s"] = pd.to_numeric(motion["offset_s"], errors="coerce")
            for col in ("acc_x", "acc_y", "acc_z"):
                motion[col] = pd.to_numeric(motion[col], errors="coerce")
            motion = motion.dropna(subset=["offset_s", "acc_x", "acc_y", "acc_z"])
            if not motion.empty:
                motion["acc_mag"] = np.sqrt(
                    np.square(motion["acc_x"])
                    + np.square(motion["acc_y"])
                    + np.square(motion["acc_z"])
                )
        else:
            motion = pd.DataFrame(columns=["offset_s", "acc_mag"])

        window_seconds = 1800.0
        stride_seconds = 900.0
        offset_min = float(hr["offset_s"].min())
        offset_max = float(hr["offset_s"].max())
        if not np.isfinite(offset_min) or not np.isfinite(offset_max):
            continue
        if offset_max - offset_min < window_seconds:
            continue

        starts = np.arange(offset_min, offset_max - window_seconds + 1e-9, stride_seconds)
        for start in starts:
            end = start + window_seconds
            hr_window = hr[(hr["offset_s"] >= start) & (hr["offset_s"] < end)]
            if len(hr_window) < 8:
                continue
            steps_window = steps[(steps["offset_s"] >= start) & (steps["offset_s"] < end)]
            motion_window = motion[(motion["offset_s"] >= start) & (motion["offset_s"] < end)]

            feat = _init_feature_dict()
            hr_values = hr_window["hr"].to_numpy(dtype=np.float64)
            hr_time = hr_window["offset_s"].to_numpy(dtype=np.float64)
            steps_values = (
                steps_window["steps"].to_numpy(dtype=np.float64)
                if not steps_window.empty
                else np.array([], dtype=np.float64)
            )
            motion_values = (
                motion_window["acc_mag"].to_numpy(dtype=np.float64)
                if not motion_window.empty
                else np.array([], dtype=np.float64)
            )

            _add_numeric_stats(feat, "HR", hr_values)
            _add_numeric_stats(feat, "steps", steps_values)
            _add_numeric_stats(feat, "distance", np.array([], dtype=np.float64))
            _add_numeric_stats(feat, "calories", np.array([], dtype=np.float64))
            _add_numeric_stats(feat, "sdnn", np.array([], dtype=np.float64))
            _add_numeric_stats(feat, "rmssd", np.array([], dtype=np.float64))

            feat["window_count"] = float(len(hr_values))
            feat["coverage_hours"] = float(window_seconds / 3600.0)
            feat["window_density"] = float(len(hr_values) / max(window_seconds / 60.0, 1.0))
            feat["sleep_window_hours_clock"] = float(window_seconds / 3600.0)
            feat["asleep_hour"] = float((start / 3600.0) % 24.0)
            feat["wakeup_hour"] = float((end / 3600.0) % 24.0)
            feat["weekday"] = float(np.nan)
            feat["hr_trend"] = _safe_trend_slope(hr_values, hr_time)

            if motion_values.size > 0 and np.isfinite(feat.get("steps_mean", np.nan)):
                feat["steps_mean"] = float(np.nanmean([feat["steps_mean"], np.nanmean(motion_values)]))

            _set_modality_missing_flags(
                feat,
                hr_present=hr_values.size > 0,
                steps_present=steps_values.size > 0,
                distance_present=False,
                calories_present=False,
                sdnn_present=False,
                rmssd_present=False,
            )
            _add_engineered_health_features(feat)

            rows.append(feat)
            groups.append(subject)
            window_quality = float(np.clip(len(hr_values) / 120.0, 0.25, 1.0))
            if steps_values.size > 0:
                window_quality = float(min(1.0, window_quality + 0.1))
            sample_weights.append(window_quality)

    if not rows:
        raise RuntimeError("sleep_accel preprocessing produced zero rows")

    features = pd.DataFrame(rows).replace([np.inf, -np.inf], np.nan)
    features["__group"] = np.array(groups, dtype=object)
    features["__order"] = np.arange(len(features), dtype=np.int64)
    features = _augment_personal_baselines(features)
    features = features.drop(columns=["__group", "__order"], errors="ignore")

    return ExternalSourcePayload(
        source="sleep_accel",
        features=features,
        groups=np.array(groups, dtype=object),
        sample_weights=np.array(sample_weights, dtype=np.float64),
        metadata={
            "rows": int(len(features)),
            "groups": int(len(np.unique(groups))),
            "window_seconds": 1800,
            "stride_seconds": 900,
        },
    )


def _load_mmash_pretrain(
    *,
    dataset_dir: Path,
    allow_download: bool,
) -> ExternalSourcePayload:
    mmash_dir = dataset_dir / "mmash"
    if not mmash_dir.exists():
        if allow_download:
            _download_mmash_archive(mmash_dir)
        else:
            raise RuntimeError("mmash directory missing and download disabled")

    actigraph_files = sorted(mmash_dir.glob("**/Actigraph.csv"))
    if not actigraph_files:
        raise RuntimeError("mmash scaffold: Actigraph.csv not found")

    rows: List[Dict[str, float]] = []
    groups: List[str] = []
    sample_weights: List[float] = []

    for file_path in actigraph_files:
        try:
            frame = pd.read_csv(file_path)
        except Exception:
            continue
        if frame.empty:
            continue

        subject = file_path.parent.name
        timestamp = _resolve_mmash_timestamps(frame)
        if timestamp is None:
            continue

        hr_values = _resolve_numeric_column(frame, ["HR", "hr", "heart_rate"])
        steps_values = _resolve_numeric_column(frame, ["Steps", "steps"])
        if hr_values is None:
            continue

        work = pd.DataFrame(
            {
                "offset_s": timestamp,
                "hr": hr_values,
                "steps": steps_values if steps_values is not None else np.nan,
            }
        )
        work = work.dropna(subset=["offset_s"]).sort_values("offset_s")
        if work.empty:
            continue

        offset_min = float(work["offset_s"].min())
        offset_max = float(work["offset_s"].max())
        window_seconds = 1800.0
        stride_seconds = 900.0
        if offset_max - offset_min < window_seconds:
            continue

        starts = np.arange(offset_min, offset_max - window_seconds + 1e-9, stride_seconds)
        for start in starts:
            end = start + window_seconds
            window = work[(work["offset_s"] >= start) & (work["offset_s"] < end)]
            hr_window = pd.to_numeric(window["hr"], errors="coerce").dropna()
            if len(hr_window) < 8:
                continue
            steps_window = pd.to_numeric(window["steps"], errors="coerce").dropna()

            feat = _init_feature_dict()
            hr_array = hr_window.to_numpy(dtype=np.float64)
            hr_time = pd.to_numeric(window.loc[hr_window.index, "offset_s"], errors="coerce").to_numpy(dtype=np.float64)
            steps_array = steps_window.to_numpy(dtype=np.float64)

            _add_numeric_stats(feat, "HR", hr_array)
            _add_numeric_stats(feat, "steps", steps_array)
            _add_numeric_stats(feat, "distance", np.array([], dtype=np.float64))
            _add_numeric_stats(feat, "calories", np.array([], dtype=np.float64))
            _add_numeric_stats(feat, "sdnn", np.array([], dtype=np.float64))
            _add_numeric_stats(feat, "rmssd", np.array([], dtype=np.float64))

            feat["window_count"] = float(len(hr_array))
            feat["coverage_hours"] = float(window_seconds / 3600.0)
            feat["window_density"] = float(len(hr_array) / max(window_seconds / 60.0, 1.0))
            feat["sleep_window_hours_clock"] = float(window_seconds / 3600.0)
            feat["asleep_hour"] = float((start / 3600.0) % 24.0)
            feat["wakeup_hour"] = float((end / 3600.0) % 24.0)
            feat["weekday"] = float(np.nan)
            feat["hr_trend"] = _safe_trend_slope(hr_array, hr_time)

            _set_modality_missing_flags(
                feat,
                hr_present=hr_array.size > 0,
                steps_present=steps_array.size > 0,
                distance_present=False,
                calories_present=False,
                sdnn_present=False,
                rmssd_present=False,
            )
            _add_engineered_health_features(feat)

            rows.append(feat)
            groups.append(subject)
            sample_weights.append(float(np.clip(len(hr_array) / 120.0, 0.25, 1.0)))

    if not rows:
        raise RuntimeError("mmash scaffold produced zero rows")

    features = pd.DataFrame(rows).replace([np.inf, -np.inf], np.nan)
    features["__group"] = np.array(groups, dtype=object)
    features["__order"] = np.arange(len(features), dtype=np.int64)
    features = _augment_personal_baselines(features)
    features = features.drop(columns=["__group", "__order"], errors="ignore")

    return ExternalSourcePayload(
        source="mmash",
        features=features,
        groups=np.array(groups, dtype=object),
        sample_weights=np.array(sample_weights, dtype=np.float64),
        metadata={
            "rows": int(len(features)),
            "groups": int(len(np.unique(groups))),
            "window_seconds": 1800,
            "stride_seconds": 900,
        },
    )


def _resolve_mmash_timestamps(frame: pd.DataFrame) -> np.ndarray | None:
    if "TIMESTAMP" in frame.columns:
        timestamp = pd.to_numeric(frame["TIMESTAMP"], errors="coerce").to_numpy(
            dtype=np.float64
        )
        return timestamp

    if "day" in frame.columns and "time" in frame.columns:
        day = pd.to_numeric(frame["day"], errors="coerce").to_numpy(dtype=np.float64)
        seconds = frame["time"].astype(str).map(_parse_hms_to_seconds).to_numpy(
            dtype=np.float64
        )
        return ((day - 1.0) * 86400.0) + seconds

    return None


def _parse_hms_to_seconds(value: str) -> float:
    text = value.strip()
    if not text:
        return float("nan")
    parts = text.split(":")
    if len(parts) != 3:
        return float("nan")
    try:
        hours = int(parts[0])
        minutes = int(parts[1])
        seconds = float(parts[2])
    except ValueError:
        return float("nan")
    return float((hours * 3600) + (minutes * 60) + seconds)


def _resolve_numeric_column(
    frame: pd.DataFrame,
    candidates: Sequence[str],
) -> np.ndarray | None:
    for column in candidates:
        if column in frame.columns:
            return pd.to_numeric(frame[column], errors="coerce").to_numpy(dtype=np.float64)
    return None


def _ensure_sleep_accel_files(base_dir: Path, allow_download: bool) -> None:
    for folder in SLEEP_ACCEL_DIRS:
        (base_dir / folder).mkdir(parents=True, exist_ok=True)
    if any((base_dir / "heart_rate").glob("*_heartrate.txt")):
        return
    if not allow_download:
        raise RuntimeError("sleep_accel files missing and download disabled")

    for folder in SLEEP_ACCEL_DIRS:
        remote_dir = f"{SLEEP_ACCEL_BASE}/{folder}/"
        names = _list_remote_files(remote_dir, suffix=".txt")
        if not names and folder == "motion":
            continue
        for name in names:
            destination = base_dir / folder / name
            if destination.exists():
                continue
            _download_file(f"{remote_dir}{name}", destination)


def _download_mmash_archive(mmash_dir: Path) -> None:
    mmash_dir.mkdir(parents=True, exist_ok=True)
    archive_path = mmash_dir / "MMASH.zip"
    if not archive_path.exists():
        _download_file(f"{MMASH_BASE}/MMASH.zip", archive_path)
    with zipfile.ZipFile(archive_path, "r") as archive:
        archive.extractall(mmash_dir)


def _list_remote_files(url: str, suffix: str) -> List[str]:
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    matches = re.findall(r'href="([^"]+)"', response.text)
    return sorted({name.strip() for name in matches if name.strip().endswith(suffix)})


def _download_file(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        with destination.open("wb") as out:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    out.write(chunk)


def _init_feature_dict() -> Dict[str, float]:
    return {
        "window_count": float("nan"),
        "coverage_hours": float("nan"),
        "window_density": float("nan"),
        "asleep_hour": float("nan"),
        "wakeup_hour": float("nan"),
        "weekday": float("nan"),
        "sleep_window_hours_clock": float("nan"),
        "hr_trend": 0.0,
    }


def _augment_personal_baselines(features_df: pd.DataFrame) -> pd.DataFrame:
    if "__group" not in features_df.columns:
        return features_df

    df = features_df.copy()
    if "__order" not in df.columns:
        df["__order"] = np.arange(len(df), dtype=np.int64)
    df = df.sort_values(["__group", "__order"]).reset_index(drop=True)

    baseline_cols = [
        "HR_mean",
        "rmssd_mean",
        "sdnn_mean",
        "steps_mean",
        "distance_mean",
        "calories_mean",
        "window_count",
        "coverage_hours",
        "asleep_hour",
        "wakeup_hour",
    ]

    for col in baseline_cols:
        if col not in df.columns:
            continue
        shifted = df.groupby("__group")[col].shift(1)
        roll_mean = (
            shifted.groupby(df["__group"])
            .rolling(window=7, min_periods=3)
            .mean()
            .reset_index(level=0, drop=True)
        )
        roll_std = (
            shifted.groupby(df["__group"])
            .rolling(window=7, min_periods=3)
            .std()
            .reset_index(level=0, drop=True)
        )
        df[f"{col}_baseline7"] = roll_mean
        df[f"{col}_delta7"] = df[col] - roll_mean
        df[f"{col}_z7"] = (df[col] - roll_mean) / (roll_std + 1e-6)

    df["nights_since_start"] = df.groupby("__group").cumcount().astype(float)
    return df.sort_values("__order").reset_index(drop=True)


def _add_numeric_stats(target: Dict[str, float], prefix: str, values: np.ndarray) -> None:
    finite = values[np.isfinite(values)] if values.size else np.array([], dtype=np.float64)
    if finite.size == 0:
        target[f"{prefix}_mean"] = float("nan")
        target[f"{prefix}_std"] = float("nan")
        target[f"{prefix}_min"] = float("nan")
        target[f"{prefix}_max"] = float("nan")
        target[f"{prefix}_p10"] = float("nan")
        target[f"{prefix}_p90"] = float("nan")
        return

    target[f"{prefix}_mean"] = float(np.nanmean(finite))
    target[f"{prefix}_std"] = float(np.nanstd(finite))
    target[f"{prefix}_min"] = float(np.nanmin(finite))
    target[f"{prefix}_max"] = float(np.nanmax(finite))
    target[f"{prefix}_p10"] = float(np.nanpercentile(finite, 10))
    target[f"{prefix}_p90"] = float(np.nanpercentile(finite, 90))


def _safe_trend_slope(values: np.ndarray, timestamps_s: np.ndarray) -> float:
    if values.size < 3 or timestamps_s.size < 3:
        return 0.0
    mask = np.isfinite(values) & np.isfinite(timestamps_s)
    if int(mask.sum()) < 3:
        return 0.0
    x = timestamps_s[mask].astype(np.float64)
    y = values[mask].astype(np.float64)
    x = x - x.mean()
    denom = float(np.dot(x, x))
    if denom < 1e-12:
        return 0.0
    return float(np.dot(x, y - y.mean()) / denom)


def _set_modality_missing_flags(
    feat: Dict[str, float],
    *,
    hr_present: bool,
    steps_present: bool,
    distance_present: bool,
    calories_present: bool,
    sdnn_present: bool,
    rmssd_present: bool,
) -> None:
    feat["hr_missing"] = 0.0 if hr_present else 1.0
    feat["steps_missing"] = 0.0 if steps_present else 1.0
    feat["distance_missing"] = 0.0 if distance_present else 1.0
    feat["calories_missing"] = 0.0 if calories_present else 1.0
    feat["sdnn_missing"] = 0.0 if sdnn_present else 1.0
    feat["rmssd_missing"] = 0.0 if rmssd_present else 1.0


def _add_engineered_health_features(feat: Dict[str, float]) -> None:
    asleep_hour = _safe_float(feat.get("asleep_hour"))
    wakeup_hour = _safe_float(feat.get("wakeup_hour"))
    weekday = _safe_float(feat.get("weekday"))
    coverage_hours = _safe_float(feat.get("coverage_hours"))
    window_count = _safe_float(feat.get("window_count"))
    sleep_window_hours = _safe_float(feat.get("sleep_window_hours_clock"))
    hr_mean = _safe_float(feat.get("HR_mean"))
    rmssd_mean = _safe_float(feat.get("rmssd_mean"))
    sdnn_mean = _safe_float(feat.get("sdnn_mean"))
    steps_mean = _safe_float(feat.get("steps_mean"))

    feat["asleep_hour_sin"] = _cyclic_sin(asleep_hour, period=24.0)
    feat["asleep_hour_cos"] = _cyclic_cos(asleep_hour, period=24.0)
    feat["wakeup_hour_sin"] = _cyclic_sin(wakeup_hour, period=24.0)
    feat["wakeup_hour_cos"] = _cyclic_cos(wakeup_hour, period=24.0)
    feat["weekday_sin"] = _cyclic_sin(weekday, period=7.0)
    feat["weekday_cos"] = _cyclic_cos(weekday, period=7.0)

    feat["coverage_hours_log1p"] = _safe_log1p_non_negative(coverage_hours)
    feat["window_count_log1p"] = _safe_log1p_non_negative(window_count)
    feat["sleep_window_hours_log1p"] = _safe_log1p_non_negative(sleep_window_hours)

    feat["hr_rmssd_interaction"] = _safe_interaction(hr_mean, rmssd_mean)
    feat["hr_sdnn_interaction"] = _safe_interaction(hr_mean, sdnn_mean)
    feat["steps_coverage_interaction"] = _safe_steps_coverage(steps_mean, coverage_hours)

    if np.isnan(asleep_hour) or np.isnan(wakeup_hour):
        feat["sleep_phase_span_abs"] = float("nan")
        feat["sleep_phase_span_wrap"] = float("nan")
    else:
        span_abs = abs(wakeup_hour - asleep_hour)
        feat["sleep_phase_span_abs"] = float(span_abs)
        feat["sleep_phase_span_wrap"] = float(max(0.0, 24.0 - span_abs))


def _safe_float(value: object) -> float:
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return float("nan")
    if np.isnan(numeric):
        return float("nan")
    return numeric


def _cyclic_sin(value: float, period: float) -> float:
    if np.isnan(value) or period <= 0:
        return float("nan")
    return float(np.sin(2.0 * np.pi * value / period))


def _cyclic_cos(value: float, period: float) -> float:
    if np.isnan(value) or period <= 0:
        return float("nan")
    return float(np.cos(2.0 * np.pi * value / period))


def _safe_log1p_non_negative(value: float) -> float:
    if np.isnan(value):
        return float("nan")
    return float(np.log1p(max(value, 0.0)))


def _safe_interaction(a: float, b: float) -> float:
    if np.isnan(a) or np.isnan(b):
        return float("nan")
    return float(a * b)


def _safe_steps_coverage(steps_mean: float, coverage_hours: float) -> float:
    if np.isnan(steps_mean) or np.isnan(coverage_hours):
        return float("nan")
    return float(np.sqrt(max(steps_mean, 0.0)) * max(coverage_hours, 0.0))
