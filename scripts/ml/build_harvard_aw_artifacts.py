#!/usr/bin/env python3
"""Build Harvard Apple Watch model artifacts for Flutter inference.

Outputs:
  - assets/models/harvard_aw/model_harvardAWData_xgboost.onnx
  - assets/models/harvard_aw/preprocessor_v1.json
  - assets/models/harvard_aw/model_metadata.json
  - build/ml/harvard_aw/model_xgboost.joblib
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import joblib
import numpy as np
import onnxmltools
import pandas as pd
import xgboost as xgb
from onnxmltools.convert.common.data_types import FloatTensorType
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import OneHotEncoder, StandardScaler


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


class AppleWatchSyntheticFeatures:
    def __init__(
        self,
        intensity_params: Dict | None = None,
        sd_normalized_span: int = 3,
        correlation_window: int = 30,
    ) -> None:
        self.intensity_params = intensity_params or {
            "weight_hr": 0.90,
            "hr_max": 80,
            "steps_max": 50,
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

    def fit_transform(self, df: pd.DataFrame) -> pd.DataFrame:
        return self.fit(df).transform(df)

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
    def __init__(self, target_col: str = "activity_trimmed"):
        self.target_col = target_col
        self.scaler = StandardScaler()
        self.encoder = OneHotEncoder(sparse_output=False, handle_unknown="ignore")
        self.numeric_features: List[str] = []
        self.categorical_features: List[str] = []
        self.feature_names: List[str] = []
        self.target_mapping: Dict[str, int] = {}
        self.inverse_target_mapping: Dict[int, str] = {}
        self.is_fitted = False

    def identify_features(self, df: pd.DataFrame) -> None:
        exclude_cols = [self.target_col, "Unnamed: 0"]
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

    def encode_target(self, df: pd.DataFrame) -> pd.Series:
        unique_classes = sorted(df[self.target_col].unique())
        self.target_mapping = {cls: idx for idx, cls in enumerate(unique_classes)}
        self.inverse_target_mapping = {idx: cls for cls, idx in self.target_mapping.items()}
        return df[self.target_col].map(self.target_mapping)

    def fit_transform(self, df: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray]:
        self.identify_features(df)
        y = self.encode_target(df)

        x_numeric = df[self.numeric_features].copy()
        x_numeric = x_numeric.fillna(x_numeric.median(numeric_only=True))
        x_numeric_scaled = self.scaler.fit_transform(x_numeric)

        if self.categorical_features:
            x_categorical = df[self.categorical_features].copy().fillna("Unknown")
            x_categorical_encoded = self.encoder.fit_transform(x_categorical)
            cat_feature_names = self.encoder.get_feature_names_out(self.categorical_features)
            self.feature_names = self.numeric_features + list(cat_feature_names)
            x = np.hstack([x_numeric_scaled, x_categorical_encoded])
        else:
            self.feature_names = self.numeric_features
            x = x_numeric_scaled

        self.is_fitted = True
        return x, y.values


def _resolve_default_dataset() -> Path:
    env = os.getenv("HARVARD_AW_DATASET")
    if env:
        return Path(env).expanduser().resolve()

    cache_path = Path(
        "~/.cache/kagglehub/datasets/aleespinosa/apple-watch-and-fitbit-data/versions/1/data_for_weka_aw.csv"
    ).expanduser()
    return cache_path.resolve()


def build(config: BuildConfig) -> None:
    if not config.dataset_path.exists():
        raise FileNotFoundError(
            f"Dataset not found: {config.dataset_path}. "
            "Set HARVARD_AW_DATASET env var to data_for_weka_aw.csv path."
        )

    config.output_dir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(config.dataset_path)
    if "Unnamed: 0" in df.columns:
        df = df.drop("Unnamed: 0", axis=1)

    fe = AppleWatchSyntheticFeatures()
    features = fe.fit_transform(df)

    preprocessor = ActivityDataPreprocessor()
    x, y = preprocessor.fit_transform(features)

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=0.1, random_state=42, stratify=y
    )

    model = xgb.XGBClassifier(
        **BEST_PARAMS,
        objective="multi:softprob",
        num_class=len(np.unique(y_train)),
        random_state=42,
        n_jobs=-1,
        tree_method="hist",
        eval_metric="mlogloss",
    )
    model.fit(x_train, y_train)

    # Save raw training model for reproducibility (outside Flutter assets).
    build_dir = Path("build/ml/harvard_aw").resolve()
    build_dir.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, build_dir / "model_xgboost.joblib")

    preprocessor_payload = {
        "mean": preprocessor.scaler.mean_.tolist(),
        "std": preprocessor.scaler.scale_.tolist(),
        "feature_names": preprocessor.feature_names,
        "target_mapping": preprocessor.target_mapping,
        "inverse_target_mapping": {
            str(k): v for k, v in preprocessor.inverse_target_mapping.items()
        },
    }
    with (config.output_dir / "preprocessor_v1.json").open("w", encoding="utf-8") as f:
        json.dump(preprocessor_payload, f, ensure_ascii=False, indent=2)

    # ONNX export.
    onnx_model = onnxmltools.convert_xgboost(
        model,
        initial_types=[("float_input", FloatTensorType([None, x_train.shape[1]]))],
        target_opset=14,
    )
    with (config.output_dir / "model_harvardAWData_xgboost.onnx").open("wb") as f:
        f.write(onnx_model.SerializeToString())

    test_acc = float((model.predict(x_test) == y_test).mean())
    metadata = {
        "model_version": "harvard-aw-xgb-v1",
        "accuracy_test": round(test_acc, 6),
        "features_count": x_train.shape[1],
        "input_name": "float_input",
        "labels": preprocessor.inverse_target_mapping,
        "dataset_path": str(config.dataset_path),
    }
    with (config.output_dir / "model_metadata.json").open("w", encoding="utf-8") as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)

    print("Artifacts generated:")
    for name in [
        "model_harvardAWData_xgboost.onnx",
        "preprocessor_v1.json",
        "model_metadata.json",
    ]:
        print(f" - {config.output_dir / name}")
    print(f" - {build_dir / 'model_xgboost.joblib'}")
    print(f"Test accuracy: {test_acc:.4f}")


if __name__ == "__main__":
    dataset = _resolve_default_dataset()
    output = Path("assets/models/harvard_aw").resolve()
    build(BuildConfig(dataset_path=dataset, output_dir=output))
