#!/usr/bin/env python3
"""Build Harvard Apple Watch model artifacts for Flutter inference.

Outputs:
  - assets/models/harvard_aw/model_harvardAWData_xgboost.onnx
  - assets/models/harvard_aw/preprocessor_v1.json
  - assets/models/harvard_aw/preprocessor_v2.json
  - assets/models/harvard_aw/model_metadata.json
  - build/ml/harvard_aw/model_xgboost.joblib
  - build/ml/harvard_aw/split_manifest.json
  - build/ml/harvard_aw/training_report.json
  - build/ml/harvard_aw/parity_fixture_v2.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import joblib
import numpy as np
import onnxmltools
import pandas as pd
import xgboost as xgb
from onnxmltools.convert.common.data_types import FloatTensorType
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    log_loss,
)
from sklearn.model_selection import GroupShuffleSplit, StratifiedShuffleSplit
from sklearn.preprocessing import OneHotEncoder, StandardScaler


MODEL_VERSION = "harvard-aw-xgb-v2"
INPUT_NAME = "float_input"
FEATURE_ENGINEERING_VERSION = "harvard-fe-v2"
PREPROCESSOR_V2_VERSION = "harvard-preprocessor-v2"
TARGET_COL = "activity_trimmed"
DEFAULT_SEED = 42
DEFAULT_TEST_SIZE = 0.10
DEFAULT_VAL_SIZE = 0.20
DEFAULT_EARLY_STOPPING_ROUNDS = 30
DEFAULT_PARITY_SAMPLES = 8
GROUP_COLUMN_CANDIDATES = (
    "participant_id",
    "subject_id",
    "participant",
    "subject",
    "session_id",
    "session",
)

BEST_PARAMS = {
    "n_estimators": 412,
    "max_depth": 7,
    "learning_rate": 0.05259189873268501,
    "subsample": 0.6273436115554192,
    "colsample_bytree": 0.8601696737189636,
    "min_child_weight": 1,
    "gamma": 0.03924923021690026,
    "reg_alpha": 0.03073470465028678,
    "reg_lambda": 0.9428595026044732,
    "scale_pos_weight": 1.7662945534315597,
}


@dataclass
class BuildConfig:
    dataset_path: Path
    output_dir: Path
    report_dir: Path
    seed: int = DEFAULT_SEED
    test_size: float = DEFAULT_TEST_SIZE
    val_size: float = DEFAULT_VAL_SIZE
    early_stopping_rounds: int = DEFAULT_EARLY_STOPPING_ROUNDS
    parity_samples: int = DEFAULT_PARITY_SAMPLES


@dataclass
class SplitResult:
    train_idx: np.ndarray
    val_idx: np.ndarray
    test_idx: np.ndarray
    strategy: str
    group_column: Optional[str]
    unique_groups: int
    group_overlap_check: bool
    manifest: Dict[str, Any]


class AppleWatchSyntheticFeatures:
    def __init__(
        self,
        intensity_params: Optional[Dict[str, float]] = None,
        sd_normalized_span: int = 3,
        correlation_window: int = 30,
    ) -> None:
        self.intensity_params = intensity_params or {
            "weight_hr": 0.90,
            "hr_max": 80.0,
            "steps_max": 50.0,
            "scale": 0.791,
            "offset": -0.079,
        }
        self.sd_normalized_span = sd_normalized_span
        self.correlation_window = correlation_window
        self._fitted = False

    def fit(self, df: pd.DataFrame) -> "AppleWatchSyntheticFeatures":
        required_cols = [
            "age",
            "gender",
            "height",
            "weight",
            "Applewatch.Steps_LE",
            "Applewatch.Heart_LE",
            "Applewatch.Calories_LE",
            "Applewatch.Distance_LE",
            "RestingApplewatchHeartrate_LE",
        ]
        missing = [col for col in required_cols if col not in df.columns]
        if missing:
            raise ValueError(f"Missing required columns: {missing}")
        self._fitted = True
        return self

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        if not self._fitted:
            raise RuntimeError("Call fit() before transform()")

        features = df.copy()
        features["NormalizedApplewatchHeartrate_LE"] = (
            features["Applewatch.Heart_LE"] - features["RestingApplewatchHeartrate_LE"]
        )
        features["SDNormalizedApplewatchHR_LE"] = (
            features["NormalizedApplewatchHeartrate_LE"]
            .ewm(span=self.sd_normalized_span, min_periods=2)
            .std()
            .fillna(0)
        )
        features["ApplewatchIntensity_LE"] = self._calculate_intensity(features)
        features["CorrelationApplewatchHeartrateSteps_LE"] = self._rolling_pearson(
            features["Applewatch.Heart_LE"],
            features["Applewatch.Steps_LE"],
            window=self.correlation_window,
        )
        features["ApplewatchStepsXDistance_LE"] = (
            features["Applewatch.Steps_LE"] * features["Applewatch.Distance_LE"]
        )
        features = features.replace([np.inf, -np.inf], np.nan)
        features = features.ffill().bfill().fillna(0)
        return features

    def get_manifest_payload(self) -> Dict[str, Any]:
        return {
            "feature_engineering_version": FEATURE_ENGINEERING_VERSION,
            "feature_engineering_params": {
                "intensity_params": self.intensity_params,
                "sd_normalized_span": self.sd_normalized_span,
                "correlation_window": self.correlation_window,
            },
        }

    def _calculate_intensity(self, features: pd.DataFrame) -> pd.Series:
        p = self.intensity_params
        hr_delta = features["NormalizedApplewatchHeartrate_LE"].clip(0)
        steps_log = np.log1p(features["Applewatch.Steps_LE"])
        hr_norm = (hr_delta / p["hr_max"]).clip(0, 1)
        steps_norm = (steps_log / np.log1p(p["steps_max"])).clip(0, 1)
        intensity_raw = p["weight_hr"] * hr_norm + (1 - p["weight_hr"]) * steps_norm
        return (intensity_raw * p["scale"] + p["offset"]).clip(0, 1)

    @staticmethod
    def _rolling_pearson(x: pd.Series, y: pd.Series, window: int = 30) -> pd.Series:
        result: List[float] = []
        for i in range(len(x)):
            wx = x.iloc[max(0, i - window) : i + 1]
            wy = y.iloc[max(0, i - window) : i + 1]
            if wx.std() < 1e-6 or wy.std() < 1e-6 or len(wx.dropna()) < 10:
                result.append(1.0)
            else:
                corr = wx.corr(wy)
                result.append(corr if not np.isnan(corr) else 1.0)
        return pd.Series(result, index=x.index).ffill().bfill()


class ActivityDataPreprocessor:
    def __init__(self, target_col: str = TARGET_COL):
        self.target_col = target_col
        self.scaler = StandardScaler()
        self.encoder = _make_encoder()
        self.numeric_features: List[str] = []
        self.categorical_features: List[str] = []
        self.numeric_imputation_values: Dict[str, float] = {}
        self.categorical_fill_value = "Unknown"
        self.feature_names: List[str] = []
        self.target_mapping: Dict[str, int] = {}
        self.inverse_target_mapping: Dict[int, str] = {}
        self.encoder_categories: Dict[str, List[str]] = {}
        self.is_fitted = False

    def identify_features(self, df: pd.DataFrame) -> None:
        exclude_cols = {self.target_col, "Unnamed: 0"}
        self.numeric_features = [
            col
            for col in df.select_dtypes(include=[np.number]).columns
            if col not in exclude_cols
        ]
        self.categorical_features = [
            col
            for col in df.select_dtypes(include=["object", "category"]).columns
            if col not in exclude_cols
        ]

    def fit(self, df: pd.DataFrame) -> "ActivityDataPreprocessor":
        self.identify_features(df)
        self._fit_target_mapping(df[self.target_col])
        self._fit_numeric(df)
        self._fit_categorical(df)
        self.is_fitted = True
        return self

    def transform(self, df: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray]:
        if not self.is_fitted:
            raise RuntimeError("Call fit() before transform()")

        x_numeric = pd.DataFrame(index=df.index)
        if self.numeric_features:
            x_numeric = df[self.numeric_features].apply(pd.to_numeric, errors="coerce")
            x_numeric = x_numeric.fillna(pd.Series(self.numeric_imputation_values))
            x_numeric_scaled = self.scaler.transform(x_numeric.to_numpy(dtype=np.float64))
        else:
            x_numeric_scaled = np.zeros((len(df), 0), dtype=np.float64)

        if self.categorical_features:
            x_categorical = (
                df[self.categorical_features]
                .copy()
                .fillna(self.categorical_fill_value)
                .astype(str)
            )
            x_categorical_encoded = self.encoder.transform(x_categorical)
            x = np.hstack([x_numeric_scaled, x_categorical_encoded])
        else:
            x = x_numeric_scaled

        y = self._transform_target(df[self.target_col])
        return x.astype(np.float32), y.astype(np.int64)

    def to_legacy_manifest(self) -> Dict[str, Any]:
        return {
            "mean": self.scaler.mean_.tolist(),
            "std": self.scaler.scale_.tolist(),
            "feature_names": self.feature_names,
            "target_mapping": self.target_mapping,
            "inverse_target_mapping": {
                str(k): v for k, v in self.inverse_target_mapping.items()
            },
        }

    def to_v2_manifest(
        self,
        fe_manifest: Dict[str, Any],
    ) -> Dict[str, Any]:
        return {
            "version": PREPROCESSOR_V2_VERSION,
            "feature_engineering_version": fe_manifest["feature_engineering_version"],
            "feature_engineering_params": fe_manifest["feature_engineering_params"],
            "numeric_features": self.numeric_features,
            "categorical_features": self.categorical_features,
            "imputation": {
                "numeric_strategy": "median",
                "numeric_values": self.numeric_imputation_values,
                "categorical_strategy": "constant",
                "categorical_fill_value": self.categorical_fill_value,
            },
            "scaler": {
                "mean": self.scaler.mean_.tolist(),
                "std": self.scaler.scale_.tolist(),
            },
            "encoder": {
                "type": "onehot",
                "categories": self.encoder_categories,
            },
            "feature_names": self.feature_names,
            "target_mapping": self.target_mapping,
            "inverse_target_mapping": {
                str(k): v for k, v in self.inverse_target_mapping.items()
            },
        }

    def _fit_target_mapping(self, target_series: pd.Series) -> None:
        unique_classes = sorted(
            target_series.dropna().astype(str).unique().tolist()
        )
        self.target_mapping = {cls: idx for idx, cls in enumerate(unique_classes)}
        self.inverse_target_mapping = {
            idx: cls for cls, idx in self.target_mapping.items()
        }

    def _fit_numeric(self, df: pd.DataFrame) -> None:
        if not self.numeric_features:
            self.scaler.fit(np.zeros((1, 1), dtype=np.float64))
            self.scaler.mean_ = np.zeros((0,), dtype=np.float64)
            self.scaler.scale_ = np.ones((0,), dtype=np.float64)
            return
        x_numeric = df[self.numeric_features].apply(pd.to_numeric, errors="coerce")
        median_values = (
            x_numeric.median(numeric_only=True, skipna=True).fillna(0.0).to_dict()
        )
        self.numeric_imputation_values = {
            key: float(value) for key, value in median_values.items()
        }
        x_numeric = x_numeric.fillna(pd.Series(self.numeric_imputation_values))
        self.scaler.fit(x_numeric.to_numpy(dtype=np.float64))

    def _fit_categorical(self, df: pd.DataFrame) -> None:
        if not self.categorical_features:
            self.encoder_categories = {}
            self.feature_names = list(self.numeric_features)
            return
        x_categorical = (
            df[self.categorical_features]
            .copy()
            .fillna(self.categorical_fill_value)
            .astype(str)
        )
        self.encoder.fit(x_categorical)
        self.encoder_categories = {
            feature: [str(value) for value in values.tolist()]
            for feature, values in zip(self.categorical_features, self.encoder.categories_)
        }
        cat_feature_names = self.encoder.get_feature_names_out(self.categorical_features)
        self.feature_names = self.numeric_features + list(cat_feature_names)

    def _transform_target(self, target_series: pd.Series) -> np.ndarray:
        encoded = target_series.astype(str).map(self.target_mapping)
        if encoded.isna().any():
            missing = target_series[encoded.isna()].astype(str).unique().tolist()
            raise ValueError(f"Unknown target labels in split: {missing}")
        return encoded.to_numpy(dtype=np.int64)


def _make_encoder() -> OneHotEncoder:
    try:
        return OneHotEncoder(sparse_output=False, handle_unknown="ignore")
    except TypeError:
        return OneHotEncoder(sparse=False, handle_unknown="ignore")


def plan_split(
    df: pd.DataFrame,
    target_col: str = TARGET_COL,
    seed: int = DEFAULT_SEED,
    test_size: float = DEFAULT_TEST_SIZE,
    val_size: float = DEFAULT_VAL_SIZE,
) -> SplitResult:
    if target_col not in df.columns:
        raise ValueError(f"Missing target column: {target_col}")
    if not 0 < test_size < 1:
        raise ValueError("test_size must be in (0, 1)")
    if not 0 < val_size < 1:
        raise ValueError("val_size must be in (0, 1)")
    if len(df) < 20:
        raise ValueError("Need at least 20 rows for stable train/val/test splits.")

    indices = np.arange(len(df), dtype=np.int64)
    y = df[target_col].astype(str)
    selected_group_col = _find_group_column(df)
    fallback_reason: Optional[str] = None
    groups: Optional[np.ndarray] = None
    unique_groups = 0

    if selected_group_col is not None:
        groups = (
            df[selected_group_col]
            .fillna("__missing_group__")
            .astype(str)
            .to_numpy(dtype=object)
        )
        unique_groups = int(pd.Series(groups).nunique())

    if selected_group_col is not None and unique_groups >= 4 and groups is not None:
        outer = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=seed)
        trainval_local, test_local = next(outer.split(indices, y, groups=groups))
        trainval_idx = indices[trainval_local]
        test_idx = indices[test_local]

        inner = GroupShuffleSplit(n_splits=1, test_size=val_size, random_state=seed + 11)
        inner_groups = groups[trainval_idx]
        train_local, val_local = next(
            inner.split(trainval_idx, y.iloc[trainval_idx], groups=inner_groups)
        )
        train_idx = trainval_idx[train_local]
        val_idx = trainval_idx[val_local]

        train_groups = set(groups[train_idx].tolist())
        val_groups = set(groups[val_idx].tolist())
        test_groups = set(groups[test_idx].tolist())
        group_overlap_check = bool(
            train_groups.intersection(val_groups)
            or train_groups.intersection(test_groups)
            or val_groups.intersection(test_groups)
        )
        strategy = "group_shuffle_split"
        effective_group_column = selected_group_col
    else:
        if selected_group_col is not None and unique_groups < 4:
            fallback_reason = (
                f"group_column_found_but_insufficient_unique_groups:"
                f"{selected_group_col}:{unique_groups}"
            )

        outer = StratifiedShuffleSplit(
            n_splits=1, test_size=test_size, random_state=seed
        )
        trainval_local, test_local = next(outer.split(indices, y))
        trainval_idx = indices[trainval_local]
        test_idx = indices[test_local]

        inner = StratifiedShuffleSplit(
            n_splits=1, test_size=val_size, random_state=seed + 11
        )
        train_local, val_local = next(
            inner.split(trainval_idx, y.iloc[trainval_idx])
        )
        train_idx = trainval_idx[train_local]
        val_idx = trainval_idx[val_local]

        strategy = "stratified_shuffle_split"
        effective_group_column = None
        group_overlap_check = False

    train_idx = np.sort(train_idx.astype(np.int64))
    val_idx = np.sort(val_idx.astype(np.int64))
    test_idx = np.sort(test_idx.astype(np.int64))

    total = len(df)
    manifest: Dict[str, Any] = {
        "strategy": strategy,
        "group_column": effective_group_column,
        "candidate_group_column": selected_group_col,
        "unique_groups": unique_groups,
        "train_size": int(len(train_idx)),
        "val_size": int(len(val_idx)),
        "test_size": int(len(test_idx)),
        "train_ratio": round(len(train_idx) / total, 6),
        "val_ratio": round(len(val_idx) / total, 6),
        "test_ratio": round(len(test_idx) / total, 6),
        "group_overlap_check": group_overlap_check,
        "seed": seed,
        "requested_test_size": test_size,
        "requested_val_size_from_trainval": val_size,
    }
    if fallback_reason is not None:
        manifest["fallback_reason"] = fallback_reason

    return SplitResult(
        train_idx=train_idx,
        val_idx=val_idx,
        test_idx=test_idx,
        strategy=strategy,
        group_column=effective_group_column,
        unique_groups=unique_groups,
        group_overlap_check=group_overlap_check,
        manifest=manifest,
    )


def build(config: BuildConfig) -> Dict[str, Path]:
    if not config.dataset_path.exists():
        raise FileNotFoundError(
            f"Dataset not found: {config.dataset_path}. "
            "Set HARVARD_AW_DATASET env var to data_for_weka_aw.csv path."
        )

    config.output_dir.mkdir(parents=True, exist_ok=True)
    config.report_dir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(config.dataset_path)
    if "Unnamed: 0" in df.columns:
        df = df.drop("Unnamed: 0", axis=1)
    if TARGET_COL not in df.columns:
        raise ValueError(f"Missing required target column: {TARGET_COL}")

    split_result = plan_split(
        df=df,
        target_col=TARGET_COL,
        seed=config.seed,
        test_size=config.test_size,
        val_size=config.val_size,
    )

    train_raw = df.iloc[split_result.train_idx].reset_index(drop=True)
    val_raw = df.iloc[split_result.val_idx].reset_index(drop=True)
    test_raw = df.iloc[split_result.test_idx].reset_index(drop=True)

    fe = AppleWatchSyntheticFeatures()
    fe.fit(train_raw)
    train_fe = fe.transform(train_raw)
    val_fe = fe.transform(val_raw)
    test_fe = fe.transform(test_raw)

    preprocessor = ActivityDataPreprocessor(target_col=TARGET_COL)
    preprocessor.fit(train_fe)
    x_train, y_train = preprocessor.transform(train_fe)
    x_val, y_val = preprocessor.transform(val_fe)
    x_test, y_test = preprocessor.transform(test_fe)

    model_params = {
        **BEST_PARAMS,
        "objective": "multi:softprob",
        "num_class": len(preprocessor.target_mapping),
        "random_state": config.seed,
        "n_jobs": -1,
        "tree_method": "hist",
        "eval_metric": "mlogloss",
        "early_stopping_rounds": config.early_stopping_rounds,
    }
    model_params.pop("scale_pos_weight", None)
    model = xgb.XGBClassifier(**model_params)
    model.fit(
        x_train,
        y_train,
        eval_set=[(x_val, y_val)],
        verbose=False,
    )

    y_pred = model.predict(x_test).astype(np.int64)
    y_proba = model.predict_proba(x_test)
    class_ids = list(range(len(preprocessor.target_mapping)))
    class_labels = [preprocessor.inverse_target_mapping[idx] for idx in class_ids]
    metrics = _compute_metrics(
        y_true=y_test,
        y_pred=y_pred,
        y_proba=y_proba,
        class_ids=class_ids,
        class_labels=class_labels,
    )

    model_dump_path = config.report_dir / "model_xgboost.joblib"
    joblib.dump(model, model_dump_path)

    preprocessor_v1_path = config.output_dir / "preprocessor_v1.json"
    preprocessor_v2_path = config.output_dir / "preprocessor_v2.json"
    _write_json(preprocessor_v1_path, preprocessor.to_legacy_manifest())
    fe_manifest = fe.get_manifest_payload()
    _write_json(preprocessor_v2_path, preprocessor.to_v2_manifest(fe_manifest))

    onnx_path = config.output_dir / "model_harvardAWData_xgboost.onnx"
    onnx_model = onnxmltools.convert_xgboost(
        model,
        initial_types=[(INPUT_NAME, FloatTensorType([None, x_train.shape[1]]))],
        target_opset=14,
    )
    with onnx_path.open("wb") as output_file:
        output_file.write(onnx_model.SerializeToString())

    split_manifest_path = config.report_dir / "split_manifest.json"
    _write_json(split_manifest_path, split_result.manifest)

    parity_fixture = _build_parity_fixture(
        model=model,
        x_test=x_test,
        y_pred=y_pred,
        y_proba=y_proba,
        test_row_indices=split_result.test_idx,
        test_fe=test_fe,
        preprocessor=preprocessor,
        class_labels=class_labels,
        parity_samples=config.parity_samples,
    )
    parity_fixture_path = config.report_dir / "parity_fixture_v2.json"
    _write_json(parity_fixture_path, parity_fixture)

    training_report = _build_training_report(
        config=config,
        split_result=split_result,
        preprocessor=preprocessor,
        fe_manifest=fe_manifest,
        model=model,
        model_params=model_params,
        metrics=metrics,
        train_y=y_train,
        val_y=y_val,
        test_y=y_test,
    )
    training_report_path = config.report_dir / "training_report.json"
    _write_json(training_report_path, training_report)

    artifact_hashes = {
        "model_harvardAWData_xgboost.onnx": _sha256_file(onnx_path),
        "preprocessor_v1.json": _sha256_file(preprocessor_v1_path),
        "preprocessor_v2.json": _sha256_file(preprocessor_v2_path),
        "split_manifest.json": _sha256_file(split_manifest_path),
        "training_report.json": _sha256_file(training_report_path),
        "parity_fixture_v2.json": _sha256_file(parity_fixture_path),
        "model_xgboost.joblib": _sha256_file(model_dump_path),
    }

    metadata = {
        "model_version": MODEL_VERSION,
        "input_name": INPUT_NAME,
        "split_strategy": split_result.strategy,
        "group_column": split_result.group_column,
        "seed": config.seed,
        "features_count": int(x_train.shape[1]),
        "class_labels": {
            str(idx): label for idx, label in preprocessor.inverse_target_mapping.items()
        },
        "metrics": metrics,
        "dataset_path": config.dataset_path.name,
        "dataset_sha256": _sha256_file(config.dataset_path),
        "artifact_hashes": artifact_hashes,
    }
    metadata_path = config.output_dir / "model_metadata.json"
    _write_json(metadata_path, metadata)

    print("Harvard Apple Watch artifacts created:")
    print(f" - {onnx_path}")
    print(f" - {preprocessor_v1_path}")
    print(f" - {preprocessor_v2_path}")
    print(f" - {metadata_path}")
    print(f" - {model_dump_path}")
    print(f" - {split_manifest_path}")
    print(f" - {training_report_path}")
    print(f" - {parity_fixture_path}")
    print(f"Test macro F1: {metrics['macro_f1']:.4f}")
    print(f"Test balanced accuracy: {metrics['balanced_accuracy']:.4f}")

    return {
        "onnx_path": onnx_path,
        "preprocessor_v1_path": preprocessor_v1_path,
        "preprocessor_v2_path": preprocessor_v2_path,
        "metadata_path": metadata_path,
        "model_dump_path": model_dump_path,
        "split_manifest_path": split_manifest_path,
        "training_report_path": training_report_path,
        "parity_fixture_path": parity_fixture_path,
    }


def _find_group_column(df: pd.DataFrame) -> Optional[str]:
    for column in GROUP_COLUMN_CANDIDATES:
        if column not in df.columns:
            continue
        unique_count = int(df[column].dropna().nunique())
        if unique_count > 0:
            return column
    return None


def _compute_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    y_proba: np.ndarray,
    class_ids: Sequence[int],
    class_labels: Sequence[str],
) -> Dict[str, Any]:
    report = classification_report(
        y_true,
        y_pred,
        labels=class_ids,
        target_names=class_labels,
        output_dict=True,
        zero_division=0,
    )
    metrics = {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "macro_f1": float(f1_score(y_true, y_pred, average="macro", zero_division=0)),
        "weighted_f1": float(
            f1_score(y_true, y_pred, average="weighted", zero_division=0)
        ),
        "log_loss": float(log_loss(y_true, y_proba, labels=class_ids)),
        "confusion_matrix": confusion_matrix(
            y_true, y_pred, labels=class_ids
        ).tolist(),
        "classification_report": _json_safe(report),
    }
    return metrics


def _build_parity_fixture(
    model: xgb.XGBClassifier,
    x_test: np.ndarray,
    y_pred: np.ndarray,
    y_proba: np.ndarray,
    test_row_indices: np.ndarray,
    test_fe: pd.DataFrame,
    preprocessor: ActivityDataPreprocessor,
    class_labels: Sequence[str],
    parity_samples: int,
) -> Dict[str, Any]:
    if len(x_test) == 0:
        raise RuntimeError("Cannot build parity fixture: test split is empty.")
    case_count = min(max(parity_samples, 1), len(x_test))
    cases: List[Dict[str, Any]] = []
    for idx in range(case_count):
        row = test_fe.iloc[idx]
        raw_features: Dict[str, Any] = {}
        for numeric_feature in preprocessor.numeric_features:
            raw_features[numeric_feature] = _json_safe_float(
                float(pd.to_numeric(row[numeric_feature], errors="coerce"))
                if numeric_feature in row
                else np.nan
            )
        for categorical_feature in preprocessor.categorical_features:
            raw_value = row[categorical_feature] if categorical_feature in row else None
            raw_features[categorical_feature] = (
                None if pd.isna(raw_value) else str(raw_value)
            )

        predicted_class_id = int(y_pred[idx])
        cases.append(
            {
                "source_row_index": int(test_row_indices[idx]),
                "raw_features": raw_features,
                "scaled_input": x_test[idx].astype(np.float32).tolist(),
                "expected_class_id": predicted_class_id,
                "expected_label": class_labels[predicted_class_id],
                "expected_probabilities": y_proba[idx].astype(np.float64).tolist(),
            }
        )
    return {
        "version": "harvard-parity-v2",
        "model_version": MODEL_VERSION,
        "input_name": INPUT_NAME,
        "feature_names": preprocessor.feature_names,
        "class_ids": list(range(len(class_labels))),
        "class_labels": list(class_labels),
        "cases": cases,
        "xgboost_best_iteration": _extract_best_iteration(model),
    }


def _build_training_report(
    config: BuildConfig,
    split_result: SplitResult,
    preprocessor: ActivityDataPreprocessor,
    fe_manifest: Dict[str, Any],
    model: xgb.XGBClassifier,
    model_params: Dict[str, Any],
    metrics: Dict[str, Any],
    train_y: np.ndarray,
    val_y: np.ndarray,
    test_y: np.ndarray,
) -> Dict[str, Any]:
    evals_result = model.evals_result()
    return {
        "model_version": MODEL_VERSION,
        "config": {
            "seed": config.seed,
            "test_size": config.test_size,
            "val_size": config.val_size,
            "early_stopping_rounds": config.early_stopping_rounds,
            "parity_samples": config.parity_samples,
        },
        "split_manifest": split_result.manifest,
        "feature_engineering": fe_manifest,
        "preprocessor": {
            "version": PREPROCESSOR_V2_VERSION,
            "numeric_features": preprocessor.numeric_features,
            "categorical_features": preprocessor.categorical_features,
            "feature_names": preprocessor.feature_names,
            "imputation": {
                "numeric_strategy": "median",
                "numeric_values": preprocessor.numeric_imputation_values,
                "categorical_strategy": "constant",
                "categorical_fill_value": preprocessor.categorical_fill_value,
            },
            "scaler": {
                "mean": preprocessor.scaler.mean_.tolist(),
                "std": preprocessor.scaler.scale_.tolist(),
            },
            "encoder": {
                "type": "onehot",
                "categories": preprocessor.encoder_categories,
            },
            "target_mapping": preprocessor.target_mapping,
            "inverse_target_mapping": {
                str(key): value
                for key, value in preprocessor.inverse_target_mapping.items()
            },
        },
        "model_params": model_params,
        "training": {
            "eval_metric": "mlogloss",
            "eval_set": ["validation"],
            "early_stopping_rounds": config.early_stopping_rounds,
            "best_iteration": _extract_best_iteration(model),
            "best_score": _extract_best_score(model),
            "evals_result": _json_safe(evals_result),
        },
        "split_class_distribution": {
            "train": _class_distribution(train_y),
            "val": _class_distribution(val_y),
            "test": _class_distribution(test_y),
        },
        "metrics": metrics,
    }


def _class_distribution(values: np.ndarray) -> Dict[str, int]:
    unique, counts = np.unique(values, return_counts=True)
    return {str(int(key)): int(count) for key, count in zip(unique, counts)}


def _extract_best_iteration(model: xgb.XGBClassifier) -> Optional[int]:
    best_iteration = getattr(model, "best_iteration", None)
    if best_iteration is None:
        return None
    return int(best_iteration)


def _extract_best_score(model: xgb.XGBClassifier) -> Optional[float]:
    best_score = getattr(model, "best_score", None)
    if best_score is None:
        return None
    return float(best_score)


def _json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    if isinstance(value, tuple):
        return [_json_safe(item) for item in value]
    if isinstance(value, np.ndarray):
        return [_json_safe(item) for item in value.tolist()]
    if isinstance(value, np.integer):
        return int(value)
    if isinstance(value, np.floating):
        if not np.isfinite(value):
            return None
        return float(value)
    if isinstance(value, float):
        if not np.isfinite(value):
            return None
        return value
    return value


def _json_safe_float(value: float) -> Optional[float]:
    if not np.isfinite(value):
        return None
    return float(value)


def _write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as output_file:
        json.dump(_json_safe(payload), output_file, ensure_ascii=False, indent=2)


def _sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file_obj:
        while True:
            chunk = file_obj.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def _resolve_default_dataset() -> Path:
    env = os.getenv("HARVARD_AW_DATASET")
    if env:
        return Path(env).expanduser().resolve()

    cache_path = Path(
        "~/.cache/kagglehub/datasets/aleespinosa/apple-watch-and-fitbit-data/versions/1/data_for_weka_aw.csv"
    ).expanduser()
    return cache_path.resolve()


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dataset-path",
        default=str(_resolve_default_dataset()),
        help="Path to data_for_weka_aw.csv dataset.",
    )
    parser.add_argument(
        "--output-dir",
        default="assets/models/harvard_aw",
        help="Directory for ONNX + metadata + preprocessor manifests.",
    )
    parser.add_argument(
        "--report-dir",
        default="build/ml/harvard_aw",
        help="Directory for reports, parity fixtures and local model dump.",
    )
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--test-size", type=float, default=DEFAULT_TEST_SIZE)
    parser.add_argument("--val-size", type=float, default=DEFAULT_VAL_SIZE)
    parser.add_argument(
        "--early-stopping-rounds",
        type=int,
        default=DEFAULT_EARLY_STOPPING_ROUNDS,
    )
    parser.add_argument("--parity-samples", type=int, default=DEFAULT_PARITY_SAMPLES)
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    build(
        BuildConfig(
            dataset_path=Path(args.dataset_path).expanduser().resolve(),
            output_dir=Path(args.output_dir).expanduser().resolve(),
            report_dir=Path(args.report_dir).expanduser().resolve(),
            seed=int(args.seed),
            test_size=float(args.test_size),
            val_size=float(args.val_size),
            early_stopping_rounds=int(args.early_stopping_rounds),
            parity_samples=max(1, int(args.parity_samples)),
        )
    )


if __name__ == "__main__":
    main()
