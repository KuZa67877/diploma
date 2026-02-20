import 'package:equatable/equatable.dart';

class SplashData extends Equatable {
  final String appName;
  final String tagline;
  final int durationMs;

  const SplashData({
    required this.appName,
    required this.tagline,
    required this.durationMs,
  });

  @override
  List<Object> get props => [appName, tagline, durationMs];
}
