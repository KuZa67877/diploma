import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_request_size.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_usage_limits.dart';
import 'package:medi_ai/features/ai_assistant/domain/services/ai_usage_limiter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiUsageLimiterService', () {
    late SharedPreferences preferences;
    late AiUsageLimiterService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      service = AiUsageLimiterService(sharedPreferences: preferences);
    });

    test('allows request within limits', () async {
      final result = await service.canSendRequest(
        estimatedInputTokens: 800,
        requestSize: AiRequestSize.small,
        limits: const AiUsageLimits.defaults(),
        now: DateTime(2026, 5, 1, 9),
      );

      expect(result.allowed, isTrue);
      expect(result.message, isNull);
    });

    test('blocks request after max requests per day is exceeded', () async {
      final now = DateTime(2026, 5, 1, 9);
      const limits = AiUsageLimits(
        maxRequestsPerDay: 1,
        maxLargeRequestsPerDay: 3,
        maxEstimatedInputTokensPerDay: 30000,
        minDelayBetweenRequestsSeconds: 0,
        maxMessagesInContext: 8,
      );

      await service.registerRequest(
        estimatedInputTokens: 400,
        requestSize: AiRequestSize.small,
        now: now,
      );

      final result = await service.canSendRequest(
        estimatedInputTokens: 400,
        requestSize: AiRequestSize.small,
        limits: limits,
        now: now.add(const Duration(minutes: 1)),
      );

      expect(result.allowed, isFalse);
      expect(result.message, contains('Дневной лимит AI-запросов'));
    });

    test('enforces delay between requests', () async {
      final now = DateTime(2026, 5, 1, 9);

      await service.registerRequest(
        estimatedInputTokens: 400,
        requestSize: AiRequestSize.small,
        now: now,
      );

      final result = await service.canSendRequest(
        estimatedInputTokens: 200,
        requestSize: AiRequestSize.small,
        limits: const AiUsageLimits.defaults(),
        now: now.add(const Duration(seconds: 10)),
      );

      expect(result.allowed, isFalse);
      expect(result.message, contains('Подождите ещё'));
    });

    test('resets counters on the next day', () async {
      await service.registerRequest(
        estimatedInputTokens: 400,
        requestSize: AiRequestSize.small,
        now: DateTime(2026, 5, 1, 9),
      );

      final dayTwoStats = await service.getStats(now: DateTime(2026, 5, 2, 9));

      expect(dayTwoStats.requestsToday, 0);
      expect(dayTwoStats.estimatedInputTokensToday, 0);
      expect(dayTwoStats.largeRequestsToday, 0);
    });
  });
}
