import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../entities/ai_request_size.dart';
import '../entities/ai_usage_limits.dart';

class AiUsageLimiterService {
  static const String _storageKey = 'ai_assistant_usage_stats_v1';

  final SharedPreferences _sharedPreferences;

  const AiUsageLimiterService({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  Future<AiUsageStats> getStats({DateTime? now}) async {
    final stats = _readStats();
    return _normalizeForToday(stats, now: now);
  }

  Future<AiUsageCheckResult> canSendRequest({
    required int estimatedInputTokens,
    required AiRequestSize requestSize,
    required AiUsageLimits limits,
    DateTime? now,
  }) async {
    final current = await getStats(now: now);
    final effectiveNow = now ?? DateTime.now();

    if (current.requestsToday >= limits.maxRequestsPerDay) {
      return AiUsageCheckResult(
        allowed: false,
        message:
            'Дневной лимит AI-запросов в приложении исчерпан. Это ограничение нужно, чтобы не расходовать API сверх бесплатного/минимального режима.',
        stats: current,
      );
    }

    if (requestSize == AiRequestSize.large &&
        current.largeRequestsToday >= limits.maxLargeRequestsPerDay) {
      return AiUsageCheckResult(
        allowed: false,
        message:
            'Лимит больших AI-запросов на сегодня исчерпан. Попробуйте уменьшить объем данных или включить экономию токенов.',
        stats: current,
      );
    }

    if (current.estimatedInputTokensToday + estimatedInputTokens >
        limits.maxEstimatedInputTokensPerDay) {
      return AiUsageCheckResult(
        allowed: false,
        message:
            'Лимит входных токенов на сегодня исчерпан. Уменьшите объем данных или попробуйте позже.',
        stats: current,
      );
    }

    final lastRequestAt = current.lastRequestAt;
    if (lastRequestAt != null) {
      final diff = effectiveNow.difference(lastRequestAt).inSeconds;
      if (diff < limits.minDelayBetweenRequestsSeconds) {
        final remaining = limits.minDelayBetweenRequestsSeconds - diff;
        return AiUsageCheckResult(
          allowed: false,
          message:
              'Подождите ещё $remaining сек., чтобы не отправлять лишние запросы подряд.',
          stats: current,
        );
      }
    }

    return AiUsageCheckResult(
      allowed: true,
      message: null,
      stats: current,
    );
  }

  Future<AiUsageStats> registerRequest({
    required int estimatedInputTokens,
    required AiRequestSize requestSize,
    DateTime? now,
  }) async {
    final current = await getStats(now: now);
    final updated = current.copyWith(
      requestsToday: current.requestsToday + 1,
      largeRequestsToday: current.largeRequestsToday +
          (requestSize == AiRequestSize.large ? 1 : 0),
      estimatedInputTokensToday:
          current.estimatedInputTokensToday + estimatedInputTokens,
      lastRequestAt: now ?? DateTime.now(),
    );
    await _writeStats(updated);
    return updated;
  }

  Future<AiUsageStats> registerResponse({
    required int estimatedOutputTokens,
    DateTime? now,
  }) async {
    final current = await getStats(now: now);
    final updated = current.copyWith(
      estimatedOutputTokensToday:
          current.estimatedOutputTokensToday + estimatedOutputTokens,
    );
    await _writeStats(updated);
    return updated;
  }

  Future<void> resetDebugStats() async {
    if (!kDebugMode) {
      return;
    }
    await _sharedPreferences.remove(_storageKey);
  }

  AiUsageStats _readStats() {
    final raw = _sharedPreferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return AiUsageStats.empty(date: DateTime.now());
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AiUsageStats.empty(date: DateTime.now());
      }
      return AiUsageStats(
        date: DateTime.tryParse(decoded['date']?.toString() ?? '') ??
            DateTime.now(),
        requestsToday: _toInt(decoded['requestsToday']),
        largeRequestsToday: _toInt(decoded['largeRequestsToday']),
        estimatedInputTokensToday: _toInt(decoded['estimatedInputTokensToday']),
        estimatedOutputTokensToday:
            _toInt(decoded['estimatedOutputTokensToday']),
        lastRequestAt: DateTime.tryParse(
          decoded['lastRequestAt']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return AiUsageStats.empty(date: DateTime.now());
    }
  }

  Future<void> _writeStats(AiUsageStats stats) async {
    final payload = {
      'date': stats.date.toIso8601String(),
      'requestsToday': stats.requestsToday,
      'largeRequestsToday': stats.largeRequestsToday,
      'estimatedInputTokensToday': stats.estimatedInputTokensToday,
      'estimatedOutputTokensToday': stats.estimatedOutputTokensToday,
      'lastRequestAt': stats.lastRequestAt?.toIso8601String(),
    };
    await _sharedPreferences.setString(_storageKey, jsonEncode(payload));
  }

  AiUsageStats _normalizeForToday(AiUsageStats stats, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final sameDay = stats.date.year == effectiveNow.year &&
        stats.date.month == effectiveNow.month &&
        stats.date.day == effectiveNow.day;
    if (sameDay) {
      return stats;
    }
    return AiUsageStats.empty(date: effectiveNow);
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
