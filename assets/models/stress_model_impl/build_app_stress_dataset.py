#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from build_stress_artifacts import FEATURES


STRESS_MODEL_IDS = {
    "stress_score_v1",
    "stress-score-v1",
    "stress-scorecard-v1",
}


def read_table(path: Path) -> pd.DataFrame:
    if path.suffix.lower() in {".json", ".jsonl"}:
        text = path.read_text(encoding="utf-8").strip()
        if not text:
            return pd.DataFrame()
        if path.suffix.lower() == ".jsonl":
            return pd.DataFrame([json.loads(line) for line in text.splitlines() if line.strip()])
        payload = json.loads(text)
        if isinstance(payload, list):
            return pd.DataFrame(payload)
        if isinstance(payload, dict) and "rows" in payload:
            return pd.DataFrame(payload["rows"])
        if isinstance(payload, dict) and "data" in payload:
            return pd.DataFrame(payload["data"])
        return pd.DataFrame(payload)
    return pd.read_csv(path)


def parse_jsonish(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    if value is None or (isinstance(value, float) and np.isnan(value)):
        return {}
    text = str(value).strip()
    if not text:
        return {}
    try:
        parsed = json.loads(text)
        return parsed if isinstance(parsed, dict) else {}
    except json.JSONDecodeError:
        return {}


def to_utc(series: pd.Series) -> pd.Series:
    return pd.to_datetime(series, errors="coerce", utc=True)


def date_key(ts: pd.Series, timezone_offset_hours: int) -> pd.Series:
    shifted = ts + pd.to_timedelta(timezone_offset_hours, unit="h")
    return shifted.dt.strftime("%Y-%m-%d")


def normalize_scale(value: Any) -> float:
    parsed = pd.to_numeric(pd.Series([value]), errors="coerce").iloc[0]
    if pd.isna(parsed) or parsed < 1 or parsed > 5:
        return np.nan
    return float(parsed)


def optional_series(df: pd.DataFrame, column: str) -> pd.Series:
    if column in df.columns:
        return df[column]
    return pd.Series(np.nan, index=df.index)


def scale_from_column_or_metadata(
    df: pd.DataFrame,
    column: str,
    metadata_keys: tuple[str, ...],
) -> pd.Series:
    values = optional_series(df, column).copy()
    if "metadata" not in df.columns:
        return values.map(normalize_scale)

    missing = values.isna()
    if missing.any():
        metadata = optional_series(df, "metadata").map(parse_jsonish)
        for key in metadata_keys:
            replacements = metadata.map(lambda payload: payload.get(key))
            replacement_mask = missing & replacements.notna()
            values.loc[replacement_mask] = replacements.loc[replacement_mask]
            missing = values.isna()
            if not missing.any():
                break
    return values.map(normalize_scale)


def build_target_score(stress: float, fatigue: float, wellness: float) -> float:
    parts: list[tuple[float, float]] = []
    if np.isfinite(stress):
        parts.append((((stress - 1.0) / 4.0) * 100.0, 0.62))
    if np.isfinite(fatigue):
        parts.append((((fatigue - 1.0) / 4.0) * 100.0, 0.23))
    if np.isfinite(wellness):
        parts.append((((5.0 - wellness) / 4.0) * 100.0, 0.15))
    if not parts:
        return np.nan
    numerator = sum(value * weight for value, weight in parts)
    denominator = sum(weight for _, weight in parts)
    return float(np.clip(numerator / denominator, 0, 100))


def sample_weight(row: pd.Series) -> float:
    weight = 1.0
    stress = row.get("stress_now_1_5")
    if pd.isna(stress):
        return 0.0
    if float(stress) == 3.0:
        weight *= 0.45
    confidence = row.get("model_confidence")
    if pd.notna(confidence):
        weight *= float(np.clip(0.55 + (0.45 * float(confidence)), 0.35, 1.0))
    if pd.isna(row.get("fatigue_1_5")):
        weight *= 0.92
    if pd.isna(row.get("wellbeing_1_5")):
        weight *= 0.92
    return float(np.clip(weight, 0.2, 1.0))


def explode_features(outputs: pd.DataFrame) -> pd.DataFrame:
    feature_rows = []
    for _, row in outputs.iterrows():
        features = parse_jsonish(row.get("features"))
        data_quality = parse_jsonish(row.get("data_quality"))
        out: dict[str, Any] = {
            "subject_id": row.get("subject_id"),
            "window_start": row.get("window_start"),
            "window_end": row.get("window_end"),
            "join_date": row.get("join_date"),
            "model_id": row.get("model_id"),
            "model_version": row.get("model_version"),
            "model_score": row.get("score"),
            "model_confidence": row.get("confidence"),
            "model_status": row.get("status"),
            "model_source": row.get("source"),
            "model_reason": row.get("reason"),
            "data_quality_overall": data_quality.get("overall"),
            "data_quality_heart_rate": data_quality.get("heart_rate"),
            "data_quality_baseline": data_quality.get("baseline"),
        }
        for feature in FEATURES:
            out[feature] = features.get(feature)
        feature_rows.append(out)
    return pd.DataFrame(feature_rows)


def prepare_outputs(
    outputs: pd.DataFrame,
    timezone_offset_hours: int,
) -> pd.DataFrame:
    if outputs.empty:
        return outputs
    out = outputs.copy()
    out["model_id"] = out["model_id"].astype(str)
    out = out[out["model_id"].isin(STRESS_MODEL_IDS)].copy()
    out["window_start"] = to_utc(out["window_start"])
    out["window_end"] = to_utc(out["window_end"])
    out = out[out["window_end"].notna()].copy()
    out["join_date"] = date_key(out["window_end"], timezone_offset_hours)
    return explode_features(out)


def prepare_ema(
    wellbeing: pd.DataFrame,
    timezone_offset_hours: int,
) -> pd.DataFrame:
    if wellbeing.empty:
        return wellbeing
    out = wellbeing.copy()
    if "entry_date" not in out.columns:
        if "date" in out.columns:
            out["entry_date"] = out["date"]
        else:
            raise ValueError("wellbeing export must contain entry_date")
    out["stress_now_1_5"] = scale_from_column_or_metadata(
        out,
        "stress_now",
        ("stress_now", "stressNow", "stress"),
    )
    out["fatigue_1_5"] = scale_from_column_or_metadata(
        out,
        "fatigue",
        ("fatigue", "fatigueNow"),
    )
    out["wellbeing_1_5"] = scale_from_column_or_metadata(
        out,
        "wellness",
        ("wellness", "wellbeing", "wellbeingNow"),
    )
    out = out[out["stress_now_1_5"].notna()].copy()
    out["join_date"] = pd.to_datetime(out["entry_date"], errors="coerce").dt.strftime("%Y-%m-%d")
    created_at = to_utc(optional_series(out, "created_at"))
    updated_at = to_utc(optional_series(out, "updated_at"))
    date_as_utc = pd.to_datetime(out["entry_date"], errors="coerce", utc=True)
    fallback_timestamp = (
        date_as_utc
        - pd.to_timedelta(timezone_offset_hours, unit="h")
        + pd.to_timedelta(20, unit="h")
    )
    out["ema_timestamp"] = created_at.fillna(updated_at).fillna(fallback_timestamp)
    return out[
        [
            "subject_id",
            "join_date",
            "ema_timestamp",
            "stress_now_1_5",
            "fatigue_1_5",
            "wellbeing_1_5",
        ]
    ].copy()


def join_outputs_to_ema(
    outputs: pd.DataFrame,
    ema: pd.DataFrame,
    max_join_hours: float,
) -> pd.DataFrame:
    if outputs.empty or ema.empty:
        return pd.DataFrame()

    rows = []
    for _, label in ema.iterrows():
        candidates = outputs[
            (outputs["subject_id"].astype(str) == str(label["subject_id"]))
            & (outputs["join_date"] == label["join_date"])
        ].copy()
        if candidates.empty:
            continue
        candidates["join_distance_hours"] = (
            candidates["window_end"] - label["ema_timestamp"]
        ).abs().dt.total_seconds() / 3600.0
        candidates = candidates[candidates["join_distance_hours"] <= max_join_hours]
        if candidates.empty:
            continue
        best = candidates.sort_values(["join_distance_hours", "window_end"]).iloc[0].to_dict()
        best["stress_now_1_5"] = label["stress_now_1_5"]
        best["fatigue_1_5"] = label["fatigue_1_5"]
        best["wellbeing_1_5"] = label["wellbeing_1_5"]
        best["ema_timestamp"] = label["ema_timestamp"]
        rows.append(best)
    return pd.DataFrame(rows)


def finalize_dataset(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame(
            columns=[
                "subject_id",
                "window_start",
                "window_end",
                "ema_timestamp",
                "stress_now_1_5",
                "fatigue_1_5",
                "wellbeing_1_5",
                "label",
                "target_score",
                "sample_weight",
                "model_score",
                "model_confidence",
                "model_status",
                "model_source",
                "join_distance_hours",
                *FEATURES,
            ]
        )

    out = df.copy()
    out["target_score"] = out.apply(
        lambda row: build_target_score(
            row["stress_now_1_5"],
            row.get("fatigue_1_5", np.nan),
            row.get("wellbeing_1_5", np.nan),
        ),
        axis=1,
    )
    out = out[out["target_score"].notna()].copy()
    out["label"] = (out["stress_now_1_5"] >= 4).astype(int)
    out["sample_weight"] = out.apply(sample_weight, axis=1)
    for feature in FEATURES:
        if feature not in out.columns:
            out[feature] = np.nan
    ordered = [
        "subject_id",
        "window_start",
        "window_end",
        "ema_timestamp",
        "stress_now_1_5",
        "fatigue_1_5",
        "wellbeing_1_5",
        "label",
        "target_score",
        "sample_weight",
        "model_score",
        "model_confidence",
        "model_status",
        "model_source",
        "join_distance_hours",
        *FEATURES,
    ]
    existing = [column for column in ordered if column in out.columns]
    return out[existing].sort_values(["subject_id", "window_start"]).reset_index(drop=True)


def write_report(df: pd.DataFrame, path: Path) -> None:
    report = {
        "n_rows": int(len(df)),
        "n_subjects": int(df["subject_id"].nunique()) if not df.empty else 0,
        "class_balance": {
            str(key): float(value)
            for key, value in df["label"].value_counts(normalize=True).sort_index().to_dict().items()
        }
        if not df.empty
        else {},
        "stress_now_distribution": {
            str(key): int(value)
            for key, value in df["stress_now_1_5"].value_counts().sort_index().to_dict().items()
        }
        if not df.empty
        else {},
        "missingness": {
            feature: float(pd.to_numeric(df[feature], errors="coerce").isna().mean())
            for feature in FEATURES
            if feature in df.columns
        }
        if not df.empty
        else {},
    }
    path.write_text(json.dumps(report, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_outputs", required=True, type=Path)
    parser.add_argument("--wellbeing_entries", required=True, type=Path)
    parser.add_argument("--out_csv", required=True, type=Path)
    parser.add_argument("--report_json", type=Path)
    parser.add_argument("--timezone_offset_hours", type=int, default=0)
    parser.add_argument("--max_join_hours", type=float, default=18.0)
    args = parser.parse_args()

    outputs = prepare_outputs(read_table(args.model_outputs), args.timezone_offset_hours)
    ema = prepare_ema(read_table(args.wellbeing_entries), args.timezone_offset_hours)
    joined = join_outputs_to_ema(outputs, ema, args.max_join_hours)
    dataset = finalize_dataset(joined)

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    dataset.to_csv(args.out_csv, index=False)
    if args.report_json:
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        write_report(dataset, args.report_json)
    print(f"Wrote {len(dataset)} app-labeled stress rows to {args.out_csv}")


if __name__ == "__main__":
    main()
