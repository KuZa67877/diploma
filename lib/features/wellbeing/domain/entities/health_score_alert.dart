import 'package:equatable/equatable.dart';

class HealthScoreAlert extends Equatable {
  final String code;
  final String severity;
  final String message;

  const HealthScoreAlert({
    required this.code,
    required this.severity,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {'code': code, 'severity': severity, 'message': message};
  }

  @override
  List<Object> get props => [code, severity, message];
}
