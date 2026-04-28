import 'package:flutter/material.dart';
import '../widgets/mini_chart.dart';

enum DashboardScoreState { noAccess, calculating, risk, attention, stable }

enum DashboardDataStatusState { upToDate, insufficient, syncRequired }

enum DashboardVisualState { good, attention, warning, insufficient }

class DashboardLocalizedText {
  final String key;
  final Map<String, String> params;

  const DashboardLocalizedText(
    this.key, {
    this.params = const <String, String>{},
  });
}

class DashboardMetricUiModel {
  final String id;
  final IconData icon;
  final String labelKey;
  final String value;
  final String unit;
  final ChartTrend trend;
  final List<double> data;

  const DashboardMetricUiModel({
    required this.id,
    required this.icon,
    required this.labelKey,
    required this.value,
    required this.unit,
    required this.trend,
    required this.data,
  });
}

class DashboardInsightUiModel {
  final String titleKey;
  final String descKey;

  const DashboardInsightUiModel({
    required this.titleKey,
    required this.descKey,
  });
}

class DashboardModelCardUiModel {
  final String id;
  final String titleKey;
  final DashboardVisualState state;
  final DashboardLocalizedText badge;
  final DashboardLocalizedText summary;
  final DashboardLocalizedText explanation;
  final DashboardLocalizedText recommendation;
  final double? progress;

  const DashboardModelCardUiModel({
    required this.id,
    required this.titleKey,
    required this.state,
    required this.badge,
    required this.summary,
    required this.explanation,
    required this.recommendation,
    required this.progress,
  });
}

class DashboardAiRecommendationUiModel {
  final DashboardVisualState importance;
  final DashboardLocalizedText text;
  final DashboardLocalizedText reason;

  const DashboardAiRecommendationUiModel({
    required this.importance,
    required this.text,
    required this.reason,
  });
}

class DashboardKeyMetricUiModel {
  final String id;
  final String labelKey;
  final String value;
  final String unit;
  final bool hasData;

  const DashboardKeyMetricUiModel({
    required this.id,
    required this.labelKey,
    required this.value,
    required this.unit,
    required this.hasData,
  });
}

class DashboardViewData {
  final String greetingKey;
  final String userName;
  final String dateLabel;
  final DashboardDataStatusState dataStatus;
  final String dataStatusLabel;
  final int healthScore;
  final bool healthScoreIsTemporary;
  final DashboardScoreState scoreState;
  final String scoreStateLabel;
  final DashboardVisualState overallState;
  final DashboardLocalizedText overallSummary;
  final DashboardLocalizedText overallExplanation;
  final bool showInsufficientDataBanner;
  final List<String> recommendations;
  final DashboardInsightUiModel insight;
  final List<DashboardModelCardUiModel> modelCards;
  final List<DashboardAiRecommendationUiModel> aiRecommendations;
  final List<DashboardKeyMetricUiModel> keyMetrics;
  final bool showNoDataState;
  final DashboardLocalizedText noDataMessage;
  final DashboardLocalizedText noDataHint;
  final List<DashboardMetricUiModel> metrics;

  const DashboardViewData({
    required this.greetingKey,
    required this.userName,
    required this.dateLabel,
    required this.dataStatus,
    required this.dataStatusLabel,
    required this.healthScore,
    required this.healthScoreIsTemporary,
    required this.scoreState,
    required this.scoreStateLabel,
    required this.overallState,
    required this.overallSummary,
    required this.overallExplanation,
    required this.showInsufficientDataBanner,
    required this.recommendations,
    required this.insight,
    required this.modelCards,
    required this.aiRecommendations,
    required this.keyMetrics,
    required this.showNoDataState,
    required this.noDataMessage,
    required this.noDataHint,
    required this.metrics,
  });
}
