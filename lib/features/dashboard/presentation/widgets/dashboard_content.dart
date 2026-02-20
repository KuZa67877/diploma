import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../models/dashboard_ui_models.dart';
import 'ai_diagnostics_button.dart';
import 'ai_insight_card.dart';
import 'animated_reveal.dart';
import 'dashboard_header.dart';
import 'health_score_card.dart';
import 'metrics_section.dart';

class DashboardContent extends StatelessWidget {
  final DashboardViewData viewData;

  const DashboardContent({
    super.key,
    required this.viewData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              bottom: 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedReveal(
                  delay: 0,
                  child: DashboardHeader(viewData: viewData),
                ),
                AnimatedReveal(
                  delay: 100,
                  child: HealthScoreCard(
                    healthScore: viewData.healthScore,
                    status: viewData.status,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AnimatedReveal(
                  delay: 200,
                  child: AiInsightCard(insight: viewData.insight),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                MetricsSection(
                  metrics: viewData.metrics,
                  onViewAll: () => context.goNamed(AppRouter.analyticsRoute),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AnimatedReveal(
                  delay: 600,
                  child: AiDiagnosticsButton(onPressed: () {}),
                ),
                const SizedBox(height: AppConstants.spacingLg),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
