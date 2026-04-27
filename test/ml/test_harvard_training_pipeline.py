import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np
import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT_DIR / "scripts/ml/build_harvard_aw_artifacts.py"


def _load_builder_module():
    spec = importlib.util.spec_from_file_location("harvard_builder", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module from {SCRIPT_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _make_dataset(with_groups: bool) -> pd.DataFrame:
    classes = [
        "Lying",
        "Running 3 METs",
        "Running 5 METs",
        "Running 7 METs",
        "Self Pace walk",
        "Sitting",
    ]
    group_count = 8 if with_groups else 1
    samples_per_class_per_group = 8
    rng = np.random.default_rng(20260428)

    rows = []
    for group in range(group_count):
        for class_id, label in enumerate(classes):
            for rep in range(samples_per_class_per_group):
                base = class_id * 15 + group * 1.2 + rep * 0.7
                resting = 58 + class_id + rng.normal(0, 1.2)
                heart = resting + 8 + class_id * 4 + rng.normal(0, 3.0)
                steps = max(0, 120 + class_id * 70 + rng.normal(0, 20))
                distance = max(0, 0.2 + class_id * 0.25 + rng.normal(0, 0.08))
                calories = max(0, 1.5 + class_id * 1.1 + rng.normal(0, 0.4))

                row = {
                    "age": 20 + (group % 5) + rep * 0.05,
                    "gender": float((group + rep) % 2),
                    "height": 165 + (group % 6),
                    "weight": 62 + (group % 7) + class_id * 0.2,
                    "Applewatch.Steps_LE": steps,
                    "Applewatch.Heart_LE": heart,
                    "Applewatch.Calories_LE": calories + base * 0.03,
                    "Applewatch.Distance_LE": distance,
                    "EntropyApplewatchHeartPerDay_LE": 5.8 + rng.normal(0, 0.08),
                    "EntropyApplewatchStepsPerDay_LE": 6.0 + rng.normal(0, 0.08),
                    "RestingApplewatchHeartrate_LE": resting,
                    "activity_trimmed": label,
                }
                if with_groups:
                    row["participant_id"] = f"participant_{group:02d}"
                rows.append(row)
    return pd.DataFrame(rows)


class HarvardTrainingPipelineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.builder_module = _load_builder_module()
        fast_params = dict(self.builder_module.BEST_PARAMS)
        fast_params["n_estimators"] = 64
        fast_params["max_depth"] = 4
        self.builder_module.BEST_PARAMS = fast_params

    def test_pipeline_order_group_split_and_artifact_contract(self) -> None:
        dataset = _make_dataset(with_groups=True)
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            dataset_path = temp_path / "harvard_aw.csv"
            output_dir = temp_path / "assets"
            report_dir = temp_path / "reports"
            dataset.to_csv(dataset_path, index=False)

            fe_fit_rows = {}
            preprocessor_fit_rows = {}
            original_fe_fit = self.builder_module.AppleWatchSyntheticFeatures.fit
            original_preprocessor_fit = self.builder_module.ActivityDataPreprocessor.fit

            def _spy_fe_fit(instance, df):
                fe_fit_rows["rows"] = len(df)
                return original_fe_fit(instance, df)

            def _spy_preprocessor_fit(instance, df):
                preprocessor_fit_rows["rows"] = len(df)
                return original_preprocessor_fit(instance, df)

            with mock.patch.object(
                self.builder_module.AppleWatchSyntheticFeatures,
                "fit",
                new=_spy_fe_fit,
            ), mock.patch.object(
                self.builder_module.ActivityDataPreprocessor,
                "fit",
                new=_spy_preprocessor_fit,
            ):
                artifacts = self.builder_module.build(
                    self.builder_module.BuildConfig(
                        dataset_path=dataset_path,
                        output_dir=output_dir,
                        report_dir=report_dir,
                        seed=42,
                        test_size=0.2,
                        val_size=0.2,
                        early_stopping_rounds=5,
                        parity_samples=3,
                    )
                )

            split_manifest = json.loads(
                Path(artifacts["split_manifest_path"]).read_text(encoding="utf-8")
            )
            self.assertEqual(split_manifest["strategy"], "group_shuffle_split")
            self.assertEqual(split_manifest["group_column"], "participant_id")
            self.assertFalse(split_manifest["group_overlap_check"])
            self.assertEqual(
                split_manifest["train_size"]
                + split_manifest["val_size"]
                + split_manifest["test_size"],
                len(dataset),
            )

            self.assertEqual(fe_fit_rows["rows"], split_manifest["train_size"])
            self.assertEqual(
                preprocessor_fit_rows["rows"],
                split_manifest["train_size"],
            )
            self.assertLess(fe_fit_rows["rows"], len(dataset))

            preprocessor_v2 = json.loads(
                (output_dir / "preprocessor_v2.json").read_text(encoding="utf-8")
            )
            self.assertEqual(preprocessor_v2["version"], "harvard-preprocessor-v2")
            self.assertEqual(
                preprocessor_v2["feature_engineering_version"], "harvard-fe-v2"
            )
            self.assertIn("imputation", preprocessor_v2)
            self.assertIn("scaler", preprocessor_v2)
            self.assertIn("encoder", preprocessor_v2)
            self.assertEqual(
                len(preprocessor_v2["numeric_features"]),
                len(preprocessor_v2["scaler"]["mean"]),
            )
            self.assertGreaterEqual(
                len(preprocessor_v2["feature_names"]),
                len(preprocessor_v2["scaler"]["mean"]),
            )

            metadata = json.loads(
                (output_dir / "model_metadata.json").read_text(encoding="utf-8")
            )
            self.assertEqual(metadata["model_version"], "harvard-aw-xgb-v2")
            self.assertEqual(metadata["input_name"], "float_input")
            self.assertEqual(metadata["split_strategy"], "group_shuffle_split")
            self.assertEqual(metadata["dataset_path"], dataset_path.name)
            self.assertFalse(metadata["dataset_path"].startswith("/"))
            for metric_key in (
                "accuracy",
                "balanced_accuracy",
                "macro_f1",
                "weighted_f1",
                "log_loss",
                "confusion_matrix",
                "classification_report",
            ):
                self.assertIn(metric_key, metadata["metrics"])

            training_report = json.loads(
                (report_dir / "training_report.json").read_text(encoding="utf-8")
            )
            self.assertEqual(training_report["training"]["eval_metric"], "mlogloss")
            self.assertEqual(training_report["training"]["early_stopping_rounds"], 5)
            self.assertIsNotNone(training_report["training"]["best_iteration"])

    def test_plan_split_stratified_fallback_when_group_missing(self) -> None:
        dataset = _make_dataset(with_groups=False)
        split_result = self.builder_module.plan_split(
            dataset,
            target_col=self.builder_module.TARGET_COL,
            seed=123,
            test_size=0.2,
            val_size=0.2,
        )

        self.assertEqual(split_result.strategy, "stratified_shuffle_split")
        self.assertIsNone(split_result.group_column)
        self.assertFalse(split_result.group_overlap_check)

        all_labels = set(dataset[self.builder_module.TARGET_COL].astype(str))
        for split_indices in (
            split_result.train_idx,
            split_result.val_idx,
            split_result.test_idx,
        ):
            split_labels = set(
                dataset.iloc[split_indices][self.builder_module.TARGET_COL].astype(str)
            )
            self.assertEqual(split_labels, all_labels)


if __name__ == "__main__":
    unittest.main()
