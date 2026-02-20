import 'package:equatable/equatable.dart';

class ActivitySample extends Equatable {
  final String label;
  final int steps;

  const ActivitySample({
    required this.label,
    required this.steps,
  });

  @override
  List<Object> get props => [label, steps];
}
