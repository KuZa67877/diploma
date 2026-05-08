import 'package:equatable/equatable.dart';

class AiUsageLimits extends Equatable {
  final int maxRequestsPerDay;
  final int maxLargeRequestsPerDay;
  final int maxEstimatedInputTokensPerDay;
  final int minDelayBetweenRequestsSeconds;
  final int maxMessagesInContext;

  const AiUsageLimits({
    required this.maxRequestsPerDay,
    required this.maxLargeRequestsPerDay,
    required this.maxEstimatedInputTokensPerDay,
    required this.minDelayBetweenRequestsSeconds,
    required this.maxMessagesInContext,
  });

  const AiUsageLimits.defaults()
    : maxRequestsPerDay = 20,
      maxLargeRequestsPerDay = 3,
      maxEstimatedInputTokensPerDay = 30000,
      minDelayBetweenRequestsSeconds = 20,
      maxMessagesInContext = 8;

  AiUsageLimits copyWith({
    int? maxRequestsPerDay,
    int? maxLargeRequestsPerDay,
    int? maxEstimatedInputTokensPerDay,
    int? minDelayBetweenRequestsSeconds,
    int? maxMessagesInContext,
  }) {
    return AiUsageLimits(
      maxRequestsPerDay: maxRequestsPerDay ?? this.maxRequestsPerDay,
      maxLargeRequestsPerDay:
          maxLargeRequestsPerDay ?? this.maxLargeRequestsPerDay,
      maxEstimatedInputTokensPerDay:
          maxEstimatedInputTokensPerDay ?? this.maxEstimatedInputTokensPerDay,
      minDelayBetweenRequestsSeconds:
          minDelayBetweenRequestsSeconds ?? this.minDelayBetweenRequestsSeconds,
      maxMessagesInContext: maxMessagesInContext ?? this.maxMessagesInContext,
    );
  }

  @override
  List<Object?> get props => [
    maxRequestsPerDay,
    maxLargeRequestsPerDay,
    maxEstimatedInputTokensPerDay,
    minDelayBetweenRequestsSeconds,
    maxMessagesInContext,
  ];
}

class AiUsageStats extends Equatable {
  final DateTime date;
  final int requestsToday;
  final int largeRequestsToday;
  final int estimatedInputTokensToday;
  final int estimatedOutputTokensToday;
  final DateTime? lastRequestAt;

  const AiUsageStats({
    required this.date,
    required this.requestsToday,
    required this.largeRequestsToday,
    required this.estimatedInputTokensToday,
    required this.estimatedOutputTokensToday,
    required this.lastRequestAt,
  });

  const AiUsageStats.empty({
    required this.date,
  }) : requestsToday = 0,
       largeRequestsToday = 0,
       estimatedInputTokensToday = 0,
       estimatedOutputTokensToday = 0,
       lastRequestAt = null;

  AiUsageStats copyWith({
    DateTime? date,
    int? requestsToday,
    int? largeRequestsToday,
    int? estimatedInputTokensToday,
    int? estimatedOutputTokensToday,
    DateTime? lastRequestAt,
    bool clearLastRequestAt = false,
  }) {
    return AiUsageStats(
      date: date ?? this.date,
      requestsToday: requestsToday ?? this.requestsToday,
      largeRequestsToday: largeRequestsToday ?? this.largeRequestsToday,
      estimatedInputTokensToday:
          estimatedInputTokensToday ?? this.estimatedInputTokensToday,
      estimatedOutputTokensToday:
          estimatedOutputTokensToday ?? this.estimatedOutputTokensToday,
      lastRequestAt: clearLastRequestAt
          ? null
          : lastRequestAt ?? this.lastRequestAt,
    );
  }

  @override
  List<Object?> get props => [
    date,
    requestsToday,
    largeRequestsToday,
    estimatedInputTokensToday,
    estimatedOutputTokensToday,
    lastRequestAt,
  ];
}

class AiUsageCheckResult extends Equatable {
  final bool allowed;
  final String? message;
  final AiUsageStats stats;

  const AiUsageCheckResult({
    required this.allowed,
    required this.message,
    required this.stats,
  });

  @override
  List<Object?> get props => [allowed, message, stats];
}
