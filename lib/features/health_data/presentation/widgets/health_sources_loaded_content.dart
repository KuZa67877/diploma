import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/health_source_ui_model.dart';
import 'health_source_card.dart';
import 'health_sources_header.dart';

/// Контент со списком источников данных.
class HealthSourcesLoadedContent extends StatelessWidget {
  /// Список источников.
  final List<HealthSourceUiModel> sources;

  /// Идентификатор источника в процессе обновления.
  final String? updatingSourceId;

  /// Коллбек возврата назад.
  final VoidCallback onBack;

  /// Коллбек переключения подключения.
  final ValueChanged<String> onToggle;

  /// Создает контент со списком источников.
  const HealthSourcesLoadedContent({
    super.key,
    required this.sources,
    required this.updatingSourceId,
    required this.onBack,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthSourcesHeader(onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
              vertical: AppConstants.spacingMd,
            ),
            children: [
              Text(
                localizations.get('healthDataSources'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkForeground
                      : AppColors.lightForeground,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                localizations.get('healthSourcesSubtitle'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              ...sources.asMap().entries.map((entry) {
                final source = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key < sources.length - 1
                        ? AppConstants.spacingMd
                        : 0,
                  ),
                  child: HealthSourceCard(
                    source: source,
                    isUpdating: updatingSourceId == source.id,
                    onToggle: onToggle,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
