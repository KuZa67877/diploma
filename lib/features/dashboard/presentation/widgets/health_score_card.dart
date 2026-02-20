import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import 'health_score_ring.dart';
import 'status_badge.dart';

class HealthScoreCard extends StatelessWidget {
  final int healthScore;
  final String status;

  const HealthScoreCard({
    super.key,
    required this.healthScore,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryGlow,
            ],
          ),
          borderRadius: BorderRadius.circular(
            AppConstants.radius3xl,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            HealthScoreRing(score: healthScore),
            const SizedBox(width: AppConstants.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.brain,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        localizations.get('aiHealthScore'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$healthScore',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(status: status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
