# MediAI

Мобильное приложение на Flutter для персонального мониторинга самочувствия и исследования поведенческих/физиологических паттернов на основе локальных ML-моделей.

## Feature map (`lib/features`)

- `analytics`
- `auth`
- `dashboard`
- `data_input`
- `diagnostics`
- `health_data`
- `onboarding`
- `permissions`
- `profile`
- `reports`
- `settings`
- `splash`
- `wellbeing`

## Технический стек

- Flutter (Dart SDK `^3.8.1`)
- `flutter_bloc`, `get_it`, `go_router`
- `supabase_flutter`
- `onnxruntime` (on-device inference)
- Python ML pipelines (`scripts/ml` + `assets/models/stress_model_impl`)

## Требования к окружению

- Flutter SDK c Dart `3.8.1` (или совместимая версия из ветки `3.8.x`)
- Android Studio/Xcode (в зависимости от целевой платформы)
- Python `3.9+`
- Доступ к shell из корня репозитория

## Быстрый запуск

Все команды ниже выполняются из корня репозитория.

### 1) APK-режим

Готовый APK уже лежит в репозитории:

```bash
ls -lh ./app-dev-release.apk
```

Установите `app-dev-release.apk` на Android-устройство любым удобным способом (`adb install`, Android File Transfer и т.д.).

### 2) Flutter debug-режим

```bash
flutter pub get
flutter run
```

Примеры:

```bash
flutter run -d android
flutter run -d ios
```

## Конфигурация `.env`

Пример шаблона: `.env.example`.

```bash
cp .env.example .env
```

Поля:

- Обязательные для удалённого Supabase-режима:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Опциональные:
  - `SUPABASE_REDIRECT_URL` (по умолчанию `io.supabase.medi_ai://login-callback`)
  - `ENABLE_SOCIAL_AUTH` (`false` по умолчанию)
  - `ENABLE_AUTH_BYPASS` (`false` по умолчанию)

Поведение при ненастроенном Supabase:

- если `SUPABASE_URL`/`SUPABASE_ANON_KEY` остаются плейсхолдерами, приложение не инициализирует Supabase клиент;
- авторизация работает в локальном/mock режиме;
- OAuth-вход через Google/Apple возвращает ошибку «Supabase не настроен».

## Python зависимости для ML

Канонический источник зависимостей: [`requirements.txt`](./requirements.txt).

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Файл `assets/models/stress_model_impl/requirements.txt` оставлен только как прокси и ссылается на root requirements.

## ML pipeline

### Harvard activity pipeline

Скрипт: `scripts/ml/build_harvard_aw_artifacts.py`

Вход:

- CSV датасет (`--dataset-path`), например `data_for_weka_aw.csv`

Выход:

- `assets/models/harvard_aw/model_harvardAWData_xgboost.onnx`
- `assets/models/harvard_aw/preprocessor_v1.json`
- `assets/models/harvard_aw/preprocessor_v2.json`
- `assets/models/harvard_aw/model_metadata.json`
- `build/ml/harvard_aw/model_xgboost.joblib`
- `build/ml/harvard_aw/split_manifest.json`
- `build/ml/harvard_aw/training_report.json`
- `build/ml/harvard_aw/parity_fixture_v2.json`

Команда:

```bash
python3 scripts/ml/build_harvard_aw_artifacts.py \
  --dataset-path ./datasets/harvard_aw/data_for_weka_aw.csv \
  --dataset-source kaggle_apple_watch_and_fitbit_data \
  --dataset-uri kaggle://aleespinosa/apple-watch-and-fitbit-data/data_for_weka_aw.csv \
  --dataset-version 1 \
  --output-dir assets/models/harvard_aw \
  --report-dir build/ml/harvard_aw
```

### Sleep quality pipeline

Скрипт: `scripts/ml/build_sleep_quality_artifacts.py`

Источники данных:

- primary: In-situ HRV + diary (Figshare `28509740`)
- fallback: PhysioNet sleep-accel

Выход:

- `assets/models/sleep_quality/model_sleep_quality.onnx`
- `assets/models/sleep_quality/preprocessor_v2.json`
- `assets/models/sleep_quality/feature_contract_health_v2.json`
- `assets/models/sleep_quality/model_metadata.json`
- `build/ml/sleep_quality/training_report.json`
- `build/ml/sleep_quality/split_manifest.json`
- `build/ml/sleep_quality/parity_fixture_v2.json`
- `build/ml/sleep_quality/models/model_*.joblib`

Команды:

```bash
# Автовыбор источника (in_situ -> fallback sleep_accel)
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto

# Строгий офлайн режим (без скачивания датасета)
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --no-download
```

### Stress pipeline

Скрипты:

- `assets/models/stress_model_impl/build_app_stress_dataset.py`
- `assets/models/stress_model_impl/build_stress_artifacts.py`

1. Подготовка обучающей выборки из app данных:

```bash
python3 assets/models/stress_model_impl/build_app_stress_dataset.py \
  --model_outputs ./data/health_model_outputs.csv \
  --wellbeing_entries ./data/wellbeing_entries.csv \
  --out_csv ./data/app_stress_training.csv \
  --report_json ./data/app_stress_training_report.json
```

2. Сборка stress артефактов:

```bash
python3 assets/models/stress_model_impl/build_stress_artifacts.py \
  --input_csv ./data/app_stress_training.csv \
  --output_dir assets/models/stress \
  --model_id stress-score-v1 \
  --dataset-source stress_app_health_windows \
  --dataset-uri local://user-provided-training-csv \
  --dataset-version v1
```

Выход:

- `assets/models/stress/scorecard_v1.json`
- `assets/models/stress/feature_contract_stress_v2.json`
- `assets/models/stress/model_metadata.json`
- `assets/models/stress/parity_fixture.json`
- `assets/models/stress/split_manifest.json`
- `assets/models/stress/training_report.json`

## Проверка команд pipeline

Быстрая проверка CLI (без обучения):

```bash
python3 scripts/ml/build_harvard_aw_artifacts.py --help
python3 scripts/ml/build_sleep_quality_artifacts.py --help
python3 assets/models/stress_model_impl/build_stress_artifacts.py --help
```

## Runtime интеграция артефактов

- Harvard runtime loader: `lib/features/dashboard/data/services/harvard_activity_recommendation_model.dart`
- Sleep runtime loader: `lib/features/dashboard/data/services/sleep_quality_inference_model.dart`
- Stress runtime loader: `lib/features/dashboard/data/services/stress_inference_model.dart`

Контракт по путям артефактов задаётся в `pubspec.yaml` (секция `flutter/assets`).

## Model card

- Harvard model card: `docs/model_card_harvard_aw.md`

## Ограничения и дисклеймер

- Приложение и ML-модели предназначены для исследовательских и образовательных целей.
- Это не медицинская диагностика и не замена консультации врача.
- Результаты inference могут быть неточными при пропусках данных, domain shift и слабом персональном baseline.
- Перед любым clinical/high-stakes применением требуется отдельная валидация на целевой популяции.
