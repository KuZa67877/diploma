# MediAI - AI-powered Health Diagnostics

Мобильное приложение для мониторинга здоровья с использованием искусственного интеллекта.


<img width="2094" height="2727" alt="MediAI App Redesign Flow" src="https://github.com/user-attachments/assets/5c36460b-bf62-40c3-8d6e-2bbeca670d10" />

## Архитектура

Приложение построено по принципам **Clean Architecture** с **Feature-first** организацией:

```
lib/
├── core/                      # Общая функциональность
│   ├── constants/            # Цвета, стили, константы
│   ├── error/                # Обработка ошибок
│   ├── localization/         # Локализация
│   ├── theme/                # Темы приложения
│   ├── utils/                # Утилиты
│   └── widgets/              # Переиспользуемые виджеты
├── features/                  # Функциональные модули
│   ├── onboarding/           # Онбординг
│   ├── auth/                 # Авторизация
│   ├── dashboard/            # Главный экран
│   ├── data_input/           # Ввод данных
│   ├── analytics/            # Аналитика
│   ├── reports/              # Отчёты
│   └── profile/              # Профиль
└── main.dart                  # Точка входа
```

## Технологии

- **Flutter** 3.8.1+
- **flutter_bloc** - Управление состоянием
- **get_it** - Dependency Injection
- **dartz** - Функциональное программирование
- **fl_chart** - Графики и диаграммы
- **google_fonts** - Шрифт Inter
- **lucide_icons** - Иконки
- **shared_preferences** - Локальное хранилище
- **go_router** - Навигация

## Установка

Для запуска проекта в корне репо лежит apk `app-dev-release.apk`, достаточно установить его себе на девайс.

Если требуется запустить проект для дебаг режима (необходима предварительная установка Flutter):

1. Клонируйте репозиторий:
```bash
git clone <repository-url>
cd medi_ai
```

2. Установите зависимости:
```bash
flutter pub get
```

3. Запустите приложение:
```bash
# Android
flutter run

# iOS
flutter run -d ios

```

## Обучение модели качества сна

В проект добавлен скрипт обучения и сборки ONNX-артефактов:
`scripts/ml/build_sleep_quality_artifacts.py`.

По умолчанию используется датасет In-situ wearable HRV + sleep diaries (Figshare, 2025).
Если In-situ недоступен, скрипт автоматически переключается на sleep-accel (PhysioNet).

```bash
# Авто-режим (In-situ -> fallback sleep-accel)
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto

# Явно использовать только sleep-accel
python3 scripts/ml/build_sleep_quality_artifacts.py --source sleep_accel

# Оценка как персональная модель (по времени внутри каждого пользователя)
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --split-mode temporal_per_user

# Оценка на unseen users
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --split-mode group_holdout

# Режимы признаков:
# health_contract — production-контракт из признаков, которые реально можно собрать из package:health
# both — обучить/сравнить варианты и выбрать лучший
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --feature-mode health_contract
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --feature-mode both

# Multi-target (дополнительно обучает component-модели):
# efficiency, duration, fragmentation
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --objective multi_target

# Политика выбора prod-модели:
# nn_only (по умолчанию) — всегда публикует MLP, XGBoost остаётся бенчмарком
# best_mae — публикует лучшую по MAE модель
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --selection-policy nn_only
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --selection-policy best_mae

# Для ВКР-режима с обязательной нейросетью на полном In-situ датасете:
# student_residual_mlp обучается на sensor_hrv.csv, с platform-aware аугментацией
# под iOS/Android и с downweighted sleep-latency target для лучшего переноса
# на сигналы из package:health
python3 scripts/ml/build_sleep_quality_artifacts.py \
  --source in_situ \
  --feature-mode health_contract \
  --objective multi_target \
  --selection-policy nn_only \
  --in-situ-hrv-file sensor_hrv.csv \
  --no-download

# Quality gate для nn_only:
# сборка падает, если MLP хуже XGBoost по MAE больше чем на 10% (по умолчанию)
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --quality-gate-ratio 0.10

# Запуск без скачивания (только по уже локально подготовленным данным)
python3 scripts/ml/build_sleep_quality_artifacts.py --source auto --no-download
```

Артефакты для Flutter сохраняются в:
- `assets/models/sleep_quality/model_sleep_quality.onnx`
- `assets/models/sleep_quality/preprocessor_v2.json`
- `assets/models/sleep_quality/feature_contract_health_v2.json`
- `assets/models/sleep_quality/model_metadata.json`

При `--objective multi_target` дополнительно сохраняются component ONNX-модели:
- `assets/models/sleep_quality/components/model_efficiency.onnx`
- `assets/models/sleep_quality/components/model_duration.onnx`
- `assets/models/sleep_quality/components/model_fragmentation.onnx`
