import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/analytics_ui_models.dart';
import 'activity_chart_card.dart';
import 'analytics_animated_card.dart';
import 'analytics_header.dart';
import 'analytics_insights_section.dart';
import 'analytics_time_filters.dart';
import 'heart_rate_chart_card.dart';

class AnalyticsContent extends StatelessWidget {
  final AnalyticsViewData viewData;
  final ValueChanged<String> onFilterSelected;

  const AnalyticsContent({
    super.key,
    required this.viewData,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AnalyticsHeader(),
                AnalyticsTimeFilters(
                  filters: viewData.filters,
                  selectedFilterId: viewData.selectedFilterId,
                  onSelected: onFilterSelected,
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AnalyticsAnimatedCard(
                  delay: 200,
                  child: HeartRateChartCard(points: viewData.heartRate),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AnalyticsAnimatedCard(
                  delay: 300,
                  child: ActivityChartCard(activityData: viewData.activity),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AnalyticsInsightsSection(insights: viewData.insights),
                const SizedBox(height: AppConstants.spacingLg),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
