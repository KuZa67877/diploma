# Harvard AW Model Card

## Model Overview

- **Model ID**: `harvard-aw-xgb-v2`
- **Task**: многоклассовая классификация активности
- **Алгоритм**: `XGBoostClassifier` (`multi:softprob`), экспорт в ONNX
- **Вход модели**: float-тензор с именем `float_input`
- **Число признаков**: 16
- **Классы**:
  - `Lying`
  - `Sitting`
  - `Self Pace walk`
  - `Running 3 METs`
  - `Running 5 METs`
  - `Running 7 METs`

## Intended Use

- Локальная on-device рекомендация активности в dashboard экране.
- Использование внутри runtime-контракта MediAI (Flutter + ONNX Runtime).
- Исследовательская персональная аналитика активности на основе wearable-признаков.

## Out-of-Scope Use

- Клиническая диагностика и медицинские заключения.
- Использование как единственного сигнала для принятия high-stakes решений.
- Использование на данных, не соответствующих ожидаемому feature-контракту preprocessor.

## Training Data

- **Dataset source**: `kaggle_apple_watch_and_fitbit_data`
- **Dataset URI**: `kaggle://aleespinosa/apple-watch-and-fitbit-data/data_for_weka_aw.csv`
- **Dataset version**: `1`
- **Dataset SHA256**: `8f224d5a7ebad5ff62cf12e52dc50f750f4c5dcaed84d8465e9ed7bc4c6711c0`
- **Target column**: `activity_trimmed`
- **Total rows (после чтения CSV)**: `3656`

## Feature Engineering

Базовые признаки из датасета дополняются синтетическими признаками в `AppleWatchSyntheticFeatures`:

- `NormalizedApplewatchHeartrate_LE`
- `SDNormalizedApplewatchHR_LE`
- `ApplewatchIntensity_LE`
- `CorrelationApplewatchHeartrateSteps_LE`
- `ApplewatchStepsXDistance_LE`

Используется версия feature engineering: `harvard-fe-v2`.

## Preprocessing

- Медианная имputation для числовых признаков.
- `StandardScaler` (mean/std из train split).
- One-hot encoder поддерживается инфраструктурно, но в текущем артефакте категориальные признаки отсутствуют.
- Manifest preprocessora: `harvard-preprocessor-v2`.

## Validation Protocol

- Основная стратегия в текущем артефакте: `stratified_shuffle_split`.
- Размеры сплитов: train `2632` (71.99%), val `658` (17.99%), test `366` (10.01%).
- **Anti-leakage policy**:
  - если в датасете найдена валидная group-колонка (`participant_id`, `subject_id`, `session_id` и т.д.), pipeline использует group-aware split (`GroupShuffleSplit`) с проверкой отсутствия пересечения групп между train/val/test;
  - при отсутствии групповых идентификаторов pipeline fallback-ится на stratified split по таргету.
- Test split не используется для подбора hyperparameters или early stopping.

## Metrics

Текущие test-метрики из `assets/models/harvard_aw/model_metadata.json`:

- **Accuracy**: `0.5738`
- **Balanced accuracy**: `0.5626`
- **Macro F1**: `0.5667`
- **Weighted F1**: `0.5717`
- **Log loss**: `1.0812`
- **Macro precision / recall / F1**: `0.6160 / 0.5626 / 0.5667`
- **Weighted precision / recall / F1**: `0.6130 / 0.5738 / 0.5717`

Класс-уровень (precision / recall / f1):

- `Lying`: `0.4717 / 0.6329 / 0.5405`
- `Sitting`: `0.3765 / 0.5818 / 0.4571`
- `Self Pace walk`: `0.5667 / 0.3208 / 0.4096`
- `Running 3 METs`: `0.6875 / 0.3860 / 0.4944`
- `Running 5 METs`: `0.8333 / 0.5833 / 0.6863`
- `Running 7 METs`: `0.7606 / 0.8710 / 0.8120`

Confusion matrix хранится в metadata (6x6) и должна анализироваться вместе с class-support.

## Artifacts

Точные runtime-файлы в `assets/models/harvard_aw`:

- `assets/models/harvard_aw/model_harvardAWData_xgboost.onnx`
- `assets/models/harvard_aw/preprocessor_v1.json`
- `assets/models/harvard_aw/preprocessor_v2.json`
- `assets/models/harvard_aw/model_metadata.json`

Сопутствующие build-артефакты:

- `build/ml/harvard_aw/model_xgboost.joblib`
- `build/ml/harvard_aw/split_manifest.json`
- `build/ml/harvard_aw/training_report.json`
- `build/ml/harvard_aw/parity_fixture_v2.json`

## Runtime Integration

Модель читается и используется в Flutter через:

- `lib/features/dashboard/data/services/harvard_activity_recommendation_model.dart`

Ключевые asset-константы runtime:

- `kHarvardModelAssetPath`
- `kHarvardPreprocessorV2AssetPath`
- `kHarvardPreprocessorV1AssetPath`
- `kHarvardMetadataAssetPath`

`model_metadata.json` используется для чтения `model_version`; при ошибке загрузки применяется fallback-версия.

## Limitations

- Умеренное качество на части классов (`Sitting`, `Self Pace walk`, `Running 3 METs`).
- Потенциальный domain shift между train-датаcетом и реальными пользовательскими сигналами.
- При отсутствии групповых идентификаторов anti-leakage ограничен stratified random split.
- Чувствительность к качеству входных wearable-признаков и пропускам.

## Risk & Ethics

- Модель не предназначена для диагностики заболеваний.
- Выходы модели не должны использоваться как медицинские рекомендации.
- Требуются прозрачные пользовательские дисклеймеры и возможность отказа от ML-рекомендаций.
- Для продвинутого применения требуется дополнительная валидация на целевой популяции.

## Versioning & Changelog

- `harvard-aw-xgb-v2`: текущая версия runtime-модели.
- `harvard-preprocessor-v2`: текущий preprocessor manifest.
- `harvard-aw-pipeline-v3`: версия training pipeline (metadata field `training_pipeline_version`).

Изменения в рамках `pipeline-v3`:

- нормализованы dataset metadata поля (`dataset_source`, `dataset_uri`, `dataset_sha256`, `dataset_version`);
- добавлен `generated_at_utc`;
- добавлена валидация сериализуемых артефактов с ошибкой при обнаружении абсолютных локальных путей.

## Reproducibility Steps

1. Из корня репозитория создать venv и установить зависимости:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

2. Подготовить датасет Harvard CSV (например `./datasets/harvard_aw/data_for_weka_aw.csv`).

3. Запустить сборку артефактов:

```bash
python3 scripts/ml/build_harvard_aw_artifacts.py \
  --dataset-path ./datasets/harvard_aw/data_for_weka_aw.csv \
  --dataset-source kaggle_apple_watch_and_fitbit_data \
  --dataset-uri kaggle://aleespinosa/apple-watch-and-fitbit-data/data_for_weka_aw.csv \
  --dataset-version 1 \
  --output-dir assets/models/harvard_aw \
  --report-dir build/ml/harvard_aw
```

4. Проверить наличие файлов в `assets/models/harvard_aw` и `build/ml/harvard_aw`.

5. Проверить, что в `model_metadata.json` отсутствуют абсолютные пути и присутствуют:

- `dataset_source`
- `dataset_uri`
- `dataset_sha256`
- `dataset_version`
- `generated_at_utc`
- `training_pipeline_version`
