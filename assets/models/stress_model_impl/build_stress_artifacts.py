#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

os.environ.setdefault("LOKY_MAX_CPU_COUNT", "1")

from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    average_precision_score,
    balanced_accuracy_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    mean_absolute_error,
    roc_auc_score,
)
from sklearn.model_selection import LeaveOneGroupOut

SEED = 42
EPS = 1e-8
TRAINING_PIPELINE_VERSION = "stress-scorecard-pipeline-v2"
DEFAULT_DATASET_SOURCE = "stress_app_health_windows"
DEFAULT_DATASET_URI = "local://user-provided-training-csv"
DEFAULT_DATASET_VERSION = "unknown"

RUNTIME_EXTRA_FEATURES = [
    "hr_mean_5m",
    "hr_std_5m",
    "hr_min_5m",
    "hr_max_5m",
    "hr_slope_5m",
    "hr_z_5m_14",
    "steps_5m",
    "active_energy_5m",
]

FEATURES = [
    "hr_z_14",
    "hr_mean_5m",
    "hr_std_5m",
    "hr_min_5m",
    "hr_max_5m",
    "hr_slope_5m",
    "hr_z_5m_14",
    "resting_hr_z_30",
    "hrv_sdnn_z_30",
    "hrv_rmssd_z_30",
    "resp_rate_z_14",
    "temperature_z_30",
    "steps_5m",
    "steps_15m",
    "steps_1h",
    "steps_24h",
    "active_energy_5m",
    "active_energy_1h",
    "exercise_time_45m",
    "minutes_since_workout",
    "sleep_hours_latest",
    "sleep_hours_delta_7",
    "sleep_efficiency_latest",
    "sleep_efficiency_delta_7",
    "sleep_nights_7",
    "recent_sleep_score",
    "cardiac_event_present",
    "high_hr_event_present",
    "missing_hr",
    "missing_resting_hr",
    "missing_hrv_sdnn",
    "missing_hrv_rmssd",
    "missing_resp_rate",
    "missing_temperature",
    "missing_spo2",
    "missing_sleep",
    "missing_activity",
]

OLD_FEATURE_ALIASES = {
    "resting_hr_latest": ["resting_hr_mean"],
    "hrv_sdnn_latest": ["hrv_sdnn_mean"],
    "resp_rate_mean_1h": ["resp_rate_mean"],
    "temperature_latest": ["wrist_temp_mean", "body_temp_mean"],
    "spo2_min_24h": ["spo2_mean"],
    "steps_15m": ["steps_sum"],
    "steps_1h": ["steps_sum"],
    "steps_24h": ["steps_sum"],
    "active_energy_1h": ["active_energy_sum"],
    "exercise_time_45m": ["exercise_time_sum"],
}

MISSING_FLAGS = {
    "missing_hr": ["hr_mean"],
    "missing_resting_hr": ["resting_hr_latest"],
    "missing_hrv_sdnn": ["hrv_sdnn_latest"],
    "missing_hrv_rmssd": ["hrv_rmssd_latest"],
    "missing_resp_rate": ["resp_rate_mean_1h"],
    "missing_temperature": ["temperature_latest"],
    "missing_spo2": ["spo2_min_24h"],
    "missing_sleep": ["sleep_hours_latest", "recent_sleep_score"],
    "missing_activity": ["steps_1h", "active_energy_1h", "exercise_time_45m"],
}

REASON_FEATURES = {
    "elevated_hr_vs_baseline": ["hr_z_14", "hr_z_5m_14"],
    "elevated_resting_hr_vs_baseline": ["resting_hr_z_30"],
    "low_hrv_vs_baseline": ["hrv_sdnn_z_30", "hrv_rmssd_z_30"],
    "elevated_respiratory_rate": ["resp_rate_z_14"],
    "poor_sleep_recovery": ["sleep_hours_delta_7", "sleep_efficiency_delta_7"],
    "temperature_deviation": ["temperature_z_30"],
    "recent_activity_context": [
        "steps_5m",
        "steps_1h",
        "active_energy_5m",
        "active_energy_1h",
        "exercise_time_45m",
        "minutes_since_workout",
    ],
}


