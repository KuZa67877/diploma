import 'package:equatable/equatable.dart';

class ReportExportOption extends Equatable {
  final String id;
  final String labelKey;
  final bool useLocalization;
  final String iconKey;
  final String colorKey;

  const ReportExportOption({
    required this.id,
    required this.labelKey,
    required this.useLocalization,
    required this.iconKey,
    required this.colorKey,
  });

  @override
  List<Object> get props => [id, labelKey, useLocalization, iconKey, colorKey];
}
