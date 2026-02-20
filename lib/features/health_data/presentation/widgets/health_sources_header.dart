import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';

/// Заголовок экрана источников данных здоровья.
class HealthSourcesHeader extends StatelessWidget {
  /// Коллбек возврата назад.
  final VoidCallback onBack;

  /// Создает заголовок.
  const HealthSourcesHeader({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}
