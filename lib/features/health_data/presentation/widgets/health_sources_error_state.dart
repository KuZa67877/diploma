import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

/// Отображает ошибку загрузки источников данных.
class HealthSourcesErrorState extends StatelessWidget {
  /// Сообщение об ошибке.
  final String message;

  /// Коллбек повторной загрузки.
  final VoidCallback onRetry;

  /// Создает виджет ошибки.
  const HealthSourcesErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(localizations.get('retry')),
            ),
          ],
        ),
      ),
    );
  }
}
