import 'package:equatable/equatable.dart';

class HealthSourceOption extends Equatable {
  final String id;
  final String nameKey;
  final String descKey;
  final String iconKey;
  final List<String> gradientKeys;

  const HealthSourceOption({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.iconKey,
    required this.gradientKeys,
  });

  @override
  List<Object> get props => [id, nameKey, descKey, iconKey, gradientKeys];
}
