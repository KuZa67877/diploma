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
  static const Duration _fetchChunk = Duration(days: 7);

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
    if (platformTypes.isEmpty || range.end.isBefore(range.start)) {
      return const [];
    }

    final points = await _fetchPointsInChunks(
      start: range.start,
      end: range.end,
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

  Future<List<HealthDataPoint>> _fetchPointsInChunks({
    required DateTime start,
    required DateTime end,
    required List<HealthDataType> types,
  }) async {
    final points = <HealthDataPoint>[];
    var cursor = start;

    while (!cursor.isAfter(end)) {
      final chunkEnd = _minDate(cursor.add(_fetchChunk), end);
      final chunk = await _health.getHealthDataFromTypes(
        startTime: cursor,
        endTime: chunkEnd,
        types: types,
      );
      points.addAll(chunk);
      if (chunkEnd.isAtSameMomentAs(end)) {
        break;
      }
      cursor = chunkEnd.add(const Duration(milliseconds: 1));
    }

    return points;
  }

  DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

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
