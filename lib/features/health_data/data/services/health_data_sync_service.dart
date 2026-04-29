import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/repositories/health_data_repository.dart';

class HealthDataSyncService with WidgetsBindingObserver {
  static const Duration _periodicInterval = Duration(minutes: 30);
  static const Duration _resumeThrottle = Duration(minutes: 5);

  final HealthDataRepository _repository;
  final _logger = AppLogger.instance;

  Timer? _timer;
  bool _started = false;
  bool _syncInProgress = false;
  DateTime? _lastSyncAtUtc;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  HealthDataSyncService(this._repository);

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      _periodicInterval,
      (_) => unawaited(_triggerSync(reason: 'periodic')),
    );
    unawaited(_triggerSync(reason: 'startup'));
  }

  void dispose() {
    if (!_started) {
      return;
    }
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow({String reason = 'manual'}) {
    return _triggerSync(reason: reason, force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      final lastSyncAtUtc = _lastSyncAtUtc;
      if (lastSyncAtUtc != null &&
          DateTime.now().toUtc().difference(lastSyncAtUtc) < _resumeThrottle) {
        return;
      }
      unawaited(_triggerSync(reason: 'resume'));
    }
  }

  Future<void> _triggerSync({
    required String reason,
    bool force = false,
  }) async {
    if (!_started || _syncInProgress) {
      return;
    }
    if (!force &&
        reason == 'periodic' &&
        _lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _syncInProgress = true;
    try {
      _logger.info(
        'health.sync',
        'Starting health data sync',
        payload: {'reason': reason},
      );
      final result = await _repository.syncConnectedSources();
      result.fold(
        (failure) => _logger.warning(
          'health.sync',
          'Health data sync failed',
          payload: {'reason': reason, 'error': failure.message},
        ),
        (_) => _logger.info(
          'health.sync',
          'Health data sync finished',
          payload: {'reason': reason},
        ),
      );
      _lastSyncAtUtc = DateTime.now().toUtc();
    } finally {
      _syncInProgress = false;
    }
  }
}
