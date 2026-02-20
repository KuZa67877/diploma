import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/health_date_range.dart';
import '../../domain/entities/health_metric_type.dart';
import '../models/health_metric_sample_model.dart';
import 'health_platform_mapper.dart';

/// Контракт интеграции с Google Fit.
abstract class GoogleFitDataSource {
  /// Признак доступности Google Fit на устройстве.
  bool get isAvailable;

  /// Запрашивает подключение к Google Fit.
  Future<void> connect();

  /// Отключает Google Fit.
  Future<void> disconnect();

  /// Возвращает измерения метрик из Google Fit.
  Future<List<HealthMetricSampleModel>> getSamples({
    required HealthDateRange range,
    List<HealthMetricType> types,
  });
}

/// Реализация Google Fit / Health Connect на базе пакета health.
class GoogleFitDataSourceImpl implements GoogleFitDataSource {
  final Health _health;
  bool _isAuthorized = false;

  /// Создает интеграцию Google Fit / Health Connect.
  GoogleFitDataSourceImpl({Health? health}) : _health = health ?? Health();

  @override
  bool get isAvailable => Platform.isAndroid;

  @override
  Future<void> connect() async {
    if (!isAvailable) return;
    await _health.configure();
    await _requestActivityRecognition();
    _isAuthorized = await _requestAuthorization(const []);
  }

  @override
  Future<void> disconnect() async {
    _isAuthorized = false;
  }

  @override
  Future<List<HealthMetricSampleModel>> getSamples({
    required HealthDateRange range,
    List<HealthMetricType> types = const [],
  }) async {
    if (!isAvailable) return const [];
    await _health.configure();
    await _requestActivityRecognition();
    final authorized = _isAuthorized || await _requestAuthorization(types);
    if (!authorized) return const [];

    final platformTypes = HealthPlatformMapper.toPlatformTypes(types);
    final points = await _health.getHealthDataFromTypes(
      startTime: range.start,
      endTime: range.end,
      types: platformTypes,
    );
    final unique = _health.removeDuplicates(points);
    return unique
        .map(
          (point) => HealthPlatformMapper.toSample(
            point,
            fallbackSourceId: 'google_fit',
          ),
        )
        .where((sample) => sample.type != HealthMetricType.unknown)
        .toList(growable: false);
  }

  Future<bool> _requestAuthorization(List<HealthMetricType> types) async {
    final platformTypes = HealthPlatformMapper.toPlatformTypes(types);
    final permissions = platformTypes
        .map((_) => HealthDataAccess.READ)
        .toList(growable: false);
    return _health.requestAuthorization(
      platformTypes,
      permissions: permissions,
    );
  }

  Future<void> _requestActivityRecognition() async {
    final status = await Permission.activityRecognition.status;
    if (status.isGranted) return;
    await Permission.activityRecognition.request();
  }
}
