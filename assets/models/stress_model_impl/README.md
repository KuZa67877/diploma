# StressScoreModel v1

Классическая модель оценки стрессовой нагрузки для Flutter-приложения.
Нейросети не используются.

## Что внутри

- `build_stress_artifacts.py` - training/export pipeline.
- `build_app_stress_dataset.py` - сбор app-labeled датасета из `health_model_outputs` + EMA.
- `wesad_adapter.py` - адаптер WESAD в health-compatible CSV.
- `feature_contract_stress_v1.json` - legacy контракт для старых WESAD-фич.
- `requirements.txt` - Python-зависимости.
- `lib/features/dashboard/data/services/stress_inference_model.dart` - Flutter runtime.

## Архитектура

Production v1:

- deploy-модель: L2 logistic regression / scorecard;
- calibration: Platt sigmoid по out-of-fold subject-wise предсказаниям;
- benchmark-модель: `HistGradientBoostingClassifier`, только для отчета и сравнения;
- export: JSON `assets/models/stress/scorecard_v1.json`;
- Flutter inference: локально читает JSON, строит те же фичи и считает calibrated probability.

Такой формат выбран потому, что он интерпретируемый, легкий для on-device inference и не требует Python/ONNX на телефоне.

## Поддерживаемые входы

Основные каналы из `package:health`:

- `HEART_RATE`
- `RESTING_HEART_RATE`
- `WALKING_HEART_RATE`
- `HEART_RATE_VARIABILITY_SDNN`
- `HEART_RATE_VARIABILITY_RMSSD`
- `RESPIRATORY_RATE`
- `STEPS`
- `DISTANCE_WALKING_RUNNING`
- `ACTIVE_ENERGY_BURNED`
- `EXERCISE_TIME`
- `WORKOUT`
- `BODY_TEMPERATURE`
- `SKIN_TEMPERATURE`
- `SLEEP_WRIST_TEMPERATURE`
- `BLOOD_OXYGEN`
- sleep stages/session
- heart-rate event flags

Модель работает с пропусками через imputation + missing flags, но runtime блокирует ML-результат без heart-rate или при низком quality score.

## Обучение на данных из приложения

1. Применить миграцию Supabase:

```bash
supabase db push
```

2. Накопить данные:

- `health_model_outputs` - runtime-фичи и текущие score/fallback-результаты;
- `wellbeing_entries` - EMA-оценки `stress_now`, `fatigue`, `wellness` по шкале 1-5.

3. Выгрузить обе таблицы в CSV/JSON/JSONL. Минимальный фильтр для outputs:

```sql
select *
from public.health_model_outputs
where model_id = 'stress_score_v1'
order by subject_id, window_end;
```

4. Собрать обучающий датасет:

```bash
python3 assets/models/stress_model_impl/build_app_stress_dataset.py \
  --model_outputs ./data/health_model_outputs.csv \
  --wellbeing_entries ./data/wellbeing_entries.csv \
  --out_csv ./data/app_stress_training.csv \
  --report_json ./data/app_stress_training_report.json \
  --timezone_offset_hours 3
```

Builder соединяет EMA с ближайшим stress output того же пользователя и локального дня, по умолчанию в пределах `18` часов. Target:

- `label`: `stress_now >= 4`;
- `target_score`: weighted score из `stress_now`, `fatigue`, инвертированного `wellness`;
- `sample_weight`: ниже для нейтрального стресса `3/5`, низкого confidence и неполной EMA.

5. Переобучить deploy scorecard:

```bash
python3 assets/models/stress_model_impl/build_stress_artifacts.py \
  --input_csv ./data/app_stress_training.csv \
  --output_dir assets/models/stress \
  --model_id stress-score-v1
```

После этого Flutter использует обновленный `assets/models/stress/scorecard_v1.json` локально, без Python/ONNX.

## Обучение на своем health/EMA CSV

Минимальные поля:

- `subject_id`
- `window_start`
- `label` (`0/1`, `baseline/stress`, `low/high`)

Лучше добавить EMA:

- `stress_now_1_5`
- `fatigue_1_5`
- `wellbeing_1_5`

Если `label` отсутствует, pipeline может построить binary label из `stress_now_1_5`: `>=4` как stress.

Пример:

```bash
python3 assets/models/stress_model_impl/build_stress_artifacts.py \
  --input_csv ./data/stress_health_windows.csv \
  --output_dir assets/models/stress \
  --model_id stress-score-v1
```

## Обучение на WESAD benchmark

Если есть исходный WESAD:

```bash
python3 assets/models/stress_model_impl/wesad_adapter.py \
  --wesad_root assets/models/stress_model_impl/WESAD \
  --out_csv assets/models/stress_model_impl/wesad_features.csv
```

Затем:

```bash
python3 assets/models/stress_model_impl/build_stress_artifacts.py \
  --input_csv assets/models/stress_model_impl/wesad_features.csv \
  --output_dir assets/models/stress \
  --model_id stress-score-v1
```

## Экспортируемые артефакты

- `assets/models/stress/scorecard_v1.json` - deploy-модель для Flutter.
- `assets/models/stress/feature_contract_stress_v2.json` - контракт runtime-фич.
- `assets/models/stress/model_metadata.json` - краткие метаданные и метрики.
- `assets/models/stress/training_report.json` - полный отчет обучения.
- `assets/models/stress/split_manifest.json` - subject-wise split.
- `assets/models/stress/parity_fixture.json` - fixture для проверки parity Python/Dart.

`feature_contract_stress_v2.json` включает runtime-окна `5 / 15 / 60 / 1440` минут. После переобучения deploy scorecard может использовать как базовые признаки, так и 5-минутные признаки `hr_*_5m`, `hr_z_5m_14`, `steps_5m`, `active_energy_5m`.

## Ограничения качества

WESAD полезен как benchmark, но не равен Apple Watch / HealthKit:

- WESAD содержит лабораторный стресс, а не повседневный стресс;
- часть HealthKit-метрик там отсутствует и заполняется missing flags;
- финальную точность нужно подтверждать на EMA-данных из приложения.

Текущие WESAD-метрики лежат в `assets/models/stress/training_report.json`.