@dataclass
class Preprocessor:
    feature_names: list[str]
    imputer_statistics: list[float]
    robust_center: list[float]
    robust_scale: list[float]


@dataclass
class Calibration:
    method: str
    coefficient: float
    intercept: float


@dataclass
class FoldReport:
    fold: int
    held_out_subject: str
    n_train: int
    n_test: int
    logistic_roc_auc: float
    logistic_pr_auc: float
    logistic_macro_f1: float
    logistic_balanced_accuracy: float
    logistic_brier: float
    logistic_mae_score: float
    gbdt_roc_auc: float
    gbdt_pr_auc: float
    gbdt_macro_f1: float
    gbdt_balanced_accuracy: float


def set_seed(seed: int = SEED) -> None:
    random.seed(seed)
    np.random.seed(seed)


def sigmoid(x: np.ndarray | float) -> np.ndarray | float:
    return 1.0 / (1.0 + np.exp(-np.clip(x, -40, 40)))


def logit(p: np.ndarray) -> np.ndarray:
    clipped = np.clip(p, 1e-6, 1.0 - 1e-6)
    return np.log(clipped / (1.0 - clipped))


def robust_stats(values: np.ndarray) -> tuple[float, float]:
    valid = values[np.isfinite(values)]
    if valid.size == 0:
        return 0.0, 1.0
    median = float(np.median(valid))
    q25, q75 = np.percentile(valid, [25, 75])
    scale = float(q75 - q25)
    if not math.isfinite(scale) or scale <= EPS:
        scale = float(np.std(valid))
    if not math.isfinite(scale) or scale <= EPS:
        scale = 1.0
    return median, scale


def fit_preprocessor(df: pd.DataFrame) -> Preprocessor:
    imputed_columns: list[np.ndarray] = []
    imputer_statistics: list[float] = []
    centers: list[float] = []
    scales: list[float] = []

    for feature in FEATURES:
        values = pd.to_numeric(df[feature], errors="coerce").to_numpy(dtype=float)
        median, _ = robust_stats(values)
        imputer_statistics.append(median)
        imputed = np.where(np.isfinite(values), values, median)
        center, scale = robust_stats(imputed)
        centers.append(center)
        scales.append(scale)
        imputed_columns.append(imputed)

    return Preprocessor(
        feature_names=FEATURES,
        imputer_statistics=imputer_statistics,
        robust_center=centers,
        robust_scale=scales,
    )


def transform(df: pd.DataFrame, preprocessor: Preprocessor) -> np.ndarray:
    columns = []
    for i, feature in enumerate(preprocessor.feature_names):
        values = pd.to_numeric(df[feature], errors="coerce").to_numpy(dtype=float)
        imputed = np.where(
            np.isfinite(values),
            values,
            preprocessor.imputer_statistics[i],
        )
        scaled = (imputed - preprocessor.robust_center[i]) / preprocessor.robust_scale[i]
        scaled = np.nan_to_num(scaled, nan=0.0, posinf=20.0, neginf=-20.0)
        scaled = np.clip(scaled, -20.0, 20.0)
        columns.append(scaled)
    return np.vstack(columns).T.astype(np.float32)


def normalize_label(value: Any) -> int:
    if pd.isna(value):
        raise ValueError("label contains missing value")
    if isinstance(value, str):
        normalized = value.strip().lower()
        mapping = {
            "0": 0,
            "1": 1,
            "baseline": 0,
            "no_stress": 0,
            "no stress": 0,
            "low": 0,
            "medium": 1,
            "stress": 1,
            "high": 1,
        }
        if normalized in mapping:
            return mapping[normalized]
    return int(float(value))


