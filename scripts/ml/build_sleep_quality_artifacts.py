#!/usr/bin/env python3
"""Build sleep quality model artifacts for Flutter ONNX inference.

Preferred data source:
  1) In-situ wearable HRV + sleep diaries (Figshare article 28509740)
Fallback:
  2) Sleep-accel (PhysioNet Apple Watch dataset)

Outputs:
  - assets/models/sleep_quality/model_sleep_quality.onnx
  - assets/models/sleep_quality/preprocessor_v2.json
  - assets/models/sleep_quality/feature_contract_health_v2.json
  - assets/models/sleep_quality/model_metadata.json
  - build/ml/sleep_quality/training_report.json
  - build/ml/sleep_quality/split_manifest.json
  - build/ml/sleep_quality/models/model_<selected>.joblib
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import warnings
from dataclasses import dataclass
from datetime import datetime, time, timedelta
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import joblib
import numpy as np
import onnx
import onnxmltools
import pandas as pd
import requests
import xgboost as xgb
from onnx import TensorProto, helper, numpy_helper
from onnxmltools.convert.common.data_types import FloatTensorType as OnnxFloatTensorType
from sklearn.linear_model import HuberRegressor
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import GroupShuffleSplit, train_test_split
from sklearn.neural_network import MLPRegressor
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType as SkFloatTensorType
from sleep_external_adapters import ExternalPretrainBundle, load_external_pretrain_bundle


FIGSHARE_ARTICLE_ID = "28509740"
FIGSHARE_API_URL = f"https://api.figshare.com/v2/articles/{FIGSHARE_ARTICLE_ID}"
INSITU_DEFAULT_HRV_FILE = "sensor_hrv_filtered.csv"
INSITU_SUPPORTED_HRV_FILES = (
    "sensor_hrv_filtered.csv",
    "sensor_hrv.csv",
)
INSITU_REQUIRED_SHARED_FILES = (
    "sleep_diary.csv",
    "survey.csv",
)

SLEEP_ACCEL_BASE = "https://physionet.org/files/sleep-accel/1.0.0"
SLEEP_ACCEL_DIRS = ("heart_rate", "labels", "steps")

MODEL_VERSION = "sleep-quality-v3"
PREPROCESSOR_VERSION = "preprocessor_v2"
HEALTH_CONTRACT_VERSION = "sleep-health-contract-v2"
INPUT_NAME = "float_input"
SEED = 42
MIN_SEGMENT_ROWS = 8
DEFAULT_CLIP_QUANTILE_LOW = 0.01
DEFAULT_CLIP_QUANTILE_HIGH = 0.99
LOW_ALIGNMENT_QUALITY_REFERENCE = 0.35
LOW_SCORE_THRESHOLD = 70.0
COMPONENT_WEIGHTS = np.array([0.50, 0.20, 0.30], dtype=np.float32)
DEFAULT_EXTERNAL_PRETRAIN_OBJECTIVE = "masked_reconstruction_modality_heads"
FINAL_REFIT_VALIDATION_RATIO = 0.15
STUDENT_PLATFORM_VALIDATION_WEIGHT = 0.20
STUDENT_SELECTION_TIE_TOLERANCE = 0.015
STUDENT_PLATFORM_PROFILES = {
    "ios": ("rmssd",),
    "android": ("sdnn",),
}

# Features that can be built from package:health wearable data in app runtime.
# This contract intentionally excludes diary_* and survey_* fields.
HEALTH_CONTRACT_FEATURES = (
    "HR_mean",
    "HR_std",
    "HR_min",
    "HR_max",
    "HR_p10",
    "HR_p90",
    "steps_mean",
    "steps_std",
    "steps_min",
    "steps_max",
    "steps_p10",
    "steps_p90",
    "distance_mean",
    "distance_std",
    "distance_min",
    "distance_max",
    "distance_p10",
    "distance_p90",
    "calories_mean",
    "calories_std",
    "calories_min",
    "calories_max",
    "calories_p10",
    "calories_p90",
    "sdnn_mean",
    "sdnn_std",
    "sdnn_min",
    "sdnn_max",
    "sdnn_p10",
    "sdnn_p90",
    "rmssd_mean",
    "rmssd_std",
    "rmssd_min",
    "rmssd_max",
    "rmssd_p10",
    "rmssd_p90",
    "window_count",
    "coverage_hours",
    "window_density",
    "asleep_hour",
    "wakeup_hour",
    "weekday",
    "sleep_window_hours_clock",
    "hr_trend",
    "HR_mean_baseline7",
    "HR_mean_delta7",
    "HR_mean_z7",
    "rmssd_mean_baseline7",
    "rmssd_mean_delta7",
    "rmssd_mean_z7",
    "sdnn_mean_baseline7",
    "sdnn_mean_delta7",
    "sdnn_mean_z7",
    "steps_mean_baseline7",
    "steps_mean_delta7",
    "steps_mean_z7",
    "distance_mean_baseline7",
    "distance_mean_delta7",
    "distance_mean_z7",
    "calories_mean_baseline7",
    "calories_mean_delta7",
    "calories_mean_z7",
    "window_count_baseline7",
    "window_count_delta7",
    "window_count_z7",
    "coverage_hours_baseline7",
    "coverage_hours_delta7",
    "coverage_hours_z7",
    "asleep_hour_baseline7",
    "asleep_hour_delta7",
    "asleep_hour_z7",
    "wakeup_hour_baseline7",
    "wakeup_hour_delta7",
    "wakeup_hour_z7",
    "nights_since_start",
    "asleep_hour_sin",
    "asleep_hour_cos",
    "wakeup_hour_sin",
    "wakeup_hour_cos",
    "weekday_sin",
    "weekday_cos",
    "coverage_hours_log1p",
    "window_count_log1p",
    "sleep_window_hours_log1p",
    "hr_rmssd_interaction",
    "hr_sdnn_interaction",
    "steps_coverage_interaction",
    "sleep_phase_span_abs",
    "sleep_phase_span_wrap",
    "hr_missing",
    "steps_missing",
    "distance_missing",
    "calories_missing",
    "sdnn_missing",
    "rmssd_missing",
)

HEALTH_CONTRACT_REQUIREMENTS = {
    "minimum_history_days": 14,
    "minimum_nights_for_baseline": 7,
    "minimum_sleep_nights_for_inference": 5,
    "required_health_metric_types_any_platform": [
        "sleepAsleep",
        "heartRate",
        "steps",
    ],
    "optional_health_metric_types": [
        "sleepInBed",
        "sleepAwake",
        "sleepDeep",
        "sleepRem",
        "restingHeartRate",
        "heartRateVariabilitySdnn",
        "heartRateVariabilityRmssd",
        "activeEnergyBurned",
        "totalCaloriesBurned",
        "distanceWalkingRunning",
        "distanceDelta",
    ],
}

warnings.filterwarnings(
    "ignore",
    message=".*encountered in matmul.*",
    category=RuntimeWarning,
)


@dataclass
class BuildConfig:
    source: str
    dataset_dir: Path
    output_dir: Path
    report_dir: Path
    allow_download: bool
    split_mode: str
    feature_mode: str
    objective: str
    selection_policy: str
    quality_gate_ratio: float
    in_situ_hrv_file: str
    in_situ_missingness_threshold: Optional[float]
    in_situ_missingness_aggregation: str
    enable_external_pretrain: bool
    external_pretrain_sources: Tuple[str, ...]
    external_pretrain_objective: str


@dataclass
class DatasetBundle:
    source: str
    features: pd.DataFrame
    target: np.ndarray
    groups: np.ndarray
    rows: int
    metadata: Dict[str, object]
    sample_dates: Optional[np.ndarray]
    component_targets: Optional[Dict[str, np.ndarray]]
    sample_weights: np.ndarray
    row_quality: np.ndarray


@dataclass
class ValidationFold:
    name: str
    train_idx: np.ndarray
    val_idx: np.ndarray


@dataclass
class SplitPlan:
    strategy: str
    trainval_idx: np.ndarray
    test_idx: np.ndarray
    validation_folds: List[ValidationFold]
    manifest: Dict[str, object]


def main() -> None:
    args = _parse_args()
    config = BuildConfig(
        source=args.source,
        dataset_dir=Path(args.dataset_dir).resolve(),
        output_dir=Path(args.output_dir).resolve(),
        report_dir=Path(args.report_dir).resolve(),
        allow_download=not args.no_download,
        split_mode=args.split_mode,
        feature_mode=args.feature_mode,
        objective=args.objective,
        selection_policy=args.selection_policy,
        quality_gate_ratio=float(args.quality_gate_ratio),
        in_situ_hrv_file=str(args.in_situ_hrv_file),
        in_situ_missingness_threshold=None
        if args.in_situ_missingness_threshold is None
        else float(args.in_situ_missingness_threshold),
        in_situ_missingness_aggregation=str(args.in_situ_missingness_aggregation),
        enable_external_pretrain=bool(args.enable_external_pretrain),
        external_pretrain_sources=tuple(
            source.strip().lower()
            for source in str(args.external_pretrain_sources).split(",")
            if source.strip()
        ),
        external_pretrain_objective=str(args.external_pretrain_objective).strip().lower(),
    )
    if config.in_situ_missingness_threshold is not None and config.in_situ_missingness_threshold < 0:
        raise ValueError("--in-situ-missingness-threshold must be >= 0.")

    config.output_dir.mkdir(parents=True, exist_ok=True)
    config.report_dir.mkdir(parents=True, exist_ok=True)

    bundle = _load_dataset(config)
    if bundle.rows < 20:
        raise RuntimeError(
            f"Too few samples after preprocessing: {bundle.rows}. "
            "Need at least 20 rows to train a stable model."
        )
    if not bundle.component_targets:
        raise RuntimeError("Sleep student model requires component targets.")

    external_pretrain_bundle: Optional[ExternalPretrainBundle] = None
    external_pretraining_info = _default_external_pretraining_info(config)
    if config.enable_external_pretrain:
        external_pretrain_bundle = load_external_pretrain_bundle(
            dataset_dir=config.dataset_dir,
            sources=config.external_pretrain_sources,
            allow_download=config.allow_download,
            health_contract_features=HEALTH_CONTRACT_FEATURES,
        )
        external_pretraining_info.update(external_pretrain_bundle.metadata)
        external_pretraining_info["loaded_rows"] = int(len(external_pretrain_bundle.features))
        external_pretraining_info["loaded_groups"] = int(len(np.unique(external_pretrain_bundle.groups)))
        external_pretraining_info["objective"] = config.external_pretrain_objective

    feature_variants = _build_feature_variants(bundle.features, config.feature_mode)
    variant_reports: Dict[str, Dict[str, object]] = {}
    for variant_name, variant_df in feature_variants.items():
        variant_reports[variant_name] = _train_single_target_variant(
            features_df=variant_df,
            target=bundle.target,
            component_targets=bundle.component_targets,
            groups=bundle.groups,
            sample_dates=bundle.sample_dates,
            sample_weights=bundle.sample_weights,
            split_mode=config.split_mode,
            selection_policy=config.selection_policy,
            quality_gate_ratio=config.quality_gate_ratio,
            external_pretrain_bundle=external_pretrain_bundle,
            external_pretraining_info=external_pretraining_info,
            external_pretrain_objective=config.external_pretrain_objective,
        )

    if config.feature_mode == "both":
        selected_variant = min(
            variant_reports.keys(),
            key=lambda name: variant_reports[name]["selected_validation_mae"],
        )
    else:
        selected_variant = next(iter(variant_reports.keys()))

    selected_report = variant_reports[selected_variant]
    selected_model_name = selected_report["selected_model_name"]
    selected_model = selected_report["selected_model"]
    feature_names = selected_report["feature_names"]
    preprocessor = selected_report["preprocessor"]
    split_manifest = selected_report["split_manifest"]
    feature_missingness = selected_report["feature_missingness"]
    target_distribution = selected_report["target_distribution"]
    gate = selected_report["promotion_gate"]

    if config.selection_policy == "nn_only" and not gate["passed"]:
        raise RuntimeError(
            "Quality gate failed for NN-only policy: "
            f"student validation MAE={gate['student_validation_mae']:.4f} exceeds "
            f"allowed={gate['allowed_validation_mae']:.4f} relative to teacher "
            f"validation MAE={gate['teacher_validation_mae']:.4f}."
        )

    build_model_dir = config.report_dir / "models"
    build_model_dir.mkdir(parents=True, exist_ok=True)
    model_dump_path = build_model_dir / f"model_{selected_variant}_{selected_model_name}.joblib"
    joblib.dump(selected_model, model_dump_path)

    model_path = config.output_dir / "model_sleep_quality.onnx"
    _export_onnx(
        model_name=selected_model_name,
        model=selected_model,
        feature_count=len(feature_names),
        output_path=model_path,
    )

    preprocessor_payload = {
        "version": PREPROCESSOR_VERSION,
        "feature_names": feature_names,
        "median": preprocessor["medians"],
        "clip_low": preprocessor["clip_low"],
        "clip_high": preprocessor["clip_high"],
        "mean": preprocessor["mean"],
        "std": preprocessor["std"],
        "feature_mode": config.feature_mode,
        "objective": config.objective,
        "health_contract_version": HEALTH_CONTRACT_VERSION,
        "student_component_scaling": selected_report["student_component_scaling"],
        "aggregation_weights": COMPONENT_WEIGHTS.tolist(),
    }
    preprocessor_path = config.output_dir / "preprocessor_v2.json"
    _write_json(preprocessor_path, preprocessor_payload)

    contract_payload = {
        "contract_version": HEALTH_CONTRACT_VERSION,
        "feature_names": feature_names,
        "requirements": HEALTH_CONTRACT_REQUIREMENTS,
        "dataset_coverage": _build_health_contract_report(
            dataset_columns=bundle.features.columns,
            selected_feature_names=feature_names,
        ),
        "missingness_features": [
            name for name in feature_names if name.endswith("_missing")
        ],
    }
    contract_path = config.output_dir / "feature_contract_health_v2.json"
    _write_json(contract_path, contract_payload)

    split_manifest_path = config.report_dir / "split_manifest.json"
    _write_json(split_manifest_path, split_manifest)

    parity_fixture = _build_parity_fixture(
        feature_names=feature_names,
        features_df=feature_variants[selected_variant],
        preprocessor=preprocessor,
        selected_model_name=selected_model_name,
        selected_model=selected_model,
        source_rows=selected_report["test_idx"],
    )
    parity_fixture_path = config.report_dir / "parity_fixture_v2.json"
    _write_json(parity_fixture_path, parity_fixture)

    artifact_hashes = {
        "model_sleep_quality.onnx": _sha256_file(model_path),
        "preprocessor_v2.json": _sha256_file(preprocessor_path),
        "feature_contract_health_v2.json": _sha256_file(contract_path),
        "split_manifest.json": _sha256_file(split_manifest_path),
        "parity_fixture_v2.json": _sha256_file(parity_fixture_path),
        "model_dump.joblib": _sha256_file(model_dump_path),
    }

    metadata = {
        "model_version": MODEL_VERSION,
        "selected_model": selected_model_name,
        "input_name": INPUT_NAME,
        "source_dataset": bundle.source,
        "dataset_info": bundle.metadata,
        "rows_total": bundle.rows,
        "rows_train_pool": int(len(selected_report["trainval_idx"])),
        "rows_test": int(len(selected_report["test_idx"])),
        "groups_total": int(len(np.unique(bundle.groups))),
        "groups_train_pool": int(len(np.unique(bundle.groups[selected_report["trainval_idx"]]))),
        "groups_test": int(len(np.unique(bundle.groups[selected_report["test_idx"]]))),
        "split_mode": config.split_mode,
        "feature_mode": config.feature_mode,
        "selected_feature_variant": selected_variant,
        "objective": config.objective,
        "selection_policy": config.selection_policy,
        "quality_gate_ratio": config.quality_gate_ratio,
        "features_count": len(feature_names),
        "feature_names": feature_names,
        "feature_missingness": feature_missingness,
        "target_distribution": target_distribution,
        "validation_protocol": selected_report["validation_protocol"],
        "teacher_metrics": selected_report["teacher_metrics"],
        "student_metrics": selected_report["student_metrics"],
        "student_selection": selected_report.get("student_selection"),
        "frozen_test_summary": selected_report["frozen_test_summary"],
        "platform_profile_diagnostics": selected_report.get("platform_profile_diagnostics"),
        "promotion_gate": gate,
        "secondary_unseen_user_report": selected_report["secondary_unseen_user_report"],
        "artifact_hashes": artifact_hashes,
        "mlp_output_scaling": {"mean": 0.0, "std": 1.0},
        "feature_contract": contract_payload,
        "target_definition": "Sleep quality score in [0, 100], composed from diary-derived sleep efficiency, duration adequacy, WASO and night awakenings, with sleep latency downweighted to improve transfer to package:health signals.",
        "student_architecture": selected_report["student_architecture"],
        "student_final_fit": selected_report.get("student_final_fit"),
        "training_notes": {
            "teacher_student_distillation": True,
            "student_platform_profile_augmentation": True,
            "student_overall_residual_head": True,
            "student_seed_selection": "family_mean_then_near_best_r2_seed",
            "target_sleep_latency_downweighted": True,
            "train_test_leakage_removed": True,
            "test_used_for_model_selection": False,
        },
    }
    if "external_pretraining" in selected_report:
        metadata["external_pretraining"] = selected_report["external_pretraining"]

    metadata_path = config.output_dir / "model_metadata.json"
    training_report_path = config.report_dir / "training_report.json"
    _write_json(metadata_path, metadata)
    _write_json(training_report_path, metadata)

    print("Sleep quality artifacts created:")
    print(f" - {model_path}")
    print(f" - {preprocessor_path}")
    print(f" - {contract_path}")
    print(f" - {metadata_path}")
    print(f" - {training_report_path}")
    print(f" - {split_manifest_path}")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        default="auto",
        choices=("auto", "in_situ", "sleep_accel"),
        help="Preferred data source.",
    )
    parser.add_argument(
        "--dataset-dir",
        default="build/ml/datasets/sleep_quality",
        help="Directory for raw downloaded datasets.",
    )
    parser.add_argument(
        "--output-dir",
        default="assets/models/sleep_quality",
        help="Directory for ONNX and preprocessing artifacts.",
    )
    parser.add_argument(
        "--report-dir",
        default="build/ml/sleep_quality",
        help="Directory for training reports and local model dumps.",
    )
    parser.add_argument(
        "--no-download",
        action="store_true",
        help="Fail instead of downloading missing datasets.",
    )
    parser.add_argument(
        "--split-mode",
        default="temporal_per_user",
        choices=("temporal_per_user", "group_holdout"),
        help="Evaluation split: personalized temporal or unseen-user holdout.",
    )
    parser.add_argument(
        "--feature-mode",
        default="health_contract",
        choices=("health_contract", "both"),
        help="Feature projection mode.",
    )
    parser.add_argument(
        "--objective",
        default="multi_target",
        choices=("single_score", "multi_target"),
        help="Training objective. multi_target is recommended for production.",
    )
    parser.add_argument(
        "--selection-policy",
        default="nn_only",
        choices=("nn_only", "best_mae"),
        help="Export the compact student only, or whichever validation MAE is best.",
    )
    parser.add_argument(
        "--quality-gate-ratio",
        default=0.10,
        type=float,
        help="Allowed student MAE slack relative to the teacher validation MAE.",
    )
    parser.add_argument(
        "--in-situ-hrv-file",
        default=INSITU_DEFAULT_HRV_FILE,
        choices=INSITU_SUPPORTED_HRV_FILES,
        help="Which Figshare HRV table to use for in-situ training.",
    )
    parser.add_argument(
        "--in-situ-missingness-threshold",
        default=None,
        type=float,
        help=(
            "Optional night-level missingness_score threshold. "
            "If omitted, extra missingness filtering is disabled and row quality is handled by sample weights."
        ),
    )
    parser.add_argument(
        "--in-situ-missingness-aggregation",
        default="median",
        choices=("mean", "median"),
        help="How to aggregate segment missingness_score into a night-level quality metric.",
    )
    parser.add_argument(
        "--enable-external-pretrain",
        action="store_true",
        help="Enable optional self-supervised pretraining on external wearable datasets.",
    )
    parser.add_argument(
        "--external-pretrain-sources",
        default="sleep_accel,mmash",
        help="Comma-separated external sources for pretraining (sleep_accel,mmash).",
    )
    parser.add_argument(
        "--external-pretrain-objective",
        default=DEFAULT_EXTERNAL_PRETRAIN_OBJECTIVE,
        choices=(DEFAULT_EXTERNAL_PRETRAIN_OBJECTIVE,),
        help="Self-supervised pretraining objective.",
    )
    return parser.parse_args()


def _load_dataset(config: BuildConfig) -> DatasetBundle:
    source = config.source
    if source == "auto":
        try:
            return _load_in_situ(config)
        except Exception as primary_error:
            print(f"Primary dataset unavailable ({primary_error}), trying sleep-accel fallback...")
            return _load_sleep_accel(config.dataset_dir, allow_download=config.allow_download)
    if source == "in_situ":
        return _load_in_situ(config)
    return _load_sleep_accel(config.dataset_dir, allow_download=config.allow_download)


def _build_feature_variants(
    features_df: pd.DataFrame,
    feature_mode: str,
) -> Dict[str, pd.DataFrame]:
    if feature_mode == "health_contract":
        return {"health_contract": _project_health_contract(features_df)}
    if feature_mode == "both":
        return {"health_contract": _project_health_contract(features_df)}
    raise ValueError(f"Unsupported feature_mode={feature_mode}")


def _project_health_contract(features: pd.DataFrame) -> pd.DataFrame:
    projected = pd.DataFrame(index=features.index)
    for name in HEALTH_CONTRACT_FEATURES:
        projected[name] = features[name] if name in features.columns else np.nan
    return projected


def _build_health_contract_report(
    dataset_columns: Iterable[str],
    selected_feature_names: Sequence[str],
) -> Dict[str, object]:
    dataset_cols = set(dataset_columns)
    required = list(HEALTH_CONTRACT_FEATURES)
    available = [name for name in required if name in dataset_cols]
    missing = [name for name in required if name not in dataset_cols]
    selected_missing = [name for name in selected_feature_names if name in missing]

    return {
        "required_features_total": len(required),
        "required_features_available": len(available),
        "required_features_missing": len(missing),
        "required_feature_coverage_ratio": round(len(available) / max(len(required), 1), 4),
        "missing_feature_names": missing,
        "selected_variant_missing_feature_names": selected_missing,
    }


def _default_external_pretraining_info(config: BuildConfig) -> Dict[str, object]:
    return {
        "enabled": bool(config.enable_external_pretrain),
        "objective": config.external_pretrain_objective,
        "requested_sources": list(config.external_pretrain_sources),
        "loaded_sources": [],
        "skipped_sources": {},
        "rows_by_source": {},
        "groups_by_source": {},
        "loaded_rows": 0,
        "loaded_groups": 0,
    }


def _train_single_target_variant(
    features_df: pd.DataFrame,
    target: np.ndarray,
    component_targets: Dict[str, np.ndarray],
    groups: np.ndarray,
    sample_dates: Optional[np.ndarray],
    sample_weights: np.ndarray,
    split_mode: str,
    selection_policy: str,
    quality_gate_ratio: float,
    external_pretrain_bundle: Optional[ExternalPretrainBundle],
    external_pretraining_info: Dict[str, object],
    external_pretrain_objective: str,
) -> Dict[str, object]:
    split_plan = _build_split_plan(
        n_rows=len(target),
        groups=groups,
        sample_dates=sample_dates,
        split_mode=split_mode,
    )
    if len(split_plan.test_idx) == 0:
        raise RuntimeError("Failed to build a non-empty frozen test split.")
    if not split_plan.validation_folds:
        raise RuntimeError("Failed to build validation folds for honest model selection.")

    feature_names = features_df.columns.tolist()
    teacher_tuning = _tune_teacher_models(
        features_df=features_df,
        target=target,
        groups=groups,
        sample_weights=sample_weights,
        folds=split_plan.validation_folds,
    )
    student_tuning = _tune_student_models(
        features_df=features_df,
        target=target,
        component_targets=component_targets,
        groups=groups,
        sample_weights=sample_weights,
        folds=split_plan.validation_folds,
        teacher_spec=teacher_tuning["best_spec"],
        external_pretrain_bundle=external_pretrain_bundle,
        external_pretrain_objective=external_pretrain_objective,
    )

    trainval_idx = split_plan.trainval_idx
    test_idx = split_plan.test_idx
    x_trainval_raw = features_df.to_numpy(dtype=np.float64)[trainval_idx]
    x_test_raw = features_df.to_numpy(dtype=np.float64)[test_idx]
    y_trainval = target[trainval_idx].astype(np.float64)
    y_test = target[test_idx].astype(np.float64)
    w_trainval = sample_weights[trainval_idx].astype(np.float64)

    x_trainval, medians, clip_low, clip_high, mean, std = _fit_preprocessor(
        x_trainval_raw,
        q_low=DEFAULT_CLIP_QUANTILE_LOW,
        q_high=DEFAULT_CLIP_QUANTILE_HIGH,
    )
    x_test = _transform_with_preprocessor(
        x_test_raw,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
    )
    modality_groups = _build_student_modality_groups(feature_names)
    missing_fill, missing_flag_on = _build_student_fill_vectors(
        feature_names=feature_names,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
    )

    teacher_model = _fit_teacher_model(
        spec=teacher_tuning["best_spec"],
        x_train=x_trainval,
        y_train=y_trainval,
        sample_weight=w_trainval,
    )
    teacher_test_pred = np.clip(_predict_model(teacher_tuning["best_spec"]["name"], teacher_model, x_test), 0, 100)

    student_model, trainval_pretrain_report, student_refit_report = _fit_final_student_model(
        feature_names=feature_names,
        x_train_full=x_trainval,
        x_train_raw_full=x_trainval_raw,
        y_train_full=y_trainval,
        component_targets_full={
            key: values[trainval_idx].astype(np.float64)
            for key, values in component_targets.items()
        },
        groups_train_full=groups[trainval_idx],
        sample_dates_train_full=None if sample_dates is None else sample_dates[trainval_idx],
        sample_weight_full=w_trainval,
        split_mode=split_mode,
        teacher_spec=teacher_tuning["best_spec"],
        teacher_model_full=teacher_model,
        student_spec=student_tuning["best_spec"],
        external_pretrain_bundle=external_pretrain_bundle,
        external_pretrain_objective=external_pretrain_objective,
        medians_full=medians,
        clip_low_full=clip_low,
        clip_high_full=clip_high,
        mean_full=mean,
        std_full=std,
    )
    student_test_pred = np.clip(_predict_model("student_residual_mlp", student_model, x_test), 0, 100)

    baseline_pred = np.full(shape=y_test.shape, fill_value=float(np.mean(y_trainval)))
    teacher_test_metrics = _extended_regression_metrics(
        y_true=y_test,
        y_pred=teacher_test_pred,
        groups=groups[test_idx],
    )
    student_test_metrics = _extended_regression_metrics(
        y_true=y_test,
        y_pred=student_test_pred,
        groups=groups[test_idx],
    )
    baseline_test_metrics = _extended_regression_metrics(
        y_true=y_test,
        y_pred=baseline_pred,
        groups=groups[test_idx],
    )
    teacher_platform_diagnostics = _model_platform_profile_diagnostics(
        model_name=str(teacher_tuning["best_spec"]["name"]),
        model_payload=teacher_model,
        x=x_test,
        y_true=y_test,
        groups=groups[test_idx],
        modality_groups=modality_groups,
        missing_fill=missing_fill,
        missing_flag_on=missing_flag_on,
    )
    student_platform_diagnostics = _model_platform_profile_diagnostics(
        model_name="student_residual_mlp",
        model_payload=student_model,
        x=x_test,
        y_true=y_test,
        groups=groups[test_idx],
        modality_groups=modality_groups,
        missing_fill=missing_fill,
        missing_flag_on=missing_flag_on,
    )

    selected_model_name = _select_model_name(
        selection_policy=selection_policy,
        teacher_name=str(teacher_tuning["best_spec"]["name"]),
        teacher_validation_mae=teacher_tuning["summary"]["mae_mean"],
        student_validation_mae=student_tuning["summary"]["mae_mean"],
    )
    selected_model = student_model if selected_model_name == "student_residual_mlp" else teacher_model

    preprocessor = {
        "medians": medians.tolist(),
        "clip_low": clip_low.tolist(),
        "clip_high": clip_high.tolist(),
        "mean": mean.tolist(),
        "std": std.tolist(),
    }

    promotion_gate = {
        "passed": bool(student_tuning["summary"]["mae_mean"] <= teacher_tuning["summary"]["mae_mean"] * (1.0 + quality_gate_ratio)),
        "teacher_validation_mae": float(teacher_tuning["summary"]["mae_mean"]),
        "student_validation_mae": float(student_tuning["summary"]["mae_mean"]),
        "allowed_validation_mae": float(teacher_tuning["summary"]["mae_mean"] * (1.0 + quality_gate_ratio)),
    }

    unseen_user = _secondary_unseen_user_report(
        features_df=features_df,
        target=target,
        component_targets=component_targets,
        groups=groups,
        sample_weights=sample_weights,
        teacher_spec=teacher_tuning["best_spec"],
        student_spec=student_tuning["best_spec"],
        external_pretrain_bundle=external_pretrain_bundle,
        external_pretrain_objective=external_pretrain_objective,
    )

    external_pretraining: Optional[Dict[str, object]] = None
    if bool(external_pretraining_info.get("enabled")):
        external_pretraining = dict(external_pretraining_info)
        external_pretraining.update(
            {
                "selected_init_mode": student_tuning["selected_init_mode"],
                "best_candidate_index": student_tuning["best_candidate_index"],
                "trainval_pretraining": trainval_pretrain_report,
            }
        )

    report = {
        "feature_names": feature_names,
        "preprocessor": preprocessor,
        "split_manifest": split_plan.manifest,
        "trainval_idx": trainval_idx,
        "test_idx": test_idx,
        "selected_model_name": selected_model_name,
        "selected_model": selected_model,
        "selected_validation_mae": float(
            student_tuning["summary"]["mae_mean"]
            if selected_model_name == "student_residual_mlp"
            else teacher_tuning["summary"]["mae_mean"]
        ),
        "feature_missingness": _feature_missingness_report(features_df),
        "target_distribution": _target_distribution_report(target),
        "validation_protocol": {
            "strategy": split_plan.strategy,
            "fold_names": [fold.name for fold in split_plan.validation_folds],
            "frozen_test_policy": split_plan.manifest.get("frozen_test_policy"),
        },
        "teacher_metrics": {
            "selected_teacher": teacher_tuning["best_spec"]["name"],
            "validation_summary": teacher_tuning["summary"],
            "validation_folds": teacher_tuning["fold_reports"],
            "candidate_reports": teacher_tuning["candidate_reports"],
            "frozen_test": teacher_test_metrics,
        },
        "student_metrics": {
            "validation_summary": student_tuning["summary"],
            "validation_folds": student_tuning["fold_reports"],
            "candidate_reports": student_tuning["candidate_reports"],
            "frozen_test": student_test_metrics,
        },
        "student_selection": {
            "strategy": student_tuning["selection_strategy"],
            "selected_family_index": student_tuning["selected_family_index"],
            "selected_candidate_index": student_tuning["best_candidate_index"],
            "family_reports": student_tuning["family_reports"],
        },
        "frozen_test_summary": {
            "mean_baseline": baseline_test_metrics,
            "teacher": teacher_test_metrics,
            "student": student_test_metrics,
        },
        "platform_profile_diagnostics": {
            "teacher": teacher_platform_diagnostics,
            "student": student_platform_diagnostics,
            "selection_weight": STUDENT_PLATFORM_VALIDATION_WEIGHT,
        },
        "promotion_gate": promotion_gate,
        "secondary_unseen_user_report": unseen_user,
        "student_component_scaling": student_model["component_scaling"],
        "student_architecture": student_model["architecture"],
        "student_final_fit": student_refit_report,
    }
    if external_pretraining is not None:
        report["external_pretraining"] = external_pretraining
    return report


def _build_split_plan(
    n_rows: int,
    groups: np.ndarray,
    sample_dates: Optional[np.ndarray],
    split_mode: str,
) -> SplitPlan:
    indices = np.arange(n_rows)

    if split_mode == "temporal_per_user" and sample_dates is not None:
        frame = pd.DataFrame(
            {
                "idx": indices,
                "group": groups,
                "date": pd.to_datetime(sample_dates, errors="coerce"),
            }
        )
        frame["date"] = frame["date"].fillna(pd.Timestamp("1970-01-01"))
        frame = frame.sort_values(["group", "date", "idx"]).reset_index(drop=True)

        fold_train_parts: List[List[np.ndarray]] = [[], [], []]
        fold_val_parts: List[List[np.ndarray]] = [[], [], []]
        trainval_parts: List[np.ndarray] = []
        test_parts: List[np.ndarray] = []
        per_group_manifest: Dict[str, object] = {}

        for group_key, group_frame in frame.groupby("group"):
            idx_values = group_frame["idx"].to_numpy(dtype=np.int64)
            trainval_idx, test_idx, fold_ranges = _group_temporal_windows(idx_values)
            if trainval_idx.size > 0:
                trainval_parts.append(trainval_idx)
            if test_idx.size > 0:
                test_parts.append(test_idx)
            for fold_index, (fold_train, fold_val) in enumerate(fold_ranges[:3]):
                if fold_train.size == 0 or fold_val.size == 0:
                    continue
                fold_train_parts[fold_index].append(fold_train)
                fold_val_parts[fold_index].append(fold_val)
            per_group_manifest[str(group_key)] = {
                "rows": int(idx_values.size),
                "trainval_rows": int(trainval_idx.size),
                "test_rows": int(test_idx.size),
            }

        trainval_idx = np.concatenate(trainval_parts) if trainval_parts else np.array([], dtype=np.int64)
        test_idx = np.concatenate(test_parts) if test_parts else np.array([], dtype=np.int64)
        validation_folds = []
        for fold_index in range(3):
            if not fold_train_parts[fold_index] or not fold_val_parts[fold_index]:
                continue
            validation_folds.append(
                ValidationFold(
                    name=f"temporal_block_{fold_index + 1}",
                    train_idx=np.concatenate(fold_train_parts[fold_index]),
                    val_idx=np.concatenate(fold_val_parts[fold_index]),
                )
            )
        manifest = {
            "strategy": "temporal_blocked_per_user",
            "seed": SEED,
            "validation_fold_names": [fold.name for fold in validation_folds],
            "frozen_test_policy": "last_20pct_per_user",
            "trainval_idx": trainval_idx.tolist(),
            "test_idx": test_idx.tolist(),
            "folds": [
                {
                    "name": fold.name,
                    "train_idx": fold.train_idx.tolist(),
                    "val_idx": fold.val_idx.tolist(),
                }
                for fold in validation_folds
            ],
            "groups": per_group_manifest,
        }
        return SplitPlan(
            strategy="temporal_blocked_per_user",
            trainval_idx=trainval_idx,
            test_idx=test_idx,
            validation_folds=validation_folds,
            manifest=manifest,
        )

    unique_groups = np.unique(groups)
    if len(unique_groups) >= 4:
        outer = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED)
        trainval_idx, test_idx = next(outer.split(indices, groups=groups))
        validation_folds: List[ValidationFold] = []
        inner_seeds = [SEED, SEED + 17, SEED + 29]
        for idx, inner_seed in enumerate(inner_seeds, start=1):
            inner = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=inner_seed)
            fold_train_local, fold_val_local = next(inner.split(trainval_idx, groups=groups[trainval_idx]))
            validation_folds.append(
                ValidationFold(
                    name=f"group_holdout_{idx}",
                    train_idx=trainval_idx[fold_train_local],
                    val_idx=trainval_idx[fold_val_local],
                )
            )
        manifest = {
            "strategy": "group_holdout",
            "seed": SEED,
            "validation_fold_names": [fold.name for fold in validation_folds],
            "frozen_test_policy": "group_shuffle_split_20pct",
            "trainval_idx": trainval_idx.tolist(),
            "test_idx": test_idx.tolist(),
            "folds": [
                {
                    "name": fold.name,
                    "train_idx": fold.train_idx.tolist(),
                    "val_idx": fold.val_idx.tolist(),
                }
                for fold in validation_folds
            ],
        }
        return SplitPlan(
            strategy="group_holdout",
            trainval_idx=trainval_idx,
            test_idx=test_idx,
            validation_folds=validation_folds,
            manifest=manifest,
        )

    trainval_idx, test_idx = train_test_split(indices, test_size=0.2, random_state=SEED)
    train_idx, val_idx = train_test_split(trainval_idx, test_size=0.2, random_state=SEED)
    manifest = {
        "strategy": "random_small_dataset",
        "seed": SEED,
        "validation_fold_names": ["single_holdout"],
        "frozen_test_policy": "random_20pct",
        "trainval_idx": trainval_idx.tolist(),
        "test_idx": test_idx.tolist(),
        "folds": [
            {
                "name": "single_holdout",
                "train_idx": train_idx.tolist(),
                "val_idx": val_idx.tolist(),
            }
        ],
    }
    return SplitPlan(
        strategy="random_small_dataset",
        trainval_idx=trainval_idx,
        test_idx=test_idx,
        validation_folds=[ValidationFold(name="single_holdout", train_idx=train_idx, val_idx=val_idx)],
        manifest=manifest,
    )


def _group_temporal_windows(idxs: np.ndarray) -> Tuple[np.ndarray, np.ndarray, List[Tuple[np.ndarray, np.ndarray]]]:
    idxs = np.asarray(idxs, dtype=np.int64)
    n = idxs.size
    if n == 0:
        return idxs, np.array([], dtype=np.int64), []
    if n < 5:
        return idxs, np.array([], dtype=np.int64), []

    raw_cuts = [int(np.floor(n * ratio)) for ratio in (0.50, 0.60, 0.70, 0.80)]
    cuts: List[int] = []
    for value in raw_cuts:
        value = max(value, 3)
        if cuts:
            value = max(value, cuts[-1] + 1)
        value = min(value, n - 1)
        if not cuts or value > cuts[-1]:
            cuts.append(value)
    if len(cuts) == 1:
        cuts.append(n - 1)
    while len(cuts) < 4:
        next_value = min(max(cuts[-1] + 1, 4), n - 1)
        if next_value <= cuts[-1]:
            break
        cuts.append(next_value)
    cut_final = cuts[-1]
    trainval_idx = idxs[:cut_final]
    test_idx = idxs[cut_final:]
    folds: List[Tuple[np.ndarray, np.ndarray]] = []
    seen_ranges: set[Tuple[int, int]] = set()
    for fold_index in range(len(cuts) - 1):
        start = cuts[fold_index]
        end = cuts[fold_index + 1]
        if start < 3 or end <= start:
            continue
        if (start, end) in seen_ranges:
            continue
        seen_ranges.add((start, end))
        folds.append((idxs[:start], idxs[start:end]))
    if not folds and trainval_idx.size >= 4:
        val_start = max(3, trainval_idx.size - 1)
        folds.append((trainval_idx[:val_start], trainval_idx[val_start:]))
    return trainval_idx, test_idx, folds


def _tune_teacher_models(
    features_df: pd.DataFrame,
    target: np.ndarray,
    groups: np.ndarray,
    sample_weights: np.ndarray,
    folds: Sequence[ValidationFold],
) -> Dict[str, object]:
    candidate_specs: List[Dict[str, object]] = []
    base_xgb = {
        "objective": "reg:squarederror",
        "random_state": SEED,
        "n_jobs": -1,
        "subsample": 0.90,
        "colsample_bytree": 0.90,
        "reg_alpha": 0.0,
        "reg_lambda": 1.0,
    }
    for params in [
        {"n_estimators": 50, "max_depth": 2, "learning_rate": 0.08},
        {"n_estimators": 100, "max_depth": 2, "learning_rate": 0.05},
        {"n_estimators": 150, "max_depth": 3, "learning_rate": 0.05},
        {"n_estimators": 80, "max_depth": 3, "learning_rate": 0.08, "min_child_weight": 3},
        {"n_estimators": 200, "max_depth": 4, "learning_rate": 0.03, "min_child_weight": 5},
    ]:
        candidate_specs.append({"name": "xgboost", "params": {**base_xgb, **params}})
    for params in [
        {"alpha": 0.0005, "epsilon": 1.2, "max_iter": 3000},
        {"alpha": 0.001, "epsilon": 1.35, "max_iter": 3000},
        {"alpha": 0.002, "epsilon": 1.5, "max_iter": 3000},
    ]:
        candidate_specs.append({"name": "huber", "params": params})

    candidate_reports: List[Dict[str, object]] = []
    best_summary: Optional[Dict[str, float]] = None
    best_spec: Optional[Dict[str, object]] = None
    best_fold_reports: Optional[List[Dict[str, object]]] = None

    for candidate_index, spec in enumerate(candidate_specs):
        fold_reports: List[Dict[str, object]] = []
        for fold in folds:
            x_train_raw = features_df.to_numpy(dtype=np.float64)[fold.train_idx]
            x_val_raw = features_df.to_numpy(dtype=np.float64)[fold.val_idx]
            x_train, medians, clip_low, clip_high, mean, std = _fit_preprocessor(
                x_train_raw,
                q_low=DEFAULT_CLIP_QUANTILE_LOW,
                q_high=DEFAULT_CLIP_QUANTILE_HIGH,
            )
            x_val = _transform_with_preprocessor(
                x_val_raw,
                medians=medians,
                clip_low=clip_low,
                clip_high=clip_high,
                mean=mean,
                std=std,
            )
            model = _fit_teacher_model(
                spec=spec,
                x_train=x_train,
                y_train=target[fold.train_idx],
                sample_weight=sample_weights[fold.train_idx],
            )
            pred = np.clip(_predict_model(spec["name"], model, x_val), 0, 100)
            metrics = _extended_regression_metrics(
                y_true=target[fold.val_idx],
                y_pred=pred,
                groups=groups[fold.val_idx],
            )
            fold_reports.append({"fold": fold.name, **metrics})
        summary = _aggregate_fold_reports(fold_reports)
        report = {
            "candidate_index": candidate_index,
            "name": spec["name"],
            "params": spec["params"],
            "summary": summary,
            "fold_reports": fold_reports,
        }
        candidate_reports.append(report)
        if best_summary is None or summary["mae_mean"] < best_summary["mae_mean"]:
            best_summary = summary
            best_spec = spec
            best_fold_reports = fold_reports

    if best_summary is None or best_spec is None or best_fold_reports is None:
        raise RuntimeError("Teacher tuning failed.")

    return {
        "best_spec": best_spec,
        "summary": best_summary,
        "fold_reports": best_fold_reports,
        "candidate_reports": candidate_reports,
    }


def _fit_teacher_model(
    spec: Dict[str, object],
    x_train: np.ndarray,
    y_train: np.ndarray,
    sample_weight: np.ndarray,
) -> object:
    name = str(spec["name"])
    params = spec["params"]
    if name == "xgboost":
        model = xgb.XGBRegressor(**params)  # type: ignore[arg-type]
        model.fit(x_train, y_train, sample_weight=sample_weight)
        return model
    if name == "huber":
        model = HuberRegressor(**params)  # type: ignore[arg-type]
        model.fit(x_train, y_train, sample_weight=sample_weight)
        return model
    raise ValueError(f"Unsupported teacher spec {name}")


def _build_student_candidate_specs() -> List[Dict[str, object]]:
    base_specs = [
        {
            "hidden_dim": 32,
            "bottleneck_dim": 16,
            "learning_rate": 0.008,
            "weight_decay": 0.0002,
            "epochs": 700,
            "batch_size": 64,
            "comp_loss_weight": 0.55,
            "overall_loss_weight": 0.25,
            "distill_loss_weight": 0.20,
            "platform_profile_prob": 0.30,
            "optional_group_dropout_prob": 0.05,
            "feature_noise_std": 0.008,
            "seed": SEED,
        },
        {
            "hidden_dim": 48,
            "bottleneck_dim": 24,
            "learning_rate": 0.006,
            "weight_decay": 0.0004,
            "epochs": 900,
            "batch_size": 64,
            "comp_loss_weight": 0.50,
            "overall_loss_weight": 0.25,
            "distill_loss_weight": 0.25,
            "platform_profile_prob": 0.35,
            "optional_group_dropout_prob": 0.08,
            "feature_noise_std": 0.010,
            "seed": SEED + 1,
        },
        {
            "hidden_dim": 64,
            "bottleneck_dim": 32,
            "learning_rate": 0.005,
            "weight_decay": 0.0005,
            "epochs": 1100,
            "batch_size": 64,
            "comp_loss_weight": 0.45,
            "overall_loss_weight": 0.25,
            "distill_loss_weight": 0.30,
            "platform_profile_prob": 0.45,
            "optional_group_dropout_prob": 0.10,
            "feature_noise_std": 0.015,
            "seed": SEED + 2,
        },
    ]

    focused_base = {
        "hidden_dim": 64,
        "bottleneck_dim": 32,
        "learning_rate": 0.005,
        "weight_decay": 0.0005,
        "epochs": 1100,
        "batch_size": 64,
        "platform_profile_prob": 0.45,
        "optional_group_dropout_prob": 0.10,
        "feature_noise_std": 0.015,
    }
    extra_specs = [
        {
            **focused_base,
            "comp_loss_weight": 0.45,
            "overall_loss_weight": 0.25,
            "distill_loss_weight": 0.30,
            "seed": SEED + 5,
        },
        {
            **focused_base,
            "comp_loss_weight": 0.45,
            "overall_loss_weight": 0.25,
            "distill_loss_weight": 0.30,
            "seed": SEED + 9,
        },
    ]

    specs: List[Dict[str, object]] = []
    seen: set[Tuple[object, ...]] = set()
    for spec in [*base_specs, *extra_specs]:
        key = (
            spec["hidden_dim"],
            spec["bottleneck_dim"],
            spec["learning_rate"],
            spec["weight_decay"],
            spec["epochs"],
            spec["batch_size"],
            spec["comp_loss_weight"],
            spec["overall_loss_weight"],
            spec["distill_loss_weight"],
            spec["platform_profile_prob"],
            spec["optional_group_dropout_prob"],
            spec["feature_noise_std"],
            spec["seed"],
        )
        if key in seen:
            continue
        seen.add(key)
        specs.append(spec)
    return specs


def _student_candidate_family_key(config: Dict[str, object]) -> Tuple[Tuple[str, object], ...]:
    excluded = {
        "seed",
        "selected_epochs",
        "best_epoch",
        "best_val_mae",
        "refit_strategy",
    }
    normalized: List[Tuple[str, object]] = []
    for key, value in config.items():
        if key in excluded:
            continue
        normalized.append((str(key), value))
    return tuple(sorted(normalized))


def _summarize_student_candidate_families(
    candidate_reports: Sequence[Dict[str, object]],
) -> Tuple[List[Dict[str, object]], Optional[Dict[str, object]]]:
    families: Dict[Tuple[Tuple[str, object], ...], List[Dict[str, object]]] = {}
    for report in candidate_reports:
        config = report.get("config")
        if not isinstance(config, dict):
            continue
        family_key = _student_candidate_family_key(config)
        families.setdefault(family_key, []).append(report)

    family_reports: List[Dict[str, object]] = []
    for family_index, family_key in enumerate(sorted(families.keys())):
        reports = families[family_key]
        selection_scores = np.array(
            [float(report["summary"]["selection_score"]) for report in reports],
            dtype=np.float64,
        )
        mae_values = np.array(
            [float(report["summary"]["mae_mean"]) for report in reports],
            dtype=np.float64,
        )
        platform_values = np.array(
            [
                float(report["summary"].get("platform_mae_mean", report["summary"]["mae_mean"]))
                for report in reports
            ],
            dtype=np.float64,
        )
        best_selection_score = float(np.min(selection_scores))
        median_selection_score = float(np.median(selection_scores))
        median_mae = float(np.median(mae_values))
        near_best_reports = [
            report
            for report in reports
            if float(report["summary"]["selection_score"])
            <= best_selection_score + STUDENT_SELECTION_TIE_TOLERANCE
        ]
        representative_pool = near_best_reports if near_best_reports else reports
        representative = min(
            representative_pool,
            key=lambda report: (
                -float(report["summary"].get("r2_mean", 0.0)),
                float(report["summary"].get("per_user_mae_mean", report["summary"]["mae_mean"])),
                float(report["summary"].get("low_score_mae_mean", report["summary"]["mae_mean"])),
                float(report["summary"].get("mae_std", 0.0)),
                abs(float(report["summary"]["selection_score"]) - median_selection_score),
                abs(float(report["summary"]["mae_mean"]) - median_mae),
                float(report["summary"]["selection_score"]),
                int(report["candidate_index"]),
            ),
        )
        family_reports.append(
            {
                "family_index": family_index,
                "family_config": {
                    key: value
                    for key, value in representative["config"].items()
                    if key not in {"seed", "selected_epochs", "best_epoch", "best_val_mae"}
                },
                "candidate_indices": [int(report["candidate_index"]) for report in reports],
                "seeds": [
                    int(report["config"]["seed"])
                    for report in reports
                    if "seed" in report.get("config", {})
                ],
                "family_size": len(reports),
                "summary": {
                    "mean_selection_score": float(np.mean(selection_scores)),
                    "best_selection_score": best_selection_score,
                    "median_selection_score": median_selection_score,
                    "selection_score_std": float(np.std(selection_scores)),
                    "mean_mae": float(np.mean(mae_values)),
                    "median_mae": median_mae,
                    "mean_platform_mae": float(np.mean(platform_values)),
                },
                "representative_pool_candidate_indices": [
                    int(report["candidate_index"]) for report in representative_pool
                ],
                "representative_candidate_index": int(representative["candidate_index"]),
                "representative_seed": representative["config"].get("seed"),
                "representative_summary": representative["summary"],
            }
        )

    if not family_reports:
        return [], None

    selected_family = min(
        family_reports,
        key=lambda report: (
            float(report["summary"]["mean_selection_score"]),
            float(report["summary"]["median_selection_score"]),
            float(report["summary"]["selection_score_std"]),
            float(report["summary"]["mean_mae"]),
            int(report["representative_candidate_index"]),
        ),
    )
    return family_reports, selected_family


def _build_student_modality_groups(
    feature_names: Sequence[str],
) -> Dict[str, Dict[str, np.ndarray]]:
    groups: Dict[str, Dict[str, List[int]]] = {
        "distance": {"all": [], "missing_flags": []},
        "calories": {"all": [], "missing_flags": []},
        "sdnn": {"all": [], "missing_flags": []},
        "rmssd": {"all": [], "missing_flags": []},
    }

    def add(group_name: str, index: int, is_missing_flag: bool) -> None:
        groups[group_name]["all"].append(index)
        if is_missing_flag:
            groups[group_name]["missing_flags"].append(index)

    for index, name in enumerate(feature_names):
        normalized = str(name).strip().lower()
        is_missing_flag = normalized.endswith("_missing")
        if normalized.startswith("distance_"):
            add("distance", index, is_missing_flag)
            continue
        if normalized.startswith("calories_"):
            add("calories", index, is_missing_flag)
            continue
        if normalized.startswith("sdnn_") or normalized == "hr_sdnn_interaction":
            add("sdnn", index, is_missing_flag)
            continue
        if normalized.startswith("rmssd_") or normalized == "hr_rmssd_interaction":
            add("rmssd", index, is_missing_flag)

    return {
        group_name: {
            "all": np.array(payload["all"], dtype=np.int64),
            "missing_flags": np.array(payload["missing_flags"], dtype=np.int64),
        }
        for group_name, payload in groups.items()
        if payload["all"]
    }


def _build_student_fill_vectors(
    *,
    feature_names: Sequence[str],
    medians: np.ndarray,
    clip_low: np.ndarray,
    clip_high: np.ndarray,
    mean: np.ndarray,
    std: np.ndarray,
) -> Tuple[np.ndarray, np.ndarray]:
    feature_count = len(feature_names)
    missing_raw = np.full((1, feature_count), np.nan, dtype=np.float64)
    missing_fill = _transform_with_preprocessor(
        missing_raw,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
    )[0]

    missing_flag_on_raw = np.full((1, feature_count), np.nan, dtype=np.float64)
    for index, name in enumerate(feature_names):
        if str(name).strip().lower().endswith("_missing"):
            missing_flag_on_raw[0, index] = 1.0
    missing_flag_on = _transform_with_preprocessor(
        missing_flag_on_raw,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
    )[0]
    return missing_fill, missing_flag_on


def _mask_student_modalities(
    *,
    x: np.ndarray,
    group_names_per_row: Sequence[Sequence[str]],
    modality_groups: Dict[str, Dict[str, np.ndarray]],
    missing_fill: np.ndarray,
    missing_flag_on: np.ndarray,
) -> np.ndarray:
    if x.size == 0:
        return x.copy()
    masked = x.copy()
    for row_index, group_names in enumerate(group_names_per_row):
        for group_name in group_names:
            payload = modality_groups.get(group_name)
            if payload is None:
                continue
            all_indices = payload["all"]
            if all_indices.size == 0:
                continue
            masked[row_index, all_indices] = missing_fill[all_indices]
            flag_indices = payload["missing_flags"]
            if flag_indices.size > 0:
                masked[row_index, flag_indices] = missing_flag_on[flag_indices]
    return masked


def _augment_student_inputs(
    *,
    x: np.ndarray,
    feature_names: Sequence[str],
    modality_groups: Dict[str, Dict[str, np.ndarray]],
    missing_fill: np.ndarray,
    missing_flag_on: np.ndarray,
    platform_profile_prob: float,
    optional_group_dropout_prob: float,
    feature_noise_std: float,
    rng: np.random.Generator,
) -> np.ndarray:
    if x.size == 0:
        return x.copy()

    batch_size = x.shape[0]
    group_names_per_row: List[set[str]] = [set() for _ in range(batch_size)]
    profile_names = tuple(STUDENT_PLATFORM_PROFILES.keys())
    optional_groups = tuple(
        group_name for group_name in ("distance", "calories", "sdnn", "rmssd")
        if group_name in modality_groups
    )

    if platform_profile_prob > 0.0 and profile_names:
        for row_index in range(batch_size):
            if rng.random() >= platform_profile_prob:
                continue
            profile_name = profile_names[int(rng.integers(0, len(profile_names)))]
            for group_name in STUDENT_PLATFORM_PROFILES[profile_name]:
                if group_name in modality_groups:
                    group_names_per_row[row_index].add(group_name)

    if optional_group_dropout_prob > 0.0 and optional_groups:
        for row_index in range(batch_size):
            for group_name in optional_groups:
                if rng.random() < optional_group_dropout_prob:
                    group_names_per_row[row_index].add(group_name)

    augmented = _mask_student_modalities(
        x=x,
        group_names_per_row=[tuple(names) for names in group_names_per_row],
        modality_groups=modality_groups,
        missing_fill=missing_fill,
        missing_flag_on=missing_flag_on,
    )

    if feature_noise_std <= 0.0:
        return augmented

    noise = rng.normal(0.0, feature_noise_std, size=augmented.shape)
    noise_mask = np.ones(augmented.shape, dtype=bool)
    missing_flag_indices = np.array(
        [
            index
            for index, name in enumerate(feature_names)
            if str(name).strip().lower().endswith("_missing")
        ],
        dtype=np.int64,
    )
    if missing_flag_indices.size > 0:
        noise_mask[:, missing_flag_indices] = False
    for row_index, group_names in enumerate(group_names_per_row):
        for group_name in group_names:
            payload = modality_groups.get(group_name)
            if payload is None:
                continue
            all_indices = payload["all"]
            if all_indices.size > 0:
                noise_mask[row_index, all_indices] = False
    augmented[noise_mask] += noise[noise_mask]
    return augmented


def _model_platform_profile_diagnostics(
    *,
    model_name: str,
    model_payload: object,
    x: np.ndarray,
    y_true: np.ndarray,
    groups: np.ndarray,
    modality_groups: Dict[str, Dict[str, np.ndarray]],
    missing_fill: np.ndarray,
    missing_flag_on: np.ndarray,
) -> Dict[str, object]:
    profile_reports: Dict[str, Dict[str, float]] = {}
    profile_maes: List[float] = []
    for profile_name, group_names in STUDENT_PLATFORM_PROFILES.items():
        masked_x = _mask_student_modalities(
            x=x,
            group_names_per_row=[group_names] * len(x),
            modality_groups=modality_groups,
            missing_fill=missing_fill,
            missing_flag_on=missing_flag_on,
        )
        pred = np.clip(_predict_model(model_name, model_payload, masked_x), 0, 100)
        metrics = _extended_regression_metrics(
            y_true=y_true,
            y_pred=pred,
            groups=groups,
        )
        profile_reports[profile_name] = metrics
        profile_maes.append(float(metrics["mae"]))
    return {
        "profiles": profile_reports,
        "platform_mae_mean": float(np.mean(profile_maes)) if profile_maes else 0.0,
    }


def _build_final_refit_validation_fold(
    *,
    groups: np.ndarray,
    sample_dates: Optional[np.ndarray],
    split_mode: str,
    validation_ratio: float = FINAL_REFIT_VALIDATION_RATIO,
) -> Optional[ValidationFold]:
    n_rows = int(len(groups))
    if n_rows < 24:
        return None

    local_idx = np.arange(n_rows, dtype=np.int64)

    if split_mode == "temporal_per_user" and sample_dates is not None:
        frame = pd.DataFrame(
            {
                "idx": local_idx,
                "group": groups,
                "date": pd.to_datetime(sample_dates, errors="coerce"),
            }
        )
        frame["date"] = frame["date"].fillna(pd.Timestamp("1970-01-01"))
        frame = frame.sort_values(["group", "date", "idx"]).reset_index(drop=True)

        train_parts: List[np.ndarray] = []
        val_parts: List[np.ndarray] = []
        for _, group_frame in frame.groupby("group"):
            idx_values = group_frame["idx"].to_numpy(dtype=np.int64)
            if idx_values.size < 5:
                train_parts.append(idx_values)
                continue

            max_val = idx_values.size - 3
            if max_val <= 0:
                train_parts.append(idx_values)
                continue
            val_count = min(max(int(np.ceil(idx_values.size * validation_ratio)), 1), max_val)
            split_point = idx_values.size - val_count
            train_part = idx_values[:split_point]
            val_part = idx_values[split_point:]
            if train_part.size < 3 or val_part.size == 0:
                train_parts.append(idx_values)
                continue
            train_parts.append(train_part)
            val_parts.append(val_part)

        if not val_parts:
            return None
        train_idx = np.concatenate(train_parts) if train_parts else np.array([], dtype=np.int64)
        val_idx = np.concatenate(val_parts)
        if train_idx.size < 20 or val_idx.size < 8:
            return None
        return ValidationFold(
            name="final_refit_temporal_holdout",
            train_idx=train_idx,
            val_idx=val_idx,
        )

    unique_groups = np.unique(groups)
    if split_mode == "group_holdout" and len(unique_groups) >= 4:
        splitter = GroupShuffleSplit(n_splits=1, test_size=validation_ratio, random_state=SEED + 303)
        train_idx, val_idx = next(splitter.split(local_idx, groups=groups))
        if train_idx.size < 20 or val_idx.size < 8:
            return None
        return ValidationFold(
            name="final_refit_group_holdout",
            train_idx=train_idx.astype(np.int64),
            val_idx=val_idx.astype(np.int64),
        )

    val_count = max(int(np.ceil(n_rows * validation_ratio)), 8)
    val_count = min(val_count, n_rows - 16)
    if val_count <= 0:
        return None
    return ValidationFold(
        name="final_refit_tail_holdout",
        train_idx=local_idx[:-val_count],
        val_idx=local_idx[-val_count:],
    )


def _tune_student_models(
    features_df: pd.DataFrame,
    target: np.ndarray,
    component_targets: Dict[str, np.ndarray],
    groups: np.ndarray,
    sample_weights: np.ndarray,
    folds: Sequence[ValidationFold],
    teacher_spec: Dict[str, object],
    external_pretrain_bundle: Optional[ExternalPretrainBundle],
    external_pretrain_objective: str,
) -> Dict[str, object]:
    component_matrix = _stack_component_targets(component_targets)
    candidate_specs = _build_student_candidate_specs()
    feature_names = features_df.columns.tolist()
    modality_groups = _build_student_modality_groups(feature_names)

    pretrain_enabled = bool(
        external_pretrain_bundle is not None and len(external_pretrain_bundle.features) > 0
    )
    candidate_variants: List[Tuple[Dict[str, object], str]] = []
    for spec in candidate_specs:
        candidate_variants.append((spec, "random_init"))
        if pretrain_enabled:
            candidate_variants.append((spec, "pretrained_init"))

    candidate_reports: List[Dict[str, object]] = []

    raw_features = features_df.to_numpy(dtype=np.float64)

    for candidate_index, (spec, init_mode) in enumerate(candidate_variants):
        fold_reports: List[Dict[str, object]] = []
        fold_pretrain_reports: List[Dict[str, object]] = []
        for fold_index, fold in enumerate(folds):
            x_train_raw = raw_features[fold.train_idx]
            x_val_raw = raw_features[fold.val_idx]
            x_train, medians, clip_low, clip_high, mean, std = _fit_preprocessor(
                x_train_raw,
                q_low=DEFAULT_CLIP_QUANTILE_LOW,
                q_high=DEFAULT_CLIP_QUANTILE_HIGH,
            )
            x_val = _transform_with_preprocessor(
                x_val_raw,
                medians=medians,
                clip_low=clip_low,
                clip_high=clip_high,
                mean=mean,
                std=std,
            )
            missing_fill, missing_flag_on = _build_student_fill_vectors(
                feature_names=feature_names,
                medians=medians,
                clip_low=clip_low,
                clip_high=clip_high,
                mean=mean,
                std=std,
            )
            teacher_model = _fit_teacher_model(
                spec=teacher_spec,
                x_train=x_train,
                y_train=target[fold.train_idx],
                sample_weight=sample_weights[fold.train_idx],
            )
            teacher_train = np.clip(_predict_model(teacher_spec["name"], teacher_model, x_train), 0, 100)
            encoder_init_state, pretrain_report = _prepare_external_encoder_init(
                external_pretrain_bundle=external_pretrain_bundle,
                feature_names=features_df.columns.tolist(),
                medians=medians,
                clip_low=clip_low,
                clip_high=clip_high,
                mean=mean,
                std=std,
                hidden_dim=int(spec["hidden_dim"]),
                bottleneck_dim=int(spec["bottleneck_dim"]),
                objective=external_pretrain_objective,
                seed=int(spec["seed"]) + (fold_index + 1) * 97,
                enabled=bool(init_mode == "pretrained_init"),
            )
            student_model = _fit_student_model(
                config=spec,
                x_train=x_train,
                component_targets={
                    "efficiency": component_matrix[fold.train_idx, 0],
                    "duration": component_matrix[fold.train_idx, 1],
                    "fragmentation": component_matrix[fold.train_idx, 2],
                },
                y_train=target[fold.train_idx],
                teacher_train=teacher_train,
                sample_weight=sample_weights[fold.train_idx],
                x_val=x_val,
                y_val=target[fold.val_idx],
                component_targets_val={
                    "efficiency": component_matrix[fold.val_idx, 0],
                    "duration": component_matrix[fold.val_idx, 1],
                    "fragmentation": component_matrix[fold.val_idx, 2],
                },
                encoder_init_state=encoder_init_state,
                feature_names=feature_names,
                modality_groups=modality_groups,
                missing_fill=missing_fill,
                missing_flag_on=missing_flag_on,
            )
            pred = np.clip(_predict_model("student_residual_mlp", student_model, x_val), 0, 100)
            metrics = _extended_regression_metrics(
                y_true=target[fold.val_idx],
                y_pred=pred,
                groups=groups[fold.val_idx],
            )
            profile_diagnostics = _model_platform_profile_diagnostics(
                model_name="student_residual_mlp",
                model_payload=student_model,
                x=x_val,
                y_true=target[fold.val_idx],
                groups=groups[fold.val_idx],
                modality_groups=modality_groups,
                missing_fill=missing_fill,
                missing_flag_on=missing_flag_on,
            )
            fold_reports.append(
                {
                    "fold": fold.name,
                    **metrics,
                    "ios_mae": float(
                        profile_diagnostics["profiles"].get("ios", {}).get("mae", np.nan)
                    ),
                    "android_mae": float(
                        profile_diagnostics["profiles"].get("android", {}).get("mae", np.nan)
                    ),
                    "platform_mae_mean": float(profile_diagnostics["platform_mae_mean"]),
                }
            )
            if pretrain_enabled:
                fold_pretrain_reports.append(
                    {
                        "fold": fold.name,
                        **pretrain_report,
                    }
                )
        summary = _aggregate_fold_reports(fold_reports)
        config_with_mode = dict(spec)
        if pretrain_enabled:
            config_with_mode["init_mode"] = init_mode
        report_payload = {
            "candidate_index": candidate_index,
            "config": config_with_mode,
            "summary": summary,
            "fold_reports": fold_reports,
        }
        if pretrain_enabled:
            report_payload["init_mode"] = init_mode
            report_payload["pretrain_reports"] = fold_pretrain_reports
        candidate_reports.append(report_payload)

    family_reports, selected_family = _summarize_student_candidate_families(candidate_reports)
    if selected_family is None:
        raise RuntimeError("Student tuning failed.")

    selected_candidate_index = int(selected_family["representative_candidate_index"])
    selected_candidate = next(
        (
            report
            for report in candidate_reports
            if int(report["candidate_index"]) == selected_candidate_index
        ),
        None,
    )
    if selected_candidate is None:
        raise RuntimeError("Student tuning failed to resolve selected candidate.")
    best_spec = dict(selected_candidate["config"])
    best_summary = dict(selected_candidate["summary"])
    best_fold_reports = list(selected_candidate["fold_reports"])

    return {
        "best_spec": best_spec,
        "summary": best_summary,
        "fold_reports": best_fold_reports,
        "candidate_reports": candidate_reports,
        "family_reports": family_reports,
        "selection_strategy": "family_mean_then_near_best_r2_seed",
        "selected_family_index": int(selected_family["family_index"]),
        "selected_init_mode": str(best_spec.get("init_mode", "random_init")),
        "best_candidate_index": selected_candidate_index,
    }


def _prepare_external_encoder_init(
    *,
    external_pretrain_bundle: Optional[ExternalPretrainBundle],
    feature_names: Sequence[str],
    medians: np.ndarray,
    clip_low: np.ndarray,
    clip_high: np.ndarray,
    mean: np.ndarray,
    std: np.ndarray,
    hidden_dim: int,
    bottleneck_dim: int,
    objective: str,
    seed: int,
    enabled: bool,
) -> Tuple[Optional[Dict[str, np.ndarray]], Dict[str, object]]:
    if not enabled:
        return None, {"enabled": False, "used": False, "reason": "disabled"}
    if external_pretrain_bundle is None:
        return None, {"enabled": True, "used": False, "reason": "bundle_missing"}
    if len(external_pretrain_bundle.features) == 0:
        return None, {"enabled": True, "used": False, "reason": "no_external_rows"}

    feature_frame = external_pretrain_bundle.features.reindex(columns=list(feature_names))
    x_external_raw = feature_frame.to_numpy(dtype=np.float64)
    x_external = _transform_with_preprocessor(
        x_external_raw,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
    )

    modality_feature_names = [name for name in feature_names if name.endswith("_missing")]
    if modality_feature_names:
        modality_targets = (
            external_pretrain_bundle.features.reindex(columns=modality_feature_names)
            .to_numpy(dtype=np.float64)
        )
        modality_targets = np.where(np.isfinite(modality_targets), modality_targets, 1.0)
        modality_targets = np.clip(modality_targets, 0.0, 1.0)
    else:
        modality_targets = np.zeros((len(x_external), 0), dtype=np.float64)

    sample_weight = np.asarray(external_pretrain_bundle.sample_weights, dtype=np.float64)
    if sample_weight.shape[0] != x_external.shape[0]:
        sample_weight = np.ones(x_external.shape[0], dtype=np.float64)
    sample_weight = np.where(np.isfinite(sample_weight), sample_weight, 1.0)
    sample_weight = np.clip(sample_weight, 0.1, 5.0)

    pretrain = _pretrain_student_encoder(
        x_external=x_external,
        modality_targets=modality_targets,
        sample_weight=sample_weight,
        hidden_dim=hidden_dim,
        bottleneck_dim=bottleneck_dim,
        objective=objective,
        seed=seed,
    )
    return pretrain["encoder_state"], {
        "enabled": True,
        "used": True,
        **pretrain["report"],
    }


def _fit_final_student_model(
    *,
    feature_names: Sequence[str],
    x_train_full: np.ndarray,
    x_train_raw_full: np.ndarray,
    y_train_full: np.ndarray,
    component_targets_full: Dict[str, np.ndarray],
    groups_train_full: np.ndarray,
    sample_dates_train_full: Optional[np.ndarray],
    sample_weight_full: np.ndarray,
    split_mode: str,
    teacher_spec: Dict[str, object],
    teacher_model_full: object,
    student_spec: Dict[str, object],
    external_pretrain_bundle: Optional[ExternalPretrainBundle],
    external_pretrain_objective: str,
    medians_full: np.ndarray,
    clip_low_full: np.ndarray,
    clip_high_full: np.ndarray,
    mean_full: np.ndarray,
    std_full: np.ndarray,
) -> Tuple[Dict[str, object], Dict[str, object], Dict[str, object]]:
    selected_epochs = int(student_spec["epochs"])
    epoch_selection_report: Dict[str, object] = {
        "used_internal_validation": False,
        "strategy": "full_trainval_no_internal_validation",
    }
    refit_fold = _build_final_refit_validation_fold(
        groups=groups_train_full,
        sample_dates=sample_dates_train_full,
        split_mode=split_mode,
    )
    if refit_fold is not None:
        x_refit_train_raw = x_train_raw_full[refit_fold.train_idx]
        x_refit_val_raw = x_train_raw_full[refit_fold.val_idx]
        x_refit_train, medians_refit, clip_low_refit, clip_high_refit, mean_refit, std_refit = _fit_preprocessor(
            x_refit_train_raw,
            q_low=DEFAULT_CLIP_QUANTILE_LOW,
            q_high=DEFAULT_CLIP_QUANTILE_HIGH,
        )
        x_refit_val = _transform_with_preprocessor(
            x_refit_val_raw,
            medians=medians_refit,
            clip_low=clip_low_refit,
            clip_high=clip_high_refit,
            mean=mean_refit,
            std=std_refit,
        )
        teacher_model_refit = _fit_teacher_model(
            spec=teacher_spec,
            x_train=x_refit_train,
            y_train=y_train_full[refit_fold.train_idx],
            sample_weight=sample_weight_full[refit_fold.train_idx],
        )
        teacher_refit_train = np.clip(
            _predict_model(teacher_spec["name"], teacher_model_refit, x_refit_train),
            0,
            100,
        )
        probe_pretrain_state, probe_pretrain_report = _prepare_external_encoder_init(
            external_pretrain_bundle=external_pretrain_bundle,
            feature_names=feature_names,
            medians=medians_refit,
            clip_low=clip_low_refit,
            clip_high=clip_high_refit,
            mean=mean_refit,
            std=std_refit,
            hidden_dim=int(student_spec["hidden_dim"]),
            bottleneck_dim=int(student_spec["bottleneck_dim"]),
            objective=external_pretrain_objective,
            seed=int(student_spec["seed"]) + 808,
            enabled=bool(student_spec.get("init_mode") == "pretrained_init"),
        )
        probe_modality_groups = _build_student_modality_groups(feature_names)
        probe_missing_fill, probe_missing_flag_on = _build_student_fill_vectors(
            feature_names=feature_names,
            medians=medians_refit,
            clip_low=clip_low_refit,
            clip_high=clip_high_refit,
            mean=mean_refit,
            std=std_refit,
        )
        probe_student = _fit_student_model(
            config=student_spec,
            x_train=x_refit_train,
            component_targets={
                key: values[refit_fold.train_idx].astype(np.float64)
                for key, values in component_targets_full.items()
            },
            y_train=y_train_full[refit_fold.train_idx],
            teacher_train=teacher_refit_train,
            sample_weight=sample_weight_full[refit_fold.train_idx],
            x_val=x_refit_val,
            y_val=y_train_full[refit_fold.val_idx],
            component_targets_val={
                key: values[refit_fold.val_idx].astype(np.float64)
                for key, values in component_targets_full.items()
            },
            encoder_init_state=probe_pretrain_state,
            feature_names=feature_names,
            modality_groups=probe_modality_groups,
            missing_fill=probe_missing_fill,
            missing_flag_on=probe_missing_flag_on,
        )
        best_epoch = int(probe_student["architecture"].get("best_epoch", -1))
        if best_epoch >= 0:
            selected_epochs = max(best_epoch + 1, 1)
            epoch_selection_report = {
                "used_internal_validation": True,
                "strategy": str(refit_fold.name),
                "selected_epochs": selected_epochs,
                "probe_best_epoch": best_epoch,
                "probe_best_val_mae": probe_student["architecture"].get("best_val_mae"),
                "train_rows": int(refit_fold.train_idx.size),
                "val_rows": int(refit_fold.val_idx.size),
                "probe_pretraining": probe_pretrain_report,
            }

    full_pretrain_state, full_pretrain_report = _prepare_external_encoder_init(
        external_pretrain_bundle=external_pretrain_bundle,
        feature_names=feature_names,
        medians=medians_full,
        clip_low=clip_low_full,
        clip_high=clip_high_full,
        mean=mean_full,
        std=std_full,
        hidden_dim=int(student_spec["hidden_dim"]),
        bottleneck_dim=int(student_spec["bottleneck_dim"]),
        objective=external_pretrain_objective,
        seed=int(student_spec["seed"]) + 404,
        enabled=bool(student_spec.get("init_mode") == "pretrained_init"),
    )
    teacher_train_full = np.clip(
        _predict_model(teacher_spec["name"], teacher_model_full, x_train_full),
        0,
        100,
    )
    final_config = dict(student_spec)
    final_config["epochs"] = selected_epochs
    final_config["selected_epochs"] = selected_epochs
    final_config["refit_strategy"] = str(epoch_selection_report["strategy"])
    modality_groups = _build_student_modality_groups(feature_names)
    missing_fill_full, missing_flag_on_full = _build_student_fill_vectors(
        feature_names=feature_names,
        medians=medians_full,
        clip_low=clip_low_full,
        clip_high=clip_high_full,
        mean=mean_full,
        std=std_full,
    )
    student_model = _fit_student_model(
        config=final_config,
        x_train=x_train_full,
        component_targets={key: values.astype(np.float64) for key, values in component_targets_full.items()},
        y_train=y_train_full,
        teacher_train=teacher_train_full,
        sample_weight=sample_weight_full,
        encoder_init_state=full_pretrain_state,
        feature_names=feature_names,
        modality_groups=modality_groups,
        missing_fill=missing_fill_full,
        missing_flag_on=missing_flag_on_full,
    )
    return student_model, full_pretrain_report, epoch_selection_report


def _pretrain_student_encoder(
    *,
    x_external: np.ndarray,
    modality_targets: np.ndarray,
    sample_weight: np.ndarray,
    hidden_dim: int,
    bottleneck_dim: int,
    objective: str,
    seed: int,
) -> Dict[str, object]:
    if objective != DEFAULT_EXTERNAL_PRETRAIN_OBJECTIVE:
        raise ValueError(f"Unsupported external pretraining objective={objective}")
    if x_external.size == 0 or x_external.shape[0] == 0:
        raise RuntimeError("External pretraining requires at least one row.")

    rng = np.random.default_rng(seed)
    n_features = x_external.shape[1]
    n_modality = modality_targets.shape[1] if modality_targets.ndim == 2 else 0

    encoder = _init_student_state(
        rng=rng,
        n_features=n_features,
        hidden_dim=hidden_dim,
        bottleneck_dim=bottleneck_dim,
    )

    def glorot(in_dim: int, out_dim: int) -> np.ndarray:
        limit = np.sqrt(6.0 / max(in_dim + out_dim, 1))
        return rng.uniform(-limit, limit, size=(in_dim, out_dim)).astype(np.float64)

    pretrain_state: Dict[str, np.ndarray] = {
        **encoder,
        "w_recon": glorot(bottleneck_dim, n_features),
        "b_recon": np.zeros(n_features, dtype=np.float64),
    }
    if n_modality > 0:
        pretrain_state["w_mod"] = glorot(bottleneck_dim, n_modality)
        pretrain_state["b_mod"] = np.zeros(n_modality, dtype=np.float64)

    optimizer = _init_adam_state(pretrain_state)

    epochs = 220
    batch_size = 128
    learning_rate = 0.003
    weight_decay = 0.0001
    mask_ratio = 0.20
    recon_weight = 0.85
    modality_weight = 0.15 if n_modality > 0 else 0.0

    indices = np.arange(x_external.shape[0])
    epoch_losses: List[float] = []
    for _ in range(epochs):
        rng.shuffle(indices)
        batch_losses: List[float] = []
        for start in range(0, len(indices), batch_size):
            batch_idx = indices[start : start + batch_size]
            grads, loss_value = _external_pretrain_loss_and_grads(
                state=pretrain_state,
                x_true=x_external[batch_idx],
                modality_targets=modality_targets[batch_idx] if n_modality > 0 else np.zeros((len(batch_idx), 0), dtype=np.float64),
                sample_weight=sample_weight[batch_idx],
                mask_ratio=mask_ratio,
                recon_weight=recon_weight,
                modality_weight=modality_weight,
                weight_decay=weight_decay,
                rng=rng,
            )
            _adam_step(
                state=pretrain_state,
                grads=grads,
                optimizer_state=optimizer,
                learning_rate=learning_rate,
            )
            batch_losses.append(loss_value)
        if batch_losses:
            epoch_losses.append(float(np.mean(batch_losses)))

    encoder_state = {
        key: pretrain_state[key].copy()
        for key in ("w1", "b1", "w_res", "b_res", "w2", "b2")
    }
    report = {
        "objective": objective,
        "rows": int(x_external.shape[0]),
        "epochs": epochs,
        "mask_ratio": mask_ratio,
        "modality_targets": int(n_modality),
        "mean_loss": float(np.mean(epoch_losses)) if epoch_losses else 0.0,
        "final_loss": float(epoch_losses[-1]) if epoch_losses else 0.0,
    }
    return {"encoder_state": encoder_state, "report": report}


def _external_pretrain_loss_and_grads(
    *,
    state: Dict[str, np.ndarray],
    x_true: np.ndarray,
    modality_targets: np.ndarray,
    sample_weight: np.ndarray,
    mask_ratio: float,
    recon_weight: float,
    modality_weight: float,
    weight_decay: float,
    rng: np.random.Generator,
) -> Tuple[Dict[str, np.ndarray], float]:
    x_true = x_true.astype(np.float64)
    sample_weight = sample_weight.astype(np.float64)
    sample_weight = np.where(np.isfinite(sample_weight), sample_weight, 1.0)
    sample_weight = np.clip(sample_weight, 0.1, 5.0)
    n_samples, n_features = x_true.shape

    mask = rng.random((n_samples, n_features)) < mask_ratio
    if not mask.any():
        mask[0, 0] = True
    x_masked = x_true.copy()
    x_masked[mask] = 0.0

    z1 = x_masked @ state["w1"] + state["b1"]
    a1 = np.maximum(z1, 0.0)
    res = x_masked @ state["w_res"] + state["b_res"]
    h1 = a1 + res
    z2 = h1 @ state["w2"] + state["b2"]
    a2 = np.maximum(z2, 0.0)

    recon = a2 @ state["w_recon"] + state["b_recon"]
    diff_recon = recon - x_true
    recon_loss_raw, recon_grad_raw = _smooth_l1_loss_and_grad(diff_recon, beta=1.0)

    weight_matrix = sample_weight[:, None]
    mask_matrix = mask.astype(np.float64)
    recon_norm = float(np.maximum((mask_matrix * weight_matrix).sum(), 1e-6))
    recon_loss = float((recon_loss_raw * mask_matrix * weight_matrix).sum() / recon_norm)
    recon_grad = recon_grad_raw * mask_matrix * weight_matrix * (recon_weight / recon_norm)

    grads: Dict[str, np.ndarray] = {
        "w_recon": a2.T @ recon_grad + weight_decay * state["w_recon"],
        "b_recon": recon_grad.sum(axis=0),
    }
    grad_a2 = recon_grad @ state["w_recon"].T

    modality_loss = 0.0
    if modality_weight > 0.0 and modality_targets.shape[1] > 0:
        logits = a2 @ state["w_mod"] + state["b_mod"]
        probs = 1.0 / (1.0 + np.exp(-np.clip(logits, -20.0, 20.0)))
        targets = np.clip(modality_targets.astype(np.float64), 0.0, 1.0)
        bce = -(
            targets * np.log(np.clip(probs, 1e-7, 1.0))
            + (1.0 - targets) * np.log(np.clip(1.0 - probs, 1e-7, 1.0))
        )
        modality_norm = float(np.maximum((weight_matrix * np.ones_like(targets)).sum(), 1e-6))
        modality_loss = float((bce * weight_matrix).sum() / modality_norm)
        grad_logits = (probs - targets) * weight_matrix * (modality_weight / modality_norm)
        grads["w_mod"] = a2.T @ grad_logits + weight_decay * state["w_mod"]
        grads["b_mod"] = grad_logits.sum(axis=0)
        grad_a2 += grad_logits @ state["w_mod"].T

    grad_z2 = grad_a2 * (z2 > 0)
    grads["w2"] = h1.T @ grad_z2 + weight_decay * state["w2"]
    grads["b2"] = grad_z2.sum(axis=0)

    grad_h1 = grad_z2 @ state["w2"].T
    grad_res = grad_h1
    grad_a1 = grad_h1
    grad_z1 = grad_a1 * (z1 > 0)

    grads["w_res"] = x_masked.T @ grad_res + weight_decay * state["w_res"]
    grads["b_res"] = grad_res.sum(axis=0)
    grads["w1"] = x_masked.T @ grad_z1 + weight_decay * state["w1"]
    grads["b1"] = grad_z1.sum(axis=0)

    regularization = 0.5 * weight_decay * sum(
        float(np.sum(state[name] ** 2))
        for name in state
        if name.startswith("w")
    )
    total_loss = (recon_weight * recon_loss) + (modality_weight * modality_loss) + regularization
    return grads, float(total_loss)


def _load_encoder_init_into_state(
    *,
    state: Dict[str, np.ndarray],
    encoder_init_state: Dict[str, np.ndarray],
) -> None:
    for key in ("w1", "b1", "w_res", "b_res", "w2", "b2"):
        if key not in encoder_init_state:
            continue
        init_value = np.asarray(encoder_init_state[key], dtype=np.float64)
        if state[key].shape != init_value.shape:
            raise RuntimeError(
                f"Encoder init shape mismatch for {key}: expected {state[key].shape}, got {init_value.shape}"
            )
        state[key] = init_value.copy()


def _stack_component_targets(component_targets: Dict[str, np.ndarray]) -> np.ndarray:
    required = ["efficiency", "duration", "fragmentation"]
    missing = [name for name in required if name not in component_targets]
    if missing:
        raise RuntimeError(f"Missing component targets: {missing}")
    return np.column_stack([component_targets[name] for name in required]).astype(np.float64)


def _fit_student_model(
    config: Dict[str, object],
    x_train: np.ndarray,
    component_targets: Dict[str, np.ndarray],
    y_train: np.ndarray,
    teacher_train: np.ndarray,
    sample_weight: np.ndarray,
    x_val: Optional[np.ndarray] = None,
    y_val: Optional[np.ndarray] = None,
    component_targets_val: Optional[Dict[str, np.ndarray]] = None,
    encoder_init_state: Optional[Dict[str, np.ndarray]] = None,
    feature_names: Optional[Sequence[str]] = None,
    modality_groups: Optional[Dict[str, Dict[str, np.ndarray]]] = None,
    missing_fill: Optional[np.ndarray] = None,
    missing_flag_on: Optional[np.ndarray] = None,
) -> Dict[str, object]:
    y_components = _stack_component_targets(component_targets)
    comp_mean = np.mean(y_components, axis=0)
    comp_std = np.std(y_components, axis=0)
    comp_std = np.where(comp_std < 1e-6, 1.0, comp_std)
    y_components_scaled = (y_components - comp_mean) / comp_std

    rng = np.random.default_rng(int(config["seed"]))
    hidden_dim = int(config["hidden_dim"])
    bottleneck_dim = int(config["bottleneck_dim"])
    learning_rate = float(config["learning_rate"])
    weight_decay = float(config["weight_decay"])
    epochs = int(config["epochs"])
    batch_size = int(config["batch_size"])
    comp_loss_weight = float(config["comp_loss_weight"])
    overall_loss_weight = float(config["overall_loss_weight"])
    distill_loss_weight = float(config["distill_loss_weight"])
    platform_profile_prob = float(config.get("platform_profile_prob", 0.0))
    optional_group_dropout_prob = float(config.get("optional_group_dropout_prob", 0.0))
    feature_noise_std = float(config.get("feature_noise_std", 0.0))

    n_features = x_train.shape[1]
    state = _init_student_state(
        rng=rng,
        n_features=n_features,
        hidden_dim=hidden_dim,
        bottleneck_dim=bottleneck_dim,
    )
    if encoder_init_state:
        _load_encoder_init_into_state(state=state, encoder_init_state=encoder_init_state)
    optimizer_state = _init_adam_state(state)

    best_state = copy.deepcopy(state)
    best_val_mae = float("inf")
    best_epoch = -1
    patience = 120

    indices = np.arange(len(x_train))
    for epoch in range(epochs):
        rng.shuffle(indices)
        for start in range(0, len(indices), batch_size):
            batch_idx = indices[start : start + batch_size]
            x_batch = x_train[batch_idx]
            if (
                feature_names is not None
                and modality_groups is not None
                and missing_fill is not None
                and missing_flag_on is not None
            ):
                x_batch = _augment_student_inputs(
                    x=x_batch,
                    feature_names=feature_names,
                    modality_groups=modality_groups,
                    missing_fill=missing_fill,
                    missing_flag_on=missing_flag_on,
                    platform_profile_prob=platform_profile_prob,
                    optional_group_dropout_prob=optional_group_dropout_prob,
                    feature_noise_std=feature_noise_std,
                    rng=rng,
                )
            grads, _ = _student_loss_and_grads(
                state=state,
                x=x_batch,
                component_targets_scaled=y_components_scaled[batch_idx],
                component_means=comp_mean,
                component_stds=comp_std,
                y_true=y_train[batch_idx],
                teacher_pred=teacher_train[batch_idx],
                sample_weight=sample_weight[batch_idx],
                comp_loss_weight=comp_loss_weight,
                overall_loss_weight=overall_loss_weight,
                distill_loss_weight=distill_loss_weight,
                weight_decay=weight_decay,
            )
            _adam_step(
                state=state,
                grads=grads,
                optimizer_state=optimizer_state,
                learning_rate=learning_rate,
            )

        if x_val is None or y_val is None:
            continue
        val_pred = _student_predict_overall(
            package={
                "state": state,
                "component_means": comp_mean,
                "component_stds": comp_std,
            },
            x=x_val,
        )
        val_mae = float(mean_absolute_error(y_val, np.clip(val_pred, 0, 100)))
        if val_mae < best_val_mae - 1e-5:
            best_val_mae = val_mae
            best_epoch = epoch
            best_state = copy.deepcopy(state)
        elif epoch - best_epoch >= patience:
            break

    if x_val is not None and y_val is not None:
        state = best_state

    architecture = {
        "type": "student_residual_mlp",
        "hidden_dim": hidden_dim,
        "bottleneck_dim": bottleneck_dim,
        "epochs": epochs,
        "best_val_mae": None if best_val_mae == float("inf") else best_val_mae,
        "best_epoch": None if best_epoch < 0 else best_epoch,
        "platform_profile_prob": platform_profile_prob,
        "optional_group_dropout_prob": optional_group_dropout_prob,
        "feature_noise_std": feature_noise_std,
        "overall_residual_head": True,
    }
    if "init_mode" in config:
        architecture["init_mode"] = str(config["init_mode"])
    if "selected_epochs" in config:
        architecture["selected_epochs"] = int(config["selected_epochs"])
    if "refit_strategy" in config:
        architecture["refit_strategy"] = str(config["refit_strategy"])
    component_scaling = {
        "mean": comp_mean.tolist(),
        "std": comp_std.tolist(),
    }
    return {
        "model_type": "student_residual_mlp",
        "state": {key: value.astype(np.float32) for key, value in state.items()},
        "component_scaling": component_scaling,
        "aggregation_weights": COMPONENT_WEIGHTS.astype(np.float32),
        "architecture": architecture,
    }


def _init_student_state(
    rng: np.random.Generator,
    n_features: int,
    hidden_dim: int,
    bottleneck_dim: int,
) -> Dict[str, np.ndarray]:
    def glorot(in_dim: int, out_dim: int) -> np.ndarray:
        limit = np.sqrt(6.0 / max(in_dim + out_dim, 1))
        return rng.uniform(-limit, limit, size=(in_dim, out_dim)).astype(np.float64)

    return {
        "w1": glorot(n_features, hidden_dim),
        "b1": np.zeros(hidden_dim, dtype=np.float64),
        "w_res": glorot(n_features, hidden_dim),
        "b_res": np.zeros(hidden_dim, dtype=np.float64),
        "w2": glorot(hidden_dim, bottleneck_dim),
        "b2": np.zeros(bottleneck_dim, dtype=np.float64),
        "w_out": glorot(bottleneck_dim, 3),
        "b_out": np.zeros(3, dtype=np.float64),
        "w_score": np.zeros((bottleneck_dim, 1), dtype=np.float64),
        "b_score": np.zeros(1, dtype=np.float64),
    }


def _student_forward(
    state: Dict[str, np.ndarray],
    x: np.ndarray,
    component_means: np.ndarray,
    component_stds: np.ndarray,
) -> Dict[str, np.ndarray]:
    z1 = x @ state["w1"] + state["b1"]
    a1 = np.maximum(z1, 0.0)
    res = x @ state["w_res"] + state["b_res"]
    h1 = a1 + res
    z2 = h1 @ state["w2"] + state["b2"]
    a2 = np.maximum(z2, 0.0)
    comp_scaled = a2 @ state["w_out"] + state["b_out"]
    comp = comp_scaled * component_stds + component_means
    component_score = comp @ COMPONENT_WEIGHTS.astype(np.float64)
    score_residual = (a2 @ state["w_score"] + state["b_score"]).reshape(-1)
    overall = component_score + score_residual
    return {
        "z1": z1,
        "a1": a1,
        "res": res,
        "h1": h1,
        "z2": z2,
        "a2": a2,
        "comp_scaled": comp_scaled,
        "comp": comp,
        "component_score": component_score,
        "score_residual": score_residual,
        "overall": overall,
    }


def _student_loss_and_grads(
    state: Dict[str, np.ndarray],
    x: np.ndarray,
    component_targets_scaled: np.ndarray,
    component_means: np.ndarray,
    component_stds: np.ndarray,
    y_true: np.ndarray,
    teacher_pred: np.ndarray,
    sample_weight: np.ndarray,
    comp_loss_weight: float,
    overall_loss_weight: float,
    distill_loss_weight: float,
    weight_decay: float,
) -> Tuple[Dict[str, np.ndarray], float]:
    cache = _student_forward(state, x, component_means, component_stds)
    sample_weight = sample_weight.astype(np.float64)
    weight_norm = np.maximum(sample_weight.sum(), 1e-6)

    diff_comp = cache["comp_scaled"] - component_targets_scaled
    comp_loss, grad_comp = _smooth_l1_loss_and_grad(diff_comp, beta=1.0)
    comp_loss = comp_loss * sample_weight[:, None]
    grad_comp = grad_comp * sample_weight[:, None] * (comp_loss_weight / weight_norm)

    diff_overall = cache["overall"] - y_true
    overall_loss, grad_overall_true = _smooth_l1_loss_and_grad(diff_overall, beta=5.0)
    overall_loss = overall_loss * sample_weight
    grad_overall_true = grad_overall_true * sample_weight * (overall_loss_weight / weight_norm)

    diff_distill = cache["overall"] - teacher_pred
    distill_loss, grad_overall_teacher = _smooth_l1_loss_and_grad(diff_distill, beta=5.0)
    distill_loss = distill_loss * sample_weight
    grad_overall_teacher = grad_overall_teacher * sample_weight * (distill_loss_weight / weight_norm)

    grad_overall = grad_overall_true + grad_overall_teacher
    grad_comp_from_overall = np.outer(grad_overall, COMPONENT_WEIGHTS.astype(np.float64))
    grad_comp_scaled = grad_comp + grad_comp_from_overall * component_stds

    grads = {
        "w_out": cache["a2"].T @ grad_comp_scaled + weight_decay * state["w_out"],
        "b_out": grad_comp_scaled.sum(axis=0),
        "w_score": cache["a2"].T @ grad_overall[:, None] + weight_decay * state["w_score"],
        "b_score": np.array([grad_overall.sum()], dtype=np.float64),
    }

    grad_a2 = grad_comp_scaled @ state["w_out"].T
    grad_a2 += grad_overall[:, None] @ state["w_score"].T
    grad_z2 = grad_a2 * (cache["z2"] > 0)
    grads["w2"] = cache["h1"].T @ grad_z2 + weight_decay * state["w2"]
    grads["b2"] = grad_z2.sum(axis=0)

    grad_h1 = grad_z2 @ state["w2"].T
    grad_res = grad_h1
    grad_a1 = grad_h1
    grad_z1 = grad_a1 * (cache["z1"] > 0)

    grads["w_res"] = x.T @ grad_res + weight_decay * state["w_res"]
    grads["b_res"] = grad_res.sum(axis=0)
    grads["w1"] = x.T @ grad_z1 + weight_decay * state["w1"]
    grads["b1"] = grad_z1.sum(axis=0)

    loss_value = float(
        (comp_loss.sum() + overall_loss.sum() + distill_loss.sum()) / weight_norm
        + 0.5
        * weight_decay
        * sum(float(np.sum(state[name] ** 2)) for name in ("w1", "w_res", "w2", "w_out", "w_score"))
    )
    return grads, loss_value


def _smooth_l1_loss_and_grad(diff: np.ndarray, beta: float) -> Tuple[np.ndarray, np.ndarray]:
    abs_diff = np.abs(diff)
    quadratic = abs_diff < beta
    loss = np.where(quadratic, 0.5 * (diff ** 2) / beta, abs_diff - 0.5 * beta)
    grad = np.where(quadratic, diff / beta, np.sign(diff))
    return loss, grad


def _init_adam_state(state: Dict[str, np.ndarray]) -> Dict[str, object]:
    return {
        "step": 0,
        "m": {key: np.zeros_like(value) for key, value in state.items()},
        "v": {key: np.zeros_like(value) for key, value in state.items()},
    }


def _adam_step(
    state: Dict[str, np.ndarray],
    grads: Dict[str, np.ndarray],
    optimizer_state: Dict[str, object],
    learning_rate: float,
) -> None:
    beta1 = 0.9
    beta2 = 0.999
    eps = 1e-8
    optimizer_state["step"] = int(optimizer_state["step"]) + 1
    step = int(optimizer_state["step"])
    m = optimizer_state["m"]
    v = optimizer_state["v"]

    for key, grad in grads.items():
        grad = np.clip(grad, -5.0, 5.0)
        m[key] = beta1 * m[key] + (1.0 - beta1) * grad
        v[key] = beta2 * v[key] + (1.0 - beta2) * (grad ** 2)
        m_hat = m[key] / (1.0 - beta1 ** step)
        v_hat = v[key] / (1.0 - beta2 ** step)
        state[key] -= learning_rate * m_hat / (np.sqrt(v_hat) + eps)


def _student_predict_overall(package: Dict[str, object], x: np.ndarray) -> np.ndarray:
    scaling = package["component_scaling"] if "component_scaling" in package else {
        "mean": package["component_means"],
        "std": package["component_stds"],
    }
    component_means = np.asarray(scaling["mean"], dtype=np.float64)
    component_stds = np.asarray(scaling["std"], dtype=np.float64)
    state = package["state"]
    cache = _student_forward(state, x, component_means, component_stds)
    return cache["overall"]


def _select_model_name(
    selection_policy: str,
    teacher_name: str,
    teacher_validation_mae: float,
    student_validation_mae: float,
) -> str:
    if selection_policy == "nn_only":
        return "student_residual_mlp"
    if selection_policy == "best_mae":
        return "student_residual_mlp" if student_validation_mae <= teacher_validation_mae else teacher_name
    raise ValueError(f"Unsupported selection_policy={selection_policy}")


def _predict_model(model_name: str, model_payload: object, x: np.ndarray) -> np.ndarray:
    if model_name == "xgboost":
        return model_payload.predict(x)  # type: ignore[no-any-return]
    if model_name == "huber":
        return model_payload.predict(x)  # type: ignore[no-any-return]
    if model_name == "mlp":
        if not isinstance(model_payload, dict):
            raise TypeError("MLP payload must be a dict with model/target stats.")
        model = model_payload.get("model")
        target_mean = float(model_payload.get("target_mean", 0.0))
        target_std = float(model_payload.get("target_std", 1.0))
        scaled_pred = model.predict(x)
        return scaled_pred * target_std + target_mean  # type: ignore[no-any-return]
    if model_name == "student_residual_mlp":
        if not isinstance(model_payload, dict):
            raise TypeError("Student payload must be dict-like.")
        return _student_predict_overall(model_payload, x)
    raise ValueError(f"Unsupported model_name={model_name}")


def _feature_missingness_report(features_df: pd.DataFrame) -> Dict[str, object]:
    missing = features_df.isna().mean().sort_values(ascending=False)
    return {
        "top_missing_features": {key: float(value) for key, value in missing.head(20).items()},
        "features_gt_20pct_missing": int((missing > 0.20).sum()),
        "features_gt_50pct_missing": int((missing > 0.50).sum()),
        "features_all_missing": int((missing == 1.0).sum()),
    }


def _target_distribution_report(target: np.ndarray) -> Dict[str, object]:
    series = pd.Series(target.astype(np.float64))
    quantiles = series.quantile([0.0, 0.01, 0.05, 0.25, 0.50, 0.75, 0.95, 0.99, 1.0])
    return {
        "mean": float(series.mean()),
        "std": float(series.std(ddof=0)),
        "quantiles": {str(key): float(value) for key, value in quantiles.items()},
        "rows_below_70_ratio": float(np.mean(series < LOW_SCORE_THRESHOLD)),
    }


def _aggregate_fold_reports(fold_reports: Sequence[Dict[str, object]]) -> Dict[str, float]:
    mae_values = np.array([float(report["mae"]) for report in fold_reports], dtype=np.float64)
    rmse_values = np.array([float(report["rmse"]) for report in fold_reports], dtype=np.float64)
    r2_values = np.array([float(report["r2"]) for report in fold_reports], dtype=np.float64)
    low_values = np.array([float(report["low_score_mae"]) for report in fold_reports], dtype=np.float64)
    per_user_values = np.array([float(report["per_user_mae_mean"]) for report in fold_reports], dtype=np.float64)
    summary = {
        "mae_mean": float(np.mean(mae_values)),
        "mae_std": float(np.std(mae_values)),
        "rmse_mean": float(np.mean(rmse_values)),
        "rmse_std": float(np.std(rmse_values)),
        "r2_mean": float(np.mean(r2_values)),
        "r2_std": float(np.std(r2_values)),
        "low_score_mae_mean": float(np.mean(low_values)),
        "per_user_mae_mean": float(np.mean(per_user_values)),
    }
    if fold_reports and "platform_mae_mean" in fold_reports[0]:
        platform_values = np.array(
            [float(report["platform_mae_mean"]) for report in fold_reports],
            dtype=np.float64,
        )
        ios_values = np.array(
            [float(report["ios_mae"]) for report in fold_reports],
            dtype=np.float64,
        )
        android_values = np.array(
            [float(report["android_mae"]) for report in fold_reports],
            dtype=np.float64,
        )
        summary["ios_mae_mean"] = float(np.mean(ios_values))
        summary["android_mae_mean"] = float(np.mean(android_values))
        summary["platform_mae_mean"] = float(np.mean(platform_values))
        summary["selection_score"] = float(
            summary["mae_mean"]
            + (STUDENT_PLATFORM_VALIDATION_WEIGHT * summary["platform_mae_mean"])
        )
        return summary
    summary["selection_score"] = float(summary["mae_mean"])
    return summary


def _extended_regression_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    groups: np.ndarray,
) -> Dict[str, float]:
    y_true = y_true.astype(np.float64)
    y_pred = y_pred.astype(np.float64)
    mae = float(mean_absolute_error(y_true, y_pred))
    rmse = float(np.sqrt(np.mean((y_true - y_pred) ** 2)))
    r2 = float(r2_score(y_true, y_pred)) if len(y_true) > 1 else 0.0
    low_mask = y_true < LOW_SCORE_THRESHOLD
    low_score_mae = float(mean_absolute_error(y_true[low_mask], y_pred[low_mask])) if np.any(low_mask) else mae

    per_user_maes: List[float] = []
    for group_key in np.unique(groups):
        mask = groups == group_key
        if not np.any(mask):
            continue
        per_user_maes.append(float(mean_absolute_error(y_true[mask], y_pred[mask])))
    per_user_mae_mean = float(np.mean(per_user_maes)) if per_user_maes else mae
    per_user_mae_std = float(np.std(per_user_maes)) if per_user_maes else 0.0

    return {
        "mae": mae,
        "rmse": rmse,
        "r2": r2,
        "low_score_mae": low_score_mae,
        "per_user_mae_mean": per_user_mae_mean,
        "per_user_mae_std": per_user_mae_std,
    }


def _secondary_unseen_user_report(
    features_df: pd.DataFrame,
    target: np.ndarray,
    component_targets: Dict[str, np.ndarray],
    groups: np.ndarray,
    sample_weights: np.ndarray,
    teacher_spec: Dict[str, object],
    student_spec: Dict[str, object],
    external_pretrain_bundle: Optional[ExternalPretrainBundle],
    external_pretrain_objective: str,
) -> Dict[str, object]:
    unique_groups = np.unique(groups)
    if len(unique_groups) < 4:
        return {"enabled": False, "reason": "not_enough_groups"}

    splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED + 101)
    train_idx, test_idx = next(splitter.split(np.arange(len(target)), groups=groups))
    x_train_raw = features_df.to_numpy(dtype=np.float64)[train_idx]
    x_test_raw = features_df.to_numpy(dtype=np.float64)[test_idx]
    x_train, medians, clip_low, clip_high, mean, std = _fit_preprocessor(
        x_train_raw,
        q_low=DEFAULT_CLIP_QUANTILE_LOW,
        q_high=DEFAULT_CLIP_QUANTILE_HIGH,
    )
    x_test = _transform_with_preprocessor(
        x_test_raw,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
    )
    feature_names = features_df.columns.tolist()
    modality_groups = _build_student_modality_groups(feature_names)
    missing_fill, missing_flag_on = _build_student_fill_vectors(
        feature_names=feature_names,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
    )
    teacher_model = _fit_teacher_model(
        spec=teacher_spec,
        x_train=x_train,
        y_train=target[train_idx],
        sample_weight=sample_weights[train_idx],
    )
    teacher_train = np.clip(_predict_model(teacher_spec["name"], teacher_model, x_train), 0, 100)
    encoder_init_state, pretrain_report = _prepare_external_encoder_init(
        external_pretrain_bundle=external_pretrain_bundle,
        feature_names=feature_names,
        medians=medians,
        clip_low=clip_low,
        clip_high=clip_high,
        mean=mean,
        std=std,
        hidden_dim=int(student_spec["hidden_dim"]),
        bottleneck_dim=int(student_spec["bottleneck_dim"]),
        objective=external_pretrain_objective,
        seed=int(student_spec["seed"]) + 909,
        enabled=bool(student_spec.get("init_mode") == "pretrained_init"),
    )
    student_model = _fit_student_model(
        config=student_spec,
        x_train=x_train,
        component_targets={key: values[train_idx] for key, values in component_targets.items()},
        y_train=target[train_idx],
        teacher_train=teacher_train,
        sample_weight=sample_weights[train_idx],
        encoder_init_state=encoder_init_state,
        feature_names=feature_names,
        modality_groups=modality_groups,
        missing_fill=missing_fill,
        missing_flag_on=missing_flag_on,
    )
    teacher_pred = np.clip(_predict_model(teacher_spec["name"], teacher_model, x_test), 0, 100)
    student_pred = np.clip(_predict_model("student_residual_mlp", student_model, x_test), 0, 100)
    report = {
        "enabled": True,
        "strategy": "group_shuffle_split_20pct",
        "teacher": _extended_regression_metrics(target[test_idx], teacher_pred, groups[test_idx]),
        "student": _extended_regression_metrics(target[test_idx], student_pred, groups[test_idx]),
    }
    if bool(student_spec.get("init_mode") == "pretrained_init"):
        report["student_pretraining"] = pretrain_report
    return report


def _build_parity_fixture(
    feature_names: Sequence[str],
    features_df: pd.DataFrame,
    preprocessor: Dict[str, List[float]],
    selected_model_name: str,
    selected_model: object,
    source_rows: Sequence[int],
) -> Dict[str, object]:
    if len(source_rows) == 0:
        raise RuntimeError("Cannot build parity fixture without source rows.")
    source_row = int(source_rows[0])
    raw_vector = features_df.iloc[source_row].to_numpy(dtype=np.float64)
    scaled = _transform_with_preprocessor(
        raw_vector.reshape(1, -1),
        medians=np.asarray(preprocessor["medians"], dtype=np.float64),
        clip_low=np.asarray(preprocessor["clip_low"], dtype=np.float64),
        clip_high=np.asarray(preprocessor["clip_high"], dtype=np.float64),
        mean=np.asarray(preprocessor["mean"], dtype=np.float64),
        std=np.asarray(preprocessor["std"], dtype=np.float64),
    )[0]
    prediction = float(_predict_model(selected_model_name, selected_model, scaled.reshape(1, -1))[0])
    return {
        "version": PREPROCESSOR_VERSION,
        "feature_names": list(feature_names),
        "source_row_index": source_row,
        "raw_features": {name: _json_safe_float(value) for name, value in zip(feature_names, raw_vector)},
        "scaled_input": scaled.tolist(),
        "expected_output": prediction,
        "selected_model": selected_model_name,
    }


def _json_safe_float(value: float) -> Optional[float]:
    if not np.isfinite(value):
        return None
    return float(value)


def _resolve_in_situ_missingness_threshold(config: BuildConfig) -> Optional[float]:
    if config.in_situ_missingness_threshold is not None:
        return float(config.in_situ_missingness_threshold)
    return None


def _aggregate_in_situ_missingness(values: np.ndarray, aggregation: str) -> float:
    values = values[np.isfinite(values)]
    if values.size == 0:
        return float("nan")
    if aggregation == "mean":
        return float(np.mean(values))
    if aggregation == "median":
        return float(np.median(values))
    raise ValueError(f"Unsupported in-situ missingness aggregation={aggregation}")


def _load_in_situ(config: BuildConfig) -> DatasetBundle:
    in_situ_dir = config.dataset_dir / "in_situ_28509740"
    in_situ_dir.mkdir(parents=True, exist_ok=True)
    hrv_file_name = str(config.in_situ_hrv_file)
    missingness_threshold = _resolve_in_situ_missingness_threshold(config)
    _ensure_in_situ_files(
        in_situ_dir,
        allow_download=config.allow_download,
        required_files=(hrv_file_name, *INSITU_REQUIRED_SHARED_FILES),
    )

    hrv = pd.read_csv(in_situ_dir / hrv_file_name, low_memory=False)
    diary = pd.read_csv(in_situ_dir / "sleep_diary.csv")
    survey = pd.read_csv(in_situ_dir / "survey.csv")

    if hrv.empty or diary.empty:
        raise RuntimeError("In-situ CSV files are empty.")

    hrv["ts_start"] = pd.to_numeric(hrv["ts_start"], errors="coerce")
    hrv["ts_end"] = pd.to_numeric(hrv["ts_end"], errors="coerce")
    hrv = hrv.dropna(subset=["deviceId", "ts_start", "ts_end"])

    numeric_cols = [
        "missingness_score",
        "HR",
        "ibi",
        "acc_x_avg",
        "acc_y_avg",
        "acc_z_avg",
        "steps",
        "distance",
        "calories",
        "light_avg",
        "sdnn",
        "sdsd",
        "rmssd",
        "pnn20",
        "pnn50",
        "lf",
        "hf",
        "lf/hf",
    ]
    for col in numeric_cols:
        if col in hrv.columns:
            hrv[col] = pd.to_numeric(hrv[col], errors="coerce")

    survey = survey.rename(columns={"deviceId": "device_id"})
    survey["device_id"] = survey["device_id"].astype(str)
    survey_map = survey.set_index("device_id").to_dict(orient="index")

    diary["date"] = pd.to_datetime(diary["date"], errors="coerce")
    diary = diary.dropna(subset=["date", "userId", "asleep", "wakeup"])

    rows: List[Dict[str, float]] = []
    target: List[float] = []
    groups: List[str] = []
    sample_dates: List[str] = []
    sample_weights: List[float] = []
    row_quality: List[float] = []
    component_targets: Dict[str, List[float]] = {
        "efficiency": [],
        "duration": [],
        "fragmentation": [],
    }

    hrv_by_device = {
        str(key): value.sort_values("ts_start").reset_index(drop=True)
        for key, value in hrv.groupby("deviceId")
    }

    diary_rows = diary.to_dict(orient="records")
    diary_by_device: Dict[str, List[Dict[str, object]]] = {}
    for item in diary_rows:
        device_id = str(item.get("userId", "")).strip()
        if not device_id:
            continue
        diary_by_device.setdefault(device_id, []).append(item)

    alignment_map: Dict[str, Dict[str, int]] = {}
    for device_id, device_diary in diary_by_device.items():
        series = hrv_by_device.get(device_id)
        if series is None or series.empty:
            continue
        alignment_map[device_id] = _find_best_alignment_for_device(
            device_diary=device_diary,
            device_series=series,
            min_segment_rows=MIN_SEGMENT_ROWS,
        )

    soft_weighted_low_alignment = 0
    filtered_high_missingness = 0
    alignment_qualities: List[float] = []
    night_missingness_values: List[float] = []
    for item in diary_rows:
        device_id = str(item.get("userId", "")).strip()
        if not device_id:
            continue
        series = hrv_by_device.get(device_id)
        alignment = alignment_map.get(device_id)
        if series is None or series.empty or alignment is None:
            continue

        start_dt, end_dt = _diary_sleep_window(item, day_shift=alignment["day_shift"])
        if start_dt is None or end_dt is None:
            continue
        start_ms, end_ms = _to_utc_ms(start_dt, end_dt, alignment["tz_offset_hours"])

        segment = series[(series["ts_start"] >= start_ms) & (series["ts_start"] <= end_ms)]
        if segment.empty or len(segment) < MIN_SEGMENT_ROWS:
            continue

        night_missingness = float("nan")
        if "missingness_score" in segment.columns:
            segment_missingness = (
                pd.to_numeric(segment["missingness_score"], errors="coerce")
                .dropna()
                .to_numpy(dtype=np.float64)
            )
            night_missingness = _aggregate_in_situ_missingness(
                segment_missingness,
                aggregation=config.in_situ_missingness_aggregation,
            )
        if (
            missingness_threshold is not None
            and np.isfinite(night_missingness)
            and night_missingness > missingness_threshold
        ):
            filtered_high_missingness += 1
            continue
        if np.isfinite(night_missingness):
            night_missingness_values.append(float(night_missingness))

        feat: Dict[str, float] = {}
        for col in numeric_cols:
            if col not in segment.columns:
                continue
            values = pd.to_numeric(segment[col], errors="coerce").dropna().to_numpy(dtype=np.float64)
            _add_numeric_stats(feat, col, values)

        segment_minutes = (segment["ts_end"] - segment["ts_start"]).median() / 60000.0
        if not np.isfinite(segment_minutes) or segment_minutes <= 0:
            segment_minutes = 5.0
        feat["window_count"] = float(len(segment))
        feat["coverage_hours"] = float((len(segment) * segment_minutes) / 60.0)
        feat["window_density"] = float(len(segment) / max((end_ms - start_ms) / 60000.0, 1.0))
        feat["sleep_window_hours_clock"] = float((end_ms - start_ms) / 3_600_000.0)

        asleep_hour = _to_hour_fraction(_parse_clock(str(item.get("asleep", ""))))
        wakeup_hour = _to_hour_fraction(_parse_clock(str(item.get("wakeup", ""))))
        feat["asleep_hour"] = float(asleep_hour if asleep_hour is not None else np.nan)
        feat["wakeup_hour"] = float(wakeup_hour if wakeup_hour is not None else np.nan)
        feat["weekday"] = float(start_dt.weekday())
        feat["alignment_tz_offset_hours"] = float(alignment["tz_offset_hours"])
        feat["alignment_day_shift"] = float(alignment["day_shift"])

        feat["diary_sleep_duration_h"] = _safe_float(item.get("sleep_duration"))
        feat["diary_in_bed_h"] = _safe_float(item.get("in_bed_duration"))
        feat["diary_sleep_latency_h"] = _safe_float(item.get("sleep_latency"))
        feat["diary_waso_min"] = _safe_float(item.get("waso"))
        feat["diary_wakeup_count"] = _safe_float(item.get("wakeup@night"))
        feat["diary_sleep_efficiency"] = _safe_float(item.get("sleep_efficiency"))

        hr_values = pd.to_numeric(segment.get("HR"), errors="coerce").dropna().to_numpy(dtype=np.float64)
        time_values = pd.to_numeric(segment.get("ts_start"), errors="coerce").dropna().to_numpy(dtype=np.float64)
        feat["hr_trend"] = _safe_trend_slope(hr_values, time_values)
        _set_modality_missing_flags(
            feat,
            hr_present=hr_values.size > 0,
            steps_present=_count_finite(segment.get("steps")) > 0,
            distance_present=_count_finite(segment.get("distance")) > 0,
            calories_present=_count_finite(segment.get("calories")) > 0,
            sdnn_present=_count_finite(segment.get("sdnn")) > 0,
            rmssd_present=_count_finite(segment.get("rmssd")) > 0,
        )
        _add_engineered_health_features(feat)

        demographics = survey_map.get(device_id, {})
        for key in ("sex", "age", "exercise", "coffee", "smoking", "drinking", "height", "weight"):
            feat[f"survey_{key}"] = _safe_float(demographics.get(key))

        quality = _quality_components_from_diary(item)
        if quality is None:
            continue

        device_diary_count = max(len(diary_by_device.get(device_id, [])), 1)
        hit_ratio = float(alignment.get("hits", 0)) / device_diary_count
        coverage_ratio = float(np.clip(feat["coverage_hours"] / max(feat["sleep_window_hours_clock"], 1e-6), 0.0, 1.0))
        density_ratio = float(np.clip(len(segment) / max(MIN_SEGMENT_ROWS * 2, 1), 0.0, 1.0))
        alignment_quality = float(np.clip((0.50 * coverage_ratio) + (0.30 * density_ratio) + (0.20 * hit_ratio), 0.0, 1.0))
        if alignment_quality < LOW_ALIGNMENT_QUALITY_REFERENCE:
            soft_weighted_low_alignment += 1
        alignment_qualities.append(alignment_quality)

        feat["__device_id"] = device_id  # type: ignore[assignment]
        feat["__night_date"] = start_dt.date().isoformat()  # type: ignore[assignment]

        rows.append(feat)
        target.append(float(quality["overall"]))
        component_targets["efficiency"].append(float(quality["efficiency"]))
        component_targets["duration"].append(float(quality["duration"]))
        component_targets["fragmentation"].append(float(quality["fragmentation"]))
        groups.append(device_id)
        sample_dates.append(start_dt.date().isoformat())
        signal_quality = (
            float(np.clip(1.0 - night_missingness, 0.0, 1.0))
            if np.isfinite(night_missingness)
            else 1.0
        )
        row_quality_score = float(np.clip(alignment_quality * signal_quality, 0.0, 1.0))
        combined_weight = float(np.clip(0.10 + (0.90 * row_quality_score), 0.1, 1.0))
        row_quality.append(row_quality_score)
        sample_weights.append(combined_weight)

    if not rows:
        raise RuntimeError("In-situ preprocessing produced zero rows.")

    features_df = pd.DataFrame(rows).replace([np.inf, -np.inf], np.nan)
    features_df["__row_order"] = np.arange(len(features_df))
    features_df = _augment_personal_baseline_features(features_df)
    features_df = features_df.drop(columns=["__device_id", "__night_date", "__row_order"], errors="ignore")

    covered = len(features_df)
    diary_count = len(diary_rows)
    alignment_summary = {
        "hrv_file": hrv_file_name,
        "night_missingness_threshold": missingness_threshold,
        "night_missingness_aggregation": config.in_situ_missingness_aggregation,
        "missingness_column_available": bool("missingness_score" in hrv.columns),
        "rows_with_night_missingness": int(len(night_missingness_values)),
        "devices_with_alignment": len(alignment_map),
        "coverage_ratio": round(covered / max(diary_count, 1), 4),
        "rows_after_alignment": covered,
        "rows_filtered_low_alignment": 0,
        "rows_soft_weighted_low_alignment": soft_weighted_low_alignment,
        "rows_filtered_high_missingness": filtered_high_missingness,
        "alignment_quality_mean": float(np.mean(alignment_qualities)) if alignment_qualities else 0.0,
        "alignment_quality_p10": float(np.percentile(alignment_qualities, 10)) if alignment_qualities else 0.0,
        "night_missingness_mean": float(np.mean(night_missingness_values)) if night_missingness_values else None,
        "night_missingness_p90": float(np.percentile(night_missingness_values, 90)) if night_missingness_values else None,
        "diary_rows_total": diary_count,
    }
    return DatasetBundle(
        source="in_situ_28509740",
        features=features_df,
        target=np.array(target, dtype=np.float64),
        groups=np.array(groups),
        rows=len(features_df),
        metadata=alignment_summary,
        sample_dates=np.array(sample_dates),
        component_targets={key: np.array(values, dtype=np.float64) for key, values in component_targets.items()},
        sample_weights=np.array(sample_weights, dtype=np.float64),
        row_quality=np.array(row_quality, dtype=np.float64),
    )


def _count_finite(series: object) -> int:
    if series is None:
        return 0
    values = pd.to_numeric(series, errors="coerce")
    return int(np.isfinite(values.to_numpy(dtype=np.float64)).sum())


def _diary_sleep_window(
    row: Dict[str, object],
    day_shift: int = 0,
) -> Tuple[Optional[datetime], Optional[datetime]]:
    date_value = row.get("date")
    if not isinstance(date_value, (pd.Timestamp, datetime)):
        return None, None
    base_date = (pd.Timestamp(date_value) + pd.Timedelta(days=day_shift)).to_pydatetime().date()

    asleep_clock = _parse_clock(str(row.get("asleep", "")))
    wakeup_clock = _parse_clock(str(row.get("wakeup", "")))
    if asleep_clock is None or wakeup_clock is None:
        return None, None

    start_dt = datetime.combine(base_date, asleep_clock)
    end_dt = datetime.combine(base_date, wakeup_clock)
    if end_dt <= start_dt:
        end_dt += timedelta(days=1)
    return start_dt, end_dt


def _to_utc_ms(start_local: datetime, end_local: datetime, tz_offset_hours: int) -> Tuple[int, int]:
    start_ms = int((start_local - timedelta(hours=tz_offset_hours)).timestamp() * 1000)
    end_ms = int((end_local - timedelta(hours=tz_offset_hours)).timestamp() * 1000)
    return start_ms, end_ms


def _quality_components_from_diary(row: Dict[str, object]) -> Optional[Dict[str, float]]:
    eff = _safe_float(row.get("sleep_efficiency"))
    dur = _safe_float(row.get("sleep_duration"))
    in_bed = _safe_float(row.get("in_bed_duration"))
    latency_h = _safe_float(row.get("sleep_latency"))
    waso_min = _safe_float(row.get("waso"))
    wake_count = _safe_float(row.get("wakeup@night"))

    if np.isnan(eff) and not np.isnan(dur) and not np.isnan(in_bed) and in_bed > 0:
        eff = dur / in_bed
    if np.isnan(eff) or np.isnan(dur):
        return None

    eff = float(np.clip(eff, 0, 1))
    dur = float(np.clip(dur, 0, 14))
    latency_h = 0.0 if np.isnan(latency_h) else max(0.0, latency_h)
    waso_min = 0.0 if np.isnan(waso_min) else max(0.0, waso_min)
    wake_count = 0.0 if np.isnan(wake_count) else max(0.0, wake_count)

    duration_score = 1.0 - min(abs(dur - 8.0) / 4.0, 1.0)
    latency_score = 1.0 - min(latency_h / 2.0, 1.0)
    waso_score = 1.0 - min((waso_min / 60.0) / 2.0, 1.0)
    awaken_score = 1.0 - min(wake_count / 5.0, 1.0)
    # Sleep latency is weakly observable from package:health signals, so keep only
    # a small contribution in fragmentation and remove it from the production target.
    fragmentation_score = (0.10 * latency_score) + (0.45 * waso_score) + (0.45 * awaken_score)

    score = 100.0 * (
        0.50 * eff
        + 0.30 * duration_score
        + 0.10 * waso_score
        + 0.10 * awaken_score
    )
    return {
        "overall": float(np.clip(score, 0.0, 100.0)),
        "efficiency": float(np.clip(100.0 * eff, 0.0, 100.0)),
        "duration": float(np.clip(100.0 * duration_score, 0.0, 100.0)),
        "fragmentation": float(np.clip(100.0 * fragmentation_score, 0.0, 100.0)),
    }


def _find_best_alignment_for_device(
    device_diary: Sequence[Dict[str, object]],
    device_series: pd.DataFrame,
    min_segment_rows: int,
) -> Dict[str, int]:
    ts = pd.to_numeric(device_series["ts_start"], errors="coerce").dropna().to_numpy(dtype=np.int64)
    if ts.size == 0:
        return {"day_shift": 0, "tz_offset_hours": 0, "hits": 0}
    ts.sort()

    best_score = -1
    best = {"day_shift": 0, "tz_offset_hours": 0, "hits": 0}

    for day_shift in (-1, 0, 1):
        for tz in range(-12, 13):
            hits = 0
            points = 0
            for row in device_diary:
                start_dt, end_dt = _diary_sleep_window(row, day_shift=day_shift)
                if start_dt is None or end_dt is None:
                    continue
                start_ms, end_ms = _to_utc_ms(start_dt, end_dt, tz)
                left = int(np.searchsorted(ts, start_ms, side="left"))
                right = int(np.searchsorted(ts, end_ms, side="right"))
                count = max(0, right - left)
                points += count
                if count >= min_segment_rows:
                    hits += 1
            score = hits * 100000 + points
            if score > best_score:
                best_score = score
                best = {"day_shift": day_shift, "tz_offset_hours": tz, "hits": hits}
    return best


def _augment_personal_baseline_features(features_df: pd.DataFrame) -> pd.DataFrame:
    if "__device_id" not in features_df.columns or "__night_date" not in features_df.columns:
        return features_df

    df = features_df.copy()
    if "__row_order" not in df.columns:
        df["__row_order"] = np.arange(len(df))
    df["__night_date"] = pd.to_datetime(df["__night_date"], errors="coerce")
    df = df.sort_values(["__device_id", "__night_date"]).reset_index(drop=True)

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
        shifted = df.groupby("__device_id")[col].shift(1)
        roll_mean = (
            shifted.groupby(df["__device_id"])
            .rolling(window=7, min_periods=3)
            .mean()
            .reset_index(level=0, drop=True)
        )
        roll_std = (
            shifted.groupby(df["__device_id"])
            .rolling(window=7, min_periods=3)
            .std()
            .reset_index(level=0, drop=True)
        )
        df[f"{col}_baseline7"] = roll_mean
        df[f"{col}_delta7"] = df[col] - roll_mean
        df[f"{col}_z7"] = (df[col] - roll_mean) / (roll_std + 1e-6)

    df["nights_since_start"] = df.groupby("__device_id").cumcount().astype(float)
    df = df.sort_values("__row_order").reset_index(drop=True)
    return df


def _safe_trend_slope(values: np.ndarray, timestamps_ms: np.ndarray) -> float:
    if values.size < 3 or timestamps_ms.size < 3:
        return 0.0
    mask = np.isfinite(values) & np.isfinite(timestamps_ms)
    if mask.sum() < 3:
        return 0.0
    x = timestamps_ms[mask].astype(np.float64)
    y = values[mask].astype(np.float64)
    x = (x - x.mean()) / 1000.0
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


def _ensure_in_situ_files(
    in_situ_dir: Path,
    allow_download: bool,
    required_files: Optional[Sequence[str]] = None,
) -> None:
    files_to_check = tuple(required_files) if required_files is not None else (
        INSITU_DEFAULT_HRV_FILE,
        *INSITU_REQUIRED_SHARED_FILES,
    )
    missing = [name for name in files_to_check if not (in_situ_dir / name).exists()]
    if not missing:
        return
    if not allow_download:
        raise RuntimeError(
            f"Missing required In-situ files: {missing}. Enable downloads or place files manually."
        )

    response = requests.get(FIGSHARE_API_URL, timeout=30)
    response.raise_for_status()
    payload = response.json()
    file_map = {item["name"]: item["download_url"] for item in payload.get("files", [])}

    for file_name in missing:
        url = file_map.get(file_name)
        if not url:
            raise RuntimeError(f"Cannot find {file_name} in Figshare article {FIGSHARE_ARTICLE_ID}.")
        _download_file(url, in_situ_dir / file_name)


def _load_sleep_accel(dataset_dir: Path, allow_download: bool) -> DatasetBundle:
    accel_dir = dataset_dir / "sleep_accel"
    accel_dir.mkdir(parents=True, exist_ok=True)
    _ensure_sleep_accel_files(accel_dir, allow_download=allow_download)

    label_files = sorted((accel_dir / "labels").glob("*_labeled_sleep.txt"))
    if not label_files:
        raise RuntimeError("No label files in sleep-accel dataset.")

    rows: List[Dict[str, float]] = []
    target: List[float] = []
    groups: List[str] = []
    component_targets: Dict[str, List[float]] = {
        "efficiency": [],
        "duration": [],
        "fragmentation": [],
    }

    for label_path in label_files:
        subject = label_path.name.split("_", 1)[0]
        hr_path = accel_dir / "heart_rate" / f"{subject}_heartrate.txt"
        steps_path = accel_dir / "steps" / f"{subject}_steps.txt"
        if not hr_path.exists() or not steps_path.exists():
            continue

        labels = pd.read_csv(label_path, sep=r"\s+", names=["offset", "stage"], engine="python")
        hr = pd.read_csv(hr_path, names=["offset", "hr"])
        steps = pd.read_csv(steps_path, names=["offset", "steps"])
        if labels.empty or hr.empty or steps.empty:
            continue

        label_stats = _sleep_accel_label_stats(labels["stage"].to_numpy(dtype=np.int64))
        score = _sleep_accel_quality(label_stats)
        if score is None:
            continue
        components = _sleep_accel_component_scores(label_stats)

        feat: Dict[str, float] = {}
        hr_values = pd.to_numeric(hr["hr"], errors="coerce").dropna().to_numpy(dtype=np.float64)
        _add_numeric_stats(feat, "HR", hr_values)
        steps_values = pd.to_numeric(steps["steps"], errors="coerce").dropna().to_numpy(dtype=np.float64)
        _add_numeric_stats(feat, "steps", steps_values)
        _add_numeric_stats(feat, "distance", np.array([], dtype=np.float64))
        _add_numeric_stats(feat, "calories", np.array([], dtype=np.float64))
        _add_numeric_stats(feat, "sdnn", np.array([], dtype=np.float64))
        _add_numeric_stats(feat, "rmssd", np.array([], dtype=np.float64))
        feat["window_count"] = float(len(hr_values))
        feat["coverage_hours"] = float(len(labels) * 30.0 / 3600.0)
        feat["window_density"] = feat["window_count"] / max(float(len(labels) * 30.0 / 60.0), 1.0)
        feat["sleep_window_hours_clock"] = float(label_stats.get("sleep_hours", 0.0))
        feat["asleep_hour"] = float("nan")
        feat["wakeup_hour"] = float("nan")
        feat["weekday"] = float("nan")
        feat["hr_trend"] = 0.0
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
        target.append(float(score))
        component_targets["efficiency"].append(float(components["efficiency"]))
        component_targets["duration"].append(float(components["duration"]))
        component_targets["fragmentation"].append(float(components["fragmentation"]))
        groups.append(subject)

    if not rows:
        raise RuntimeError("Sleep-accel preprocessing produced zero rows.")

    features_df = pd.DataFrame(rows).replace([np.inf, -np.inf], np.nan)
    return DatasetBundle(
        source="sleep_accel_physionet",
        features=features_df,
        target=np.array(target, dtype=np.float64),
        groups=np.array(groups),
        rows=len(features_df),
        metadata={
            "devices_with_alignment": 0,
            "coverage_ratio": 1.0,
            "rows_after_alignment": len(features_df),
            "rows_filtered_low_alignment": 0,
            "alignment_quality_mean": 1.0,
            "alignment_quality_p10": 1.0,
            "diary_rows_total": len(features_df),
        },
        sample_dates=None,
        component_targets={key: np.array(values, dtype=np.float64) for key, values in component_targets.items()},
        sample_weights=np.ones(len(features_df), dtype=np.float64),
        row_quality=np.ones(len(features_df), dtype=np.float64),
    )


def _sleep_accel_label_stats(stage_values: np.ndarray) -> Dict[str, float]:
    total = len(stage_values)
    if total == 0:
        return {}

    sleep_mask = stage_values != 0
    sleep_epochs = int(sleep_mask.sum())
    sleep_hours = float(sleep_epochs * 30.0 / 3600.0)
    deep_epochs = int((stage_values == 3).sum())
    rem_epochs = int(((stage_values == 4) | (stage_values == 5)).sum())
    deep_ratio = float(deep_epochs / max(sleep_epochs, 1))
    rem_ratio = float(rem_epochs / max(sleep_epochs, 1))
    efficiency = float(sleep_epochs / total)
    awakenings = int(((~sleep_mask) & np.roll(sleep_mask, 1)).sum())
    if total > 0:
        awakenings = max(0, awakenings - int(sleep_mask[0]))
    return {
        "efficiency": efficiency,
        "sleep_hours": sleep_hours,
        "deep_ratio": deep_ratio,
        "rem_ratio": rem_ratio,
        "awakenings": float(awakenings),
    }


def _sleep_accel_quality(stats: Dict[str, float]) -> Optional[float]:
    if not stats:
        return None
    eff = float(np.clip(stats["efficiency"], 0.0, 1.0))
    sleep_hours = max(0.0, stats["sleep_hours"])
    deep_ratio = max(0.0, stats["deep_ratio"])
    rem_ratio = max(0.0, stats["rem_ratio"])
    awakenings = max(0.0, stats["awakenings"])

    duration_score = 1.0 - min(abs(sleep_hours - 8.0) / 4.0, 1.0)
    deep_score = min(deep_ratio / 0.20, 1.0)
    rem_score = min(rem_ratio / 0.20, 1.0)
    awaken_score = 1.0 - min(awakenings / 8.0, 1.0)
    score = 100.0 * (
        0.45 * eff
        + 0.20 * duration_score
        + 0.15 * deep_score
        + 0.10 * rem_score
        + 0.10 * awaken_score
    )
    return float(np.clip(score, 0.0, 100.0))


def _sleep_accel_component_scores(stats: Dict[str, float]) -> Dict[str, float]:
    eff = float(np.clip(stats.get("efficiency", 0.0), 0.0, 1.0))
    sleep_hours = max(0.0, float(stats.get("sleep_hours", 0.0)))
    awakenings = max(0.0, float(stats.get("awakenings", 0.0)))
    duration_score = 1.0 - min(abs(sleep_hours - 8.0) / 4.0, 1.0)
    fragmentation_score = 1.0 - min(awakenings / 8.0, 1.0)
    return {
        "efficiency": float(np.clip(100.0 * eff, 0.0, 100.0)),
        "duration": float(np.clip(100.0 * duration_score, 0.0, 100.0)),
        "fragmentation": float(np.clip(100.0 * fragmentation_score, 0.0, 100.0)),
    }


def _ensure_sleep_accel_files(base_dir: Path, allow_download: bool) -> None:
    for folder in SLEEP_ACCEL_DIRS:
        (base_dir / folder).mkdir(parents=True, exist_ok=True)
    if any((base_dir / "labels").glob("*_labeled_sleep.txt")):
        return
    if not allow_download:
        raise RuntimeError("Sleep-accel files missing and download disabled.")
    for folder in SLEEP_ACCEL_DIRS:
        remote_dir = f"{SLEEP_ACCEL_BASE}/{folder}/"
        names = _list_remote_files(remote_dir, suffix=".txt")
        if not names:
            raise RuntimeError(f"No files discovered at {remote_dir}")
        for name in names:
            destination = base_dir / folder / name
            if destination.exists():
                continue
            _download_file(f"{remote_dir}{name}", destination)


def _list_remote_files(url: str, suffix: str) -> List[str]:
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    html = response.text
    matches = re.findall(r'href="([^"]+)"', html)
    return sorted({name.strip() for name in matches if name.strip().endswith(suffix)})


def _download_file(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        with destination.open("wb") as out:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    out.write(chunk)


def _impute_with_median(x: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    x = np.where(np.isfinite(x), x, np.nan)
    medians = np.nanmedian(x, axis=0)
    medians = np.where(np.isnan(medians), 0.0, medians)
    x_imputed = np.where(np.isnan(x), medians, x)
    return x_imputed, medians


def _clip_bounds_from_train(
    x_train_imputed: np.ndarray,
    q_low: float,
    q_high: float,
) -> Tuple[np.ndarray, np.ndarray]:
    if q_low < 0 or q_high > 1 or q_low >= q_high:
        raise ValueError(f"Invalid clip quantiles: q_low={q_low}, q_high={q_high}")
    col_min = np.nanmin(x_train_imputed, axis=0)
    col_max = np.nanmax(x_train_imputed, axis=0)
    clip_low = np.nanquantile(x_train_imputed, q_low, axis=0)
    clip_high = np.nanquantile(x_train_imputed, q_high, axis=0)
    clip_low = np.where(np.isfinite(clip_low), clip_low, col_min)
    clip_high = np.where(np.isfinite(clip_high), clip_high, col_max)
    clip_low = np.minimum(clip_low, clip_high)
    return clip_low, clip_high


def _clip_array(x: np.ndarray, clip_low: np.ndarray, clip_high: np.ndarray) -> np.ndarray:
    return np.minimum(np.maximum(x, clip_low), clip_high)


def _standardize(x: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    mean = x.mean(axis=0)
    std = x.std(axis=0)
    std = np.where(std < 1e-8, 1.0, std)
    x_scaled = (x - mean) / std
    return x_scaled, mean, std


def _fit_preprocessor(
    x_train_raw: np.ndarray,
    q_low: float,
    q_high: float,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    x_train_imputed, medians = _impute_with_median(x_train_raw)
    clip_low, clip_high = _clip_bounds_from_train(
        x_train_imputed=x_train_imputed,
        q_low=q_low,
        q_high=q_high,
    )
    x_train_clipped = _clip_array(x_train_imputed, clip_low, clip_high)
    x_train_scaled, mean, std = _standardize(x_train_clipped)
    return x_train_scaled, medians, clip_low, clip_high, mean, std


def _transform_with_preprocessor(
    x_raw: np.ndarray,
    medians: np.ndarray,
    clip_low: np.ndarray,
    clip_high: np.ndarray,
    mean: np.ndarray,
    std: np.ndarray,
) -> np.ndarray:
    x = np.where(np.isfinite(x_raw), x_raw, np.nan)
    x_imputed = np.where(np.isnan(x), medians, x)
    x_clipped = _clip_array(x_imputed, clip_low, clip_high)
    std_safe = np.where(np.abs(std) < 1e-8, 1.0, std)
    return (x_clipped - mean) / std_safe


def _export_onnx(model_name: str, model: object, feature_count: int, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if model_name == "xgboost":
        onnx_model = onnxmltools.convert_xgboost(
            model,  # type: ignore[arg-type]
            initial_types=[(INPUT_NAME, OnnxFloatTensorType([None, feature_count]))],
            target_opset=14,
        )
    elif model_name == "mlp":
        onnx_model = convert_sklearn(
            model,  # type: ignore[arg-type]
            initial_types=[(INPUT_NAME, SkFloatTensorType([None, feature_count]))],
            target_opset=14,
        )
    elif model_name == "student_residual_mlp":
        onnx_model = _build_student_onnx_graph(model, feature_count)
    else:
        raise ValueError(f"Unsupported model_name for ONNX export: {model_name}")

    with output_path.open("wb") as file:
        file.write(onnx_model.SerializeToString())


def _build_student_onnx_graph(model: object, feature_count: int) -> onnx.ModelProto:
    if not isinstance(model, dict) or model.get("model_type") != "student_residual_mlp":
        raise TypeError("Student ONNX export expects student_residual_mlp dict payload.")
    state = model["state"]
    component_scaling = model["component_scaling"]

    initializers = [
        numpy_helper.from_array(np.asarray(state["w1"], dtype=np.float32), name="w1"),
        numpy_helper.from_array(np.asarray(state["b1"], dtype=np.float32), name="b1"),
        numpy_helper.from_array(np.asarray(state["w_res"], dtype=np.float32), name="w_res"),
        numpy_helper.from_array(np.asarray(state["b_res"], dtype=np.float32), name="b_res"),
        numpy_helper.from_array(np.asarray(state["w2"], dtype=np.float32), name="w2"),
        numpy_helper.from_array(np.asarray(state["b2"], dtype=np.float32), name="b2"),
        numpy_helper.from_array(np.asarray(state["w_out"], dtype=np.float32), name="w_out"),
        numpy_helper.from_array(np.asarray(state["b_out"], dtype=np.float32), name="b_out"),
        numpy_helper.from_array(np.asarray(state["w_score"], dtype=np.float32), name="w_score"),
        numpy_helper.from_array(np.asarray(state["b_score"], dtype=np.float32), name="b_score"),
        numpy_helper.from_array(np.asarray(component_scaling["std"], dtype=np.float32), name="component_std"),
        numpy_helper.from_array(np.asarray(component_scaling["mean"], dtype=np.float32), name="component_mean"),
        numpy_helper.from_array(COMPONENT_WEIGHTS.reshape(3, 1).astype(np.float32), name="agg_w"),
        numpy_helper.from_array(np.zeros((1,), dtype=np.float32), name="agg_b"),
    ]

    nodes = [
        helper.make_node("Gemm", [INPUT_NAME, "w1", "b1"], ["z1"], name="dense1"),
        helper.make_node("Relu", ["z1"], ["a1"], name="relu1"),
        helper.make_node("Gemm", [INPUT_NAME, "w_res", "b_res"], ["res"], name="residual"),
        helper.make_node("Add", ["a1", "res"], ["h1"], name="residual_add"),
        helper.make_node("Gemm", ["h1", "w2", "b2"], ["z2"], name="dense2"),
        helper.make_node("Relu", ["z2"], ["a2"], name="relu2"),
        helper.make_node("Gemm", ["a2", "w_out", "b_out"], ["component_scaled"], name="dense_out"),
        helper.make_node("Mul", ["component_scaled", "component_std"], ["component_scaled_std"], name="scale_components"),
        helper.make_node("Add", ["component_scaled_std", "component_mean"], ["component_pred"], name="shift_components"),
        helper.make_node("Gemm", ["component_pred", "agg_w", "agg_b"], ["component_score"], name="aggregate_score"),
        helper.make_node("Gemm", ["a2", "w_score", "b_score"], ["score_residual"], name="score_residual"),
        helper.make_node("Add", ["component_score", "score_residual"], ["score"], name="final_score"),
    ]

    graph = helper.make_graph(
        nodes,
        "sleep_quality_student",
        [helper.make_tensor_value_info(INPUT_NAME, TensorProto.FLOAT, [None, feature_count])],
        [helper.make_tensor_value_info("score", TensorProto.FLOAT, [None, 1])],
        initializer=initializers,
    )
    model_proto = helper.make_model(graph, producer_name="medi_ai_sleep_student")
    model_proto.opset_import[0].version = 14
    # Some mobile ONNX Runtime builds bundled in Flutter support IR<=9 only.
    model_proto.ir_version = 9
    onnx.checker.check_model(model_proto)
    return model_proto


def _add_numeric_stats(target: Dict[str, float], prefix: str, values: np.ndarray) -> None:
    if values.size == 0:
        target[f"{prefix}_mean"] = float("nan")
        target[f"{prefix}_std"] = float("nan")
        target[f"{prefix}_min"] = float("nan")
        target[f"{prefix}_max"] = float("nan")
        target[f"{prefix}_p10"] = float("nan")
        target[f"{prefix}_p90"] = float("nan")
        return
    values = values.astype(np.float64)
    target[f"{prefix}_mean"] = float(np.nanmean(values))
    target[f"{prefix}_std"] = float(np.nanstd(values))
    target[f"{prefix}_min"] = float(np.nanmin(values))
    target[f"{prefix}_max"] = float(np.nanmax(values))
    target[f"{prefix}_p10"] = float(np.nanpercentile(values, 10))
    target[f"{prefix}_p90"] = float(np.nanpercentile(values, 90))


def _parse_clock(raw: str) -> Optional[time]:
    value = raw.strip()
    if not value:
        return None
    for fmt in ("%H:%M:%S", "%H:%M"):
        try:
            return datetime.strptime(value, fmt).time()
        except ValueError:
            continue
    return None


def _to_hour_fraction(clock: Optional[time]) -> Optional[float]:
    if clock is None:
        return None
    return clock.hour + (clock.minute / 60.0) + (clock.second / 3600.0)


def _safe_float(value: object) -> float:
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return float("nan")
    if np.isnan(numeric):
        return float("nan")
    return numeric


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _write_json(path: Path, payload: Dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
