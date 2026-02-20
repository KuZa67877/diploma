import 'package:flutter/material.dart';

/// UI-модель источника данных здоровья.
class HealthSourceUiModel {
  /// Идентификатор источника.
  final String id;

  /// Название источника.
  final String name;

  /// Описание источника.
  final String description;

  /// Иконка источника.
  final IconData icon;

  /// Цвет иконки.
  final Color iconColor;

  /// Цвет фона иконки.
  final Color iconBackground;

  /// Признак подключения.
  final bool isConnected;

  /// Признак доступности.
  final bool isAvailable;

  /// Ключи поддерживаемых метрик.
  final List<String> metricKeys;

  /// Создает UI-модель источника.
  const HealthSourceUiModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.isConnected,
    required this.isAvailable,
    required this.metricKeys,
  });

  /// Возвращает копию с измененными параметрами.
  HealthSourceUiModel copyWith({
    bool? isConnected,
    bool? isAvailable,
  }) {
    return HealthSourceUiModel(
      id: id,
      name: name,
      description: description,
      icon: icon,
      iconColor: iconColor,
      iconBackground: iconBackground,
      isConnected: isConnected ?? this.isConnected,
      isAvailable: isAvailable ?? this.isAvailable,
      metricKeys: metricKeys,
    );
  }
}