def ensure_target(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    if "label" in out.columns:
        out["label"] = out["label"].map(normalize_label).astype(int)
    elif "stress_now_1_5" in out.columns:
        stress = pd.to_numeric(out["stress_now_1_5"], errors="coerce")
        out["label"] = (stress >= 4).astype(int)
        out["target_score"] = ((stress - 1.0) / 4.0 * 100.0).clip(0, 100)
        out["sample_weight"] = np.where(stress == 3, 0.45, 1.0)
    else:
        raise ValueError("CSV must contain either label or stress_now_1_5")

    if "target_score" not in out.columns:
        out["target_score"] = out["label"].astype(float) * 100.0
    return out


def fill_feature_aliases(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for feature, aliases in OLD_FEATURE_ALIASES.items():
        if feature not in out.columns:
            out[feature] = np.nan
        for alias in aliases:
            if alias not in out.columns:
                continue
            mask = out[feature].isna()
            out.loc[mask, feature] = out.loc[mask, alias]

    if "temperature_latest" in out.columns and "temperature_z_30" not in out.columns:
        out["temperature_z_30"] = np.nan
    if "minutes_since_workout" not in out.columns:
        out["minutes_since_workout"] = 9999.0
    if "cardiac_event_present" not in out.columns:
        out["cardiac_event_present"] = 0.0
    if "high_hr_event_present" not in out.columns:
        source = "highHeartRateEvent" if "highHeartRateEvent" in out.columns else None
        out["high_hr_event_present"] = out[source] if source else 0.0
    return out


def rolling_robust_z(values: np.ndarray, window: int, min_periods: int) -> tuple[np.ndarray, np.ndarray]:
    z = np.full(values.shape, np.nan, dtype=float)
    counts = np.zeros(values.shape, dtype=float)
    for i in range(values.size):
        start = max(0, i - window)
        prior = values[start:i]
        prior = prior[np.isfinite(prior)]
        counts[i] = prior.size
        if prior.size < min_periods or not np.isfinite(values[i]):
            continue
        median = float(np.median(prior))
        mad = float(np.median(np.abs(prior - median)))
        spread = 1.4826 * mad
        if spread <= EPS:
            spread = float(np.std(prior))
        if spread <= EPS:
            continue
        z[i] = float(np.clip((values[i] - median) / spread, -5, 5))
    return z, counts


def fill_with_rolling_z(
    df: pd.DataFrame,
    value_col: str,
    z_col: str,
    count_col: str | None,
    window: int,
    min_periods: int,
) -> pd.DataFrame:
    out = df.copy()
    if value_col not in out.columns:
        return out
    if z_col not in out.columns:
        out[z_col] = np.nan
    if count_col and count_col not in out.columns:
        out[count_col] = np.nan

    for _, group in out.groupby("subject_id", sort=False):
        idx = group.sort_values("window_start").index
        values = pd.to_numeric(out.loc[idx, value_col], errors="coerce").to_numpy(dtype=float)
        z, counts = rolling_robust_z(values, window=window, min_periods=min_periods)
        z_mask = out.loc[idx, z_col].isna().to_numpy()
        out.loc[idx[z_mask], z_col] = z[z_mask]
        if count_col:
            count_mask = out.loc[idx, count_col].isna().to_numpy()
            out.loc[idx[count_mask], count_col] = np.clip(counts[count_mask], 0, 7)
    return out


def derive_features(df: pd.DataFrame) -> pd.DataFrame:
    out = fill_feature_aliases(df)
    out = fill_with_rolling_z(out, "hr_mean", "hr_z_14", "hr_baseline_days_14", 21, 3)
    out = fill_with_rolling_z(out, "resting_hr_latest", "resting_hr_z_30", None, 42, 3)
    out = fill_with_rolling_z(out, "hrv_sdnn_latest", "hrv_sdnn_z_30", None, 42, 3)
    out = fill_with_rolling_z(out, "hrv_rmssd_latest", "hrv_rmssd_z_30", None, 42, 3)
    out = fill_with_rolling_z(out, "resp_rate_mean_1h", "resp_rate_z_14", None, 21, 3)
    out = fill_with_rolling_z(out, "temperature_latest", "temperature_z_30", None, 42, 3)

    if "hr_over_rhr" not in out.columns:
        out["hr_over_rhr"] = np.nan
    mask = out["hr_over_rhr"].isna()
    if "hr_mean" in out.columns and "resting_hr_latest" in out.columns:
        denom = pd.to_numeric(out["resting_hr_latest"], errors="coerce")
        out.loc[mask & (denom > 0), "hr_over_rhr"] = (
            pd.to_numeric(out["hr_mean"], errors="coerce") / denom
        )

    if "sleep_hours_latest" not in out.columns and "recent_sleep_score" in out.columns:
        out["sleep_hours_latest"] = np.nan
    if "sleep_hours_delta_7" not in out.columns:
        out["sleep_hours_delta_7"] = np.nan
    if "sleep_efficiency_latest" not in out.columns:
        out["sleep_efficiency_latest"] = np.nan
    if "sleep_efficiency_delta_7" not in out.columns:
        out["sleep_efficiency_delta_7"] = np.nan
    if "sleep_nights_7" not in out.columns:
        out["sleep_nights_7"] = np.where(out.get("recent_sleep_score", pd.Series(np.nan, index=out.index)).notna(), 1, 0)

    for flag, source_cols in MISSING_FLAGS.items():
        if flag not in out.columns:
            out[flag] = np.nan
        source_present = np.zeros(len(out), dtype=bool)
        for source in source_cols:
            if source in out.columns:
                source_present |= pd.to_numeric(out[source], errors="coerce").notna().to_numpy()
        mask = out[flag].isna()
        out.loc[mask, flag] = np.where(source_present[mask.to_numpy()], 0.0, 1.0)

    for feature in FEATURES:
        if feature not in out.columns:
            out[feature] = np.nan if not feature.startswith("missing_") else 1.0

    if "sample_weight" not in out.columns:
        coverage = out["missing_hr"].map(lambda x: 0.0 if x >= 0.5 else 1.0)
        optional = 1.0 - out[
            [
                "missing_hrv_sdnn",
                "missing_resp_rate",
                "missing_temperature",
                "missing_sleep",
                "missing_activity",
            ]
        ].mean(axis=1)
        out["sample_weight"] = (0.45 + 0.35 * coverage + 0.20 * optional).clip(0.2, 1.0)
    else:
        out["sample_weight"] = pd.to_numeric(out["sample_weight"], errors="coerce").fillna(0.5).clip(0.2, 1.0)

    out["sample_weight"] = np.where(out["label"] == 0, out["sample_weight"], out["sample_weight"])
    return out


def ensure_columns(df: pd.DataFrame) -> pd.DataFrame:
    out = ensure_target(df)
    if "subject_id" not in out.columns:
        out["subject_id"] = "unknown"
    if "window_start" not in out.columns:
        out["window_start"] = pd.date_range("2024-01-01", periods=len(out), freq="15min")
    out["subject_id"] = out["subject_id"].astype(str)
    out["window_start"] = pd.to_datetime(out["window_start"], errors="coerce")
    if out["window_start"].isna().any():
        raise ValueError("window_start contains invalid timestamps")
    out = derive_features(out)
    return out.sort_values(["subject_id", "window_start"]).reset_index(drop=True)


def balanced_weights(y: np.ndarray, sample_weight: np.ndarray) -> np.ndarray:
    counts = np.bincount(y.astype(int), minlength=2).astype(float)
    total = float(np.sum(counts))
    class_weight = np.ones(2, dtype=float)
    for label in (0, 1):
        if counts[label] > 0:
            class_weight[label] = total / (2.0 * counts[label])
    return sample_weight * class_weight[y.astype(int)]


def fit_logistic(x: np.ndarray, y: np.ndarray, sample_weight: np.ndarray) -> LogisticRegression:
    model = LogisticRegression(
        C=0.35,
        penalty="l2",
        solver="liblinear",
        max_iter=2000,
        random_state=SEED,
    )
    model.fit(x, y, sample_weight=balanced_weights(y, sample_weight))
    return model


def fit_gbdt(x: np.ndarray, y: np.ndarray, sample_weight: np.ndarray) -> HistGradientBoostingClassifier:
    model = HistGradientBoostingClassifier(
        learning_rate=0.05,
        max_iter=220,
        max_leaf_nodes=16,
        min_samples_leaf=10,
        l2_regularization=0.1,
        random_state=SEED,
    )
    model.fit(x, y, sample_weight=balanced_weights(y, sample_weight))
    return model


def fit_platt(raw_scores: np.ndarray, y: np.ndarray, sample_weight: np.ndarray) -> Calibration:
    if np.unique(y).size < 2:
        return Calibration(method="identity", coefficient=1.0, intercept=0.0)
    calibrator = LogisticRegression(
        C=1000.0,
        penalty="l2",
        solver="liblinear",
        max_iter=1000,
        random_state=SEED,
    )
    calibrator.fit(raw_scores.reshape(-1, 1), y, sample_weight=sample_weight)
    return Calibration(
        method="platt_sigmoid",
        coefficient=float(calibrator.coef_[0][0]),
        intercept=float(calibrator.intercept_[0]),
    )


def apply_calibration(raw_scores: np.ndarray, calibration: Calibration) -> np.ndarray:
    return sigmoid(raw_scores * calibration.coefficient + calibration.intercept)


def expected_calibration_error(y: np.ndarray, probs: np.ndarray, bins: int = 10) -> float:
    edges = np.linspace(0.0, 1.0, bins + 1)
    ece = 0.0
    for left, right in zip(edges[:-1], edges[1:]):
        mask = (probs >= left) & (probs < right if right < 1.0 else probs <= right)
        if not np.any(mask):
            continue
        confidence = float(np.mean(probs[mask]))
        accuracy = float(np.mean(y[mask]))
        ece += float(np.mean(mask)) * abs(accuracy - confidence)
    return float(ece)


def compute_metrics(y: np.ndarray, probs: np.ndarray, target_score: np.ndarray | None = None) -> dict[str, Any]:
    pred = (probs >= 0.5).astype(int)
    metrics: dict[str, Any] = {
        "macro_f1": float(f1_score(y, pred, average="macro", zero_division=0)),
        "balanced_accuracy": float(balanced_accuracy_score(y, pred)),
        "pr_auc": float(average_precision_score(y, probs)),
        "brier": float(brier_score_loss(y, probs)),
        "ece": expected_calibration_error(y, probs),
        "confusion_matrix": confusion_matrix(y, pred).tolist(),
    }
    try:
        metrics["roc_auc"] = float(roc_auc_score(y, probs))
    except ValueError:
        metrics["roc_auc"] = 0.5
    score_target = target_score if target_score is not None else y.astype(float) * 100.0
    metrics["mae_score"] = float(mean_absolute_error(score_target, probs * 100.0))
    return metrics


def summarize(metric_dicts: list[dict[str, Any]]) -> dict[str, float]:
    keys = [k for k in metric_dicts[0] if k != "confusion_matrix"]
    out: dict[str, float] = {}
    for key in keys:
        values = np.array([m[key] for m in metric_dicts], dtype=float)
        out[f"{key}_mean"] = float(np.mean(values))
        out[f"{key}_std"] = float(np.std(values))
    return out


def build_splits(df: pd.DataFrame) -> list[tuple[np.ndarray, np.ndarray, str]]:
    groups = df["subject_id"].to_numpy()
    unique_groups = np.unique(groups)
    indices = np.arange(len(df))
    if unique_groups.size >= 2:
        logo = LeaveOneGroupOut()
        return [
            (train_idx, test_idx, str(df.iloc[test_idx]["subject_id"].iloc[0]))
            for train_idx, test_idx in logo.split(indices, df["label"], groups)
        ]

    ordered = df.sort_values("window_start").index.to_numpy()
    cut = max(1, int(len(ordered) * 0.8))
    return [(ordered[:cut], ordered[cut:], "temporal_holdout")]


def train_validate(df: pd.DataFrame) -> tuple[dict[str, Any], Calibration]:
    y_all = df["label"].to_numpy(dtype=int)
    target_score_all = pd.to_numeric(df["target_score"], errors="coerce").fillna(
        pd.Series(y_all * 100, index=df.index)
    ).to_numpy(dtype=float)
    sample_weight_all = df["sample_weight"].to_numpy(dtype=float)

    fold_reports: list[FoldReport] = []
    logistic_metrics: list[dict[str, Any]] = []
    gbdt_metrics: list[dict[str, Any]] = []
    oof_logistic_raw = np.full(len(df), np.nan, dtype=float)
    oof_logistic_probs_raw = np.full(len(df), np.nan, dtype=float)

    for fold, (train_idx, test_idx, held_out_subject) in enumerate(build_splits(df), start=1):
        train_df = df.iloc[train_idx].copy()
        test_df = df.iloc[test_idx].copy()
        if test_df.empty:
            continue

        preprocessor = fit_preprocessor(train_df)
        x_train = transform(train_df, preprocessor)
        x_test = transform(test_df, preprocessor)
        y_train = train_df["label"].to_numpy(dtype=int)
        y_test = test_df["label"].to_numpy(dtype=int)
        w_train = train_df["sample_weight"].to_numpy(dtype=float)
        target_score = pd.to_numeric(test_df["target_score"], errors="coerce").fillna(
            pd.Series(y_test * 100, index=test_df.index)
        ).to_numpy(dtype=float)

        logistic = fit_logistic(x_train, y_train, w_train)
        logistic_raw = logistic.decision_function(x_test)
        logistic_probs = sigmoid(logistic_raw)

        gbdt = fit_gbdt(x_train, y_train, w_train)
        gbdt_probs = gbdt.predict_proba(x_test)[:, 1]

        l_metrics = compute_metrics(y_test, logistic_probs, target_score)
        g_metrics = compute_metrics(y_test, gbdt_probs, target_score)
        logistic_metrics.append(l_metrics)
        gbdt_metrics.append(g_metrics)
        oof_logistic_raw[test_idx] = logistic_raw
        oof_logistic_probs_raw[test_idx] = logistic_probs

        fold_reports.append(
            FoldReport(
                fold=fold,
                held_out_subject=held_out_subject,
                n_train=int(len(train_df)),
                n_test=int(len(test_df)),
                logistic_roc_auc=l_metrics["roc_auc"],
                logistic_pr_auc=l_metrics["pr_auc"],
                logistic_macro_f1=l_metrics["macro_f1"],
                logistic_balanced_accuracy=l_metrics["balanced_accuracy"],
                logistic_brier=l_metrics["brier"],
                logistic_mae_score=l_metrics["mae_score"],
                gbdt_roc_auc=g_metrics["roc_auc"],
                gbdt_pr_auc=g_metrics["pr_auc"],
                gbdt_macro_f1=g_metrics["macro_f1"],
                gbdt_balanced_accuracy=g_metrics["balanced_accuracy"],
            )
        )

    valid_oof = np.isfinite(oof_logistic_raw)
    calibration = fit_platt(
        oof_logistic_raw[valid_oof],
        y_all[valid_oof],
        sample_weight_all[valid_oof],
    )
    calibrated_probs = apply_calibration(oof_logistic_raw[valid_oof], calibration)
    calibrated_oof_metrics = compute_metrics(
        y_all[valid_oof],
        calibrated_probs,
        target_score_all[valid_oof],
    )

    report = {
        "validation_protocol": "subject-wise LeaveOneGroupOut" if df["subject_id"].nunique() >= 2 else "single-subject temporal holdout",
        "folds": [asdict(item) for item in fold_reports],
        "logistic_oof_summary": summarize(logistic_metrics),
        "gbdt_oof_summary": summarize(gbdt_metrics),
        "logistic_oof_calibrated": calibrated_oof_metrics,
        "calibration": asdict(calibration),
    }
    return report, calibration


def train_final_logistic(df: pd.DataFrame) -> tuple[Preprocessor, LogisticRegression]:
    preprocessor = fit_preprocessor(df)
    x = transform(df, preprocessor)
    y = df["label"].to_numpy(dtype=int)
    sample_weight = df["sample_weight"].to_numpy(dtype=float)
    return preprocessor, fit_logistic(x, y, sample_weight)


def export_scorecard(
    out_path: Path,
    model_id: str,
    preprocessor: Preprocessor,
    logistic: LogisticRegression,
    calibration: Calibration,
    report: dict[str, Any],
) -> None:
    payload = {
        "model_id": model_id,
        "model_version": "stress-scorecard-v1",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "task_type": "binary_stress_classification",
        "output": {
            "stress_score": "calibrated_probability_stress_times_100",
            "status_thresholds": {
                "stable_max_exclusive": 40,
                "attention_max_exclusive": 70,
                "risk_min": 70,
            },
        },
        "feature_contract_version": "stress-health-contract-v2",
        "feature_names": preprocessor.feature_names,
        "preprocessing": {
            "imputer_strategy": "train_median",
            "imputer_statistics": preprocessor.imputer_statistics,
            "scaler": "robust_iqr",
            "center": preprocessor.robust_center,
            "scale": preprocessor.robust_scale,
        },
        "model": {
            "type": "logistic_regression",
            "intercept": float(logistic.intercept_[0]),
            "coefficients": [float(v) for v in logistic.coef_[0]],
        },
        "calibration": asdict(calibration),
        "reason_feature_groups": REASON_FEATURES,
        "training_summary": {
            "validation_protocol": report["validation_protocol"],
            "logistic_oof_calibrated": {
                key: value
                for key, value in report["logistic_oof_calibrated"].items()
                if key != "confusion_matrix"
            },
        },
        "safety_notes": [
            "This model estimates stress-related load, not a medical diagnosis.",
            "Use runtime quality gates and fallback when heart-rate data or personal baseline is insufficient.",
            "Domain shift must be checked on Apple Watch / HealthKit EMA data before clinical or high-stakes use.",
        ],
    }
    _write_json(out_path, payload)


def export_feature_contract(out_path: Path) -> None:
    payload = {
        "contract_id": "stress-health-contract-v2",
        "window_minutes": 15,
        "runtime_windows_minutes": [5, 15, 60, 1440],
        "baseline_windows_days": [7, 14, 30],
        "required_runtime_groups": ["heart_rate", "personal_baseline"],
        "optional_runtime_groups": ["hrv", "respiratory", "sleep", "activity", "temperature", "spo2"],
        "feature_names": FEATURES,
        "runtime_extra_feature_names": RUNTIME_EXTRA_FEATURES,
        "missing_flags": [name for name in FEATURES if name.startswith("missing_")],
        "quality_gate": {
            "min_model_quality": 0.45,
            "block_if_missing": ["missing_hr"],
            "fallback_if_recent_workout_minutes_lt": 45,
            "fallback_if_baseline_days_lt": 3,
        },
    }
    _write_json(out_path, payload)


def export_parity_fixture(
    out_path: Path,
    df: pd.DataFrame,
    preprocessor: Preprocessor,
    logistic: LogisticRegression,
    calibration: Calibration,
) -> None:
    row = df.iloc[0:1]
    x = transform(row, preprocessor)
    raw_logit = float(logistic.decision_function(x)[0])
    probability = float(apply_calibration(np.array([raw_logit]), calibration)[0])
    payload = {
        "raw_features": {
            feature: None if pd.isna(row.iloc[0][feature]) else float(row.iloc[0][feature])
            for feature in FEATURES
        },
        "transformed": [float(v) for v in x[0]],
        "raw_logit": raw_logit,
        "stress_probability": probability,
        "stress_score": probability * 100.0,
    }
    _write_json(out_path, payload)


def export_artifacts(
    df: pd.DataFrame,
    out_dir: Path,
    model_id: str,
    *,
    input_csv: Path,
    dataset_source: str,
    dataset_uri: str,
    dataset_version: str,
    training_pipeline_version: str,
) -> None:
    if df["label"].nunique() < 2:
        raise ValueError("Training data must contain both stress and non-stress labels")

    report, calibration = train_validate(df)
    preprocessor, logistic = train_final_logistic(df)

    out_dir.mkdir(parents=True, exist_ok=True)
    export_scorecard(out_dir / "scorecard_v1.json", model_id, preprocessor, logistic, calibration, report)
    export_feature_contract(out_dir / "feature_contract_stress_v2.json")
    export_parity_fixture(out_dir / "parity_fixture.json", df, preprocessor, logistic, calibration)

    split_manifest = {
        "protocol": report["validation_protocol"],
        "folds": [
            {
                "fold": fold["fold"],
                "held_out_subject": fold["held_out_subject"],
                "n_train": fold["n_train"],
                "n_test": fold["n_test"],
            }
            for fold in report["folds"]
        ],
    }
    _write_json(out_dir / "split_manifest.json", split_manifest)

    training_report = {
        **report,
        "model_id": model_id,
        "selected_production_model": "logistic_scorecard_json",
        "benchmark_model": "hist_gradient_boosting_classifier",
        "n_rows": int(len(df)),
        "n_subjects": int(df["subject_id"].nunique()),
        "class_balance": {
            str(k): float(v)
            for k, v in df["label"].value_counts(normalize=True).sort_index().to_dict().items()
        },
        "missingness": {
            feature: float(pd.to_numeric(df[feature], errors="coerce").isna().mean())
            for feature in FEATURES
            if not feature.startswith("missing_")
        },
    }
    _write_json(out_dir / "training_report.json", training_report)
    generated_at_utc = datetime.now(timezone.utc).isoformat()
    model_metadata = {
        "model_id": model_id,
        "model_version": "stress-scorecard-v1",
        "created_at_utc": generated_at_utc,
        "generated_at_utc": generated_at_utc,
        "training_pipeline_version": training_pipeline_version,
        "dataset_source": dataset_source,
        "dataset_uri": dataset_uri,
        "dataset_sha256": _sha256_file(input_csv),
        "dataset_version": dataset_version,
        "selected_production_model": "logistic_scorecard_json",
        "feature_contract_version": "stress-health-contract-v2",
        "validation_protocol": report["validation_protocol"],
        "metrics": {
            key: value
            for key, value in report["logistic_oof_calibrated"].items()
            if key != "confusion_matrix"
        },
        "n_rows": int(len(df)),
        "n_subjects": int(df["subject_id"].nunique()),
    }
    _write_json(out_dir / "model_metadata.json", model_metadata)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_csv", required=True)
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--model_id", default="stress-score-v1")
    parser.add_argument(
        "--dataset-source",
        default=DEFAULT_DATASET_SOURCE,
        help="Logical dataset identifier for model metadata.",
    )
    parser.add_argument(
        "--dataset-uri",
        default=DEFAULT_DATASET_URI,
        help="Dataset URI for model metadata (URL, DOI, or local URI).",
    )
    parser.add_argument(
        "--dataset-version",
        default=DEFAULT_DATASET_VERSION,
        help="Dataset version string for model metadata.",
    )
    parser.add_argument(
        "--training-pipeline-version",
        default=TRAINING_PIPELINE_VERSION,
        help="Version label of the training pipeline implementation.",
    )
    args = parser.parse_args()

    set_seed()
    input_csv = Path(args.input_csv).expanduser().resolve()
    df = pd.read_csv(input_csv)
    df = ensure_columns(df)
    export_artifacts(
        df,
        Path(args.output_dir).expanduser().resolve(),
        args.model_id,
        input_csv=input_csv,
        dataset_source=str(args.dataset_source).strip() or DEFAULT_DATASET_SOURCE,
        dataset_uri=str(args.dataset_uri).strip() or DEFAULT_DATASET_URI,
        dataset_version=str(args.dataset_version).strip() or DEFAULT_DATASET_VERSION,
        training_pipeline_version=str(args.training_pipeline_version).strip()
        or TRAINING_PIPELINE_VERSION,
    )
    print(f"Stress artifacts exported to {args.output_dir}")


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


_WINDOWS_DRIVE_RE = re.compile(r"^[A-Za-z]:[\\/]")


def _assert_no_absolute_paths(payload: Any, context: str) -> None:
    _walk_and_validate(payload, field_path=context)


def _walk_and_validate(value: Any, field_path: str) -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            _walk_and_validate(item, field_path=f"{field_path}.{key}")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _walk_and_validate(item, field_path=f"{field_path}[{index}]")
        return
    if isinstance(value, str) and _looks_like_absolute_path(value):
        raise ValueError(
            f"Absolute path is not allowed in serialized artifacts at "
            f"{field_path}: {value}"
        )


def _looks_like_absolute_path(raw_value: str) -> bool:
    value = raw_value.strip()
    if not value:
        return False
    if "://" in value:
        return False
    if value.startswith("/"):
        return True
    if value.startswith("\\\\"):
        return True
    return bool(_WINDOWS_DRIVE_RE.match(value))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    _assert_no_absolute_paths(payload, context=str(path))
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
