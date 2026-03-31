import 'app_log_level.dart';

class AppLogEntry {
  final DateTime timestamp;
  final AppLogLevel level;
  final String category;
  final String message;
  final String? payload;

  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.payload,
  });
}
