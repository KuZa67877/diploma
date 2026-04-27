import json
import unittest
from pathlib import Path
from typing import Any, Iterable, Optional

import numpy as np

try:
    import onnxruntime as ort
except ImportError:  # pragma: no cover
    ort = None


ROOT_DIR = Path(__file__).resolve().parents[2]
MODEL_PATH = ROOT_DIR / "assets/models/harvard_aw/model_harvardAWData_xgboost.onnx"
FIXTURE_PATH = ROOT_DIR / "build/ml/harvard_aw/parity_fixture_v2.json"


@unittest.skipUnless(ort is not None, "onnxruntime is not installed")
@unittest.skipUnless(
    MODEL_PATH.exists() and FIXTURE_PATH.exists(),
    "Harvard ONNX/parity artifacts are missing. Run scripts/ml/build_harvard_aw_artifacts.py first.",
)
class HarvardOnnxParityTests(unittest.TestCase):
    def test_harvard_onnx_matches_parity_fixture(self) -> None:
        fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        class_ids = [int(item) for item in fixture.get("class_ids", [])]
        cases = fixture.get("cases", [])
        self.assertTrue(cases, "Parity fixture does not contain any cases.")

        session = ort.InferenceSession(
            str(MODEL_PATH),
            providers=["CPUExecutionProvider"],
        )
        input_name = fixture.get("input_name") or session.get_inputs()[0].name

        for case in cases:
            scaled_input = np.asarray([case["scaled_input"]], dtype=np.float32)
            outputs = session.run(None, {input_name: scaled_input})

            predicted = _extract_predicted_label(outputs, session.get_outputs())
            expected_class_id = int(case["expected_class_id"])
            if isinstance(predicted, str):
                class_labels = fixture.get("class_labels", [])
                label_to_id = {label: idx for idx, label in enumerate(class_labels)}
                self.assertIn(predicted, label_to_id)
                predicted_class_id = label_to_id[predicted]
            else:
                predicted_class_id = int(predicted)

            self.assertEqual(predicted_class_id, expected_class_id)

            probabilities = _extract_probabilities(
                outputs=outputs,
                output_defs=session.get_outputs(),
                class_ids=class_ids,
            )
            if probabilities is None:
                continue
            expected_probabilities = np.asarray(
                case["expected_probabilities"],
                dtype=np.float64,
            )
            self.assertEqual(probabilities.shape, expected_probabilities.shape)
            self.assertTrue(
                np.allclose(
                    probabilities,
                    expected_probabilities,
                    atol=1e-4,
                    rtol=1e-4,
                )
            )


def _extract_predicted_label(outputs: list[Any], output_defs: list[Any]) -> Any:
    for index, output in enumerate(outputs):
        output_name = output_defs[index].name.lower() if index < len(output_defs) else ""
        if "label" not in output_name:
            continue
        parsed = _extract_scalar(output)
        if parsed is not None:
            return parsed

    for output in outputs:
        parsed = _extract_scalar(output)
        if parsed is not None:
            return parsed

    probabilities = _extract_probabilities(outputs, output_defs, class_ids=[])
    if probabilities is None or probabilities.size == 0:
        raise AssertionError("Unable to parse ONNX outputs into class prediction.")
    return int(np.argmax(probabilities))


def _extract_scalar(output: Any) -> Optional[Any]:
    if isinstance(output, np.ndarray):
        flat = output.reshape(-1)
        if flat.size == 0:
            return None
        return flat[0].item()
    if isinstance(output, (list, tuple)):
        if not output:
            return None
        first = output[0]
        if isinstance(first, dict):
            return None
        if isinstance(first, (list, tuple, np.ndarray)):
            return _extract_scalar(first)
        return first
    if isinstance(output, dict):
        return None
    return output


def _extract_probabilities(
    outputs: list[Any],
    output_defs: list[Any],
    class_ids: Iterable[int],
) -> Optional[np.ndarray]:
    for index, output in enumerate(outputs):
        output_name = output_defs[index].name.lower() if index < len(output_defs) else ""
        if "prob" not in output_name and not _looks_like_probability_output(output):
            continue
        parsed = _as_probability_array(output, class_ids)
        if parsed is not None:
            return parsed
    for output in outputs:
        parsed = _as_probability_array(output, class_ids)
        if parsed is not None:
            return parsed
    return None


def _looks_like_probability_output(output: Any) -> bool:
    if isinstance(output, np.ndarray):
        return output.ndim >= 1 and output.size > 1
    if isinstance(output, (list, tuple)):
        if not output:
            return False
        first = output[0]
        return isinstance(first, (dict, list, tuple, np.ndarray, float, int))
    if isinstance(output, dict):
        return True
    return False


def _as_probability_array(output: Any, class_ids: Iterable[int]) -> Optional[np.ndarray]:
    ordered_class_ids = [int(class_id) for class_id in class_ids]
    if isinstance(output, np.ndarray):
        if output.ndim == 1:
            return output.astype(np.float64)
        if output.ndim >= 2 and output.shape[0] > 0:
            return output[0].astype(np.float64)
        return None

    if isinstance(output, (list, tuple)):
        if not output:
            return None
        first = output[0]
        if isinstance(first, dict):
            return _map_probabilities(first, ordered_class_ids)
        if isinstance(first, (list, tuple, np.ndarray)):
            arr = np.asarray(first, dtype=np.float64)
            return arr if arr.size > 0 else None
        arr = np.asarray(output, dtype=np.float64)
        return arr if arr.size > 1 else None

    if isinstance(output, dict):
        return _map_probabilities(output, ordered_class_ids)
    return None


def _map_probabilities(
    probability_map: dict[Any, Any],
    class_ids: list[int],
) -> Optional[np.ndarray]:
    if not probability_map:
        return None
    parsed_map: dict[int, float] = {}
    for key, value in probability_map.items():
        if isinstance(key, int):
            parsed_key = key
        elif isinstance(key, float) and key.is_integer():
            parsed_key = int(key)
        else:
            try:
                parsed_key = int(str(key))
            except ValueError:
                return None
        parsed_map[int(parsed_key)] = float(value)

    if class_ids:
        return np.asarray(
            [parsed_map.get(class_id, 0.0) for class_id in class_ids],
            dtype=np.float64,
        )

    ordered_keys = sorted(parsed_map.keys())
    return np.asarray([parsed_map[key] for key in ordered_keys], dtype=np.float64)


if __name__ == "__main__":
    unittest.main()
