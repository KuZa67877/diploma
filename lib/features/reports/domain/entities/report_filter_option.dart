import 'package:equatable/equatable.dart';

class ReportFilterOption extends Equatable {
  final String id;
  final String labelKey;

  const ReportFilterOption({
    required this.id,
    required this.labelKey,
  });

  @override
  List<Object> get props => [id, labelKey];
}
