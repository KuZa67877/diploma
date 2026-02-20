import 'package:equatable/equatable.dart';

class AnalyticsFilterOption extends Equatable {
  final String id;
  final String labelKey;

  const AnalyticsFilterOption({
    required this.id,
    required this.labelKey,
  });

  @override
  List<Object> get props => [id, labelKey];
}
