import 'package:equatable/equatable.dart';

class HeartRateSample extends Equatable {
  final int hour;
  final int bpm;

  const HeartRateSample({
    required this.hour,
    required this.bpm,
  });

  @override
  List<Object> get props => [hour, bpm];
}
