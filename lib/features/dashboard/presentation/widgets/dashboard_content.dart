import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';
import 'dashboard_header.dart';
import 'health_score_card.dart';

class DashboardContent extends StatelessWidget {
  final DashboardViewData viewData;
  final VoidCallback onOpenProfile;

  const DashboardContent({
    super.key,
    required this.viewData,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardHeader(viewData: viewData, onOpenProfile: onOpenProfile),
          HealthScoreCard(
            healthScore: viewData.healthScore,
            state: viewData.scoreState,
            stateLabel: viewData.scoreStateLabel,
          ),
          if (viewData.showInsufficientDataBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x33F59E0B)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0x55F59E0B)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizations.get('insufficientDataBanner'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFFE7C2)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              localizations.get('recommendedToday'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkForeground
                    : AppColors.lightForeground,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...viewData.recommendations.map(
            (item) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkCard
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBorder
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  localizations.get(item),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkForeground
                        : AppColors.lightForeground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
