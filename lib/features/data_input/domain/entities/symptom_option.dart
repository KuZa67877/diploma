import 'package:equatable/equatable.dart';

class SymptomOption extends Equatable {
  final String id;
  final String labelKey;

  const SymptomOption({
    required this.id,
    required this.labelKey,
  });

  @override
  List<Object> get props => [id, labelKey];
}
