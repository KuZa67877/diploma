import 'package:equatable/equatable.dart';

class DashboardInsight extends Equatable {
  final String titleKey;
  final String descKey;

  const DashboardInsight({
    required this.titleKey,
    required this.descKey,
  });

  @override
  List<Object> get props => [titleKey, descKey];
}
