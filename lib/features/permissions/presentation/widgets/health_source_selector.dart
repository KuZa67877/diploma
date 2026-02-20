import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/permissions_ui_models.dart';
import 'health_source_card.dart';

class HealthSourceSelector extends StatelessWidget {
  final List<HealthSourceUiModel> sources;
  final String? selectedSourceId;
  final ValueChanged<String> onSelectSource;

  const HealthSourceSelector({
    super.key,
    required this.sources,
    required this.selectedSourceId,
    required this.onSelectSource,
  });

  @override
  Widget build(BuildContext context) {
    final sourceWidgets = <Widget>[
      ...sources.map((source) {
        final isSelected = source.id == selectedSourceId;
        return Expanded(
          child: HealthSourceCard(
            source: source,
            isSelected: isSelected,
            onSelected: () => onSelectSource(source.id),
          ),
        );
      }),
    ];

    if (sourceWidgets.length > 1) {
      sourceWidgets.insert(
        1,
        const SizedBox(width: AppConstants.spacingMd),
      );
    }

    return Row(children: sourceWidgets);
  }
}
