# Sleep Health Feature Contract v1

Цель: фиксированный контракт фич для модели сна, который можно стабильно собрать из `package:health` в приложении.

## Почему это нужно

Предыдущая итерация выбирала `personal_full` по метрике, где признаки `diary_*` частично совпадали с таргетом и давали утечку. Такой режим не переносится в прод, потому что в runtime у пользователя нет этих `diary_*` полей.

## Контракт данных

Версия: `sleep-health-contract-v1`.

Источник истины в артефактах модели:
- `assets/models/sleep_quality/feature_contract_health_v1.json`

### Обязательные типы метрик (`package:health`)

- `sleepAsleep`
- `heartRate`
- `steps`

### Опциональные метрики (улучшают качество)

- `sleepInBed`
- `sleepAwake`
- `sleepDeep`
- `sleepRem`
- `restingHeartRate`
- `heartRateVariabilitySdnn`
- `heartRateVariabilityRmssd`
- `activeEnergyBurned`
- `totalCaloriesBurned`
- `distanceWalkingRunning`
- `distanceDelta`

## Контракт фич

Модель использует только health-совместимые признаки:

- Ночные агрегаты HR: `HR_{mean,std,min,max,p10,p90}`
- Агрегаты активности: `steps_*`, `distance_*`, `calories_*`
- Агрегаты HRV: `sdnn_*`, `rmssd_*`
- Плотность наблюдений: `window_count`, `coverage_hours`, `window_density`
- Расписание сна: `asleep_hour`, `wakeup_hour`, `weekday`, `sleep_window_hours_clock`
- Динамика в окне: `hr_trend`
- Персональные baseline-фичи 7 ночей: `*_baseline7`, `*_delta7`, `*_z7`
- `nights_since_start`

`diary_*` и `survey_*` исключены из production-контракта.

Практическая деталь для текущего приложения:
- в `HealthMetricSample` хранится `timestamp = dateTo` и `value`.
- для sleep-типов `package:health` возвращает `value` в минутах интервала сна.
- поэтому границы сегмента можно восстановить как:
  - `segment_end = timestamp`
  - `segment_start = timestamp - Duration(minutes: value)`

## Минимальные требования к данным (для запуска инференса)

- История: минимум `14` дней.
- Ночей сна: минимум `5` ночей для инференса.
- Для baseline-фич: минимум `7` ночей.

Если минимум не выполнен:
- модель не должна возвращать финальный score;
- UI показывает `insufficient data` и просит продолжить синк сна/пульса/шагов.

## Правило надежности

Даже при наличии обязательных типов:
- при сильной дырявости данных (`coverage_hours` слишком низкий) нужно снижать confidence или блокировать вывод.
- confidence должен зависеть от покрытия ключевых сигналов (`sleep + HR + steps`) за последние 7-14 дней.

## Рекомендуемый запуск обучения

```bash
python3 scripts/ml/build_sleep_quality_artifacts.py \
  --source auto \
  --split-mode temporal_per_user \
  --feature-mode health_contract
```

## Проверка перед внедрением

1. `model_metadata.json` должен содержать `selected_feature_variant = "health_contract"` (или эквивалент production-режима) и блок `feature_contract` с coverage.
2. В `preprocessor_v1.json` фичи должны быть строго из health-контракта.
3. Flutter-инференс строит вектор по тем же именам и в том же порядке.
