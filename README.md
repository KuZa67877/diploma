# MediAI - AI-powered Health Diagnostics

Мобильное приложение для мониторинга здоровья с использованием искусственного интеллекта.



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
