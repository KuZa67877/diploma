import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';
import 'health_score_ring.dart';

class HealthScoreCard extends StatelessWidget {
  final int healthScore;
  final DashboardScoreState state;
  final String stateLabel;

  const HealthScoreCard({
    super.key,
    required this.healthScore,
    required this.state,
    required this.stateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final gradient = _gradientForState(state);
    final badgeColor = _badgeColorForState(state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: 290,
        child: Stack(
          alignment: Alignment.center,
          children: [
            HealthScoreRing(score: healthScore, state: state, size: 280),
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    localizations.get('healthScore'),
                    style: TextStyle(fontSize: 13, color: Color(0xDDFFFFFF)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$healthScore',
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      localizations.get(stateLabel),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _gradientForState(DashboardScoreState scoreState) {
    switch (scoreState) {
      case DashboardScoreState.risk:
        return const [Color(0xFFC2410C), Color(0xFFF97316)];
      case DashboardScoreState.attention:
        return const [Color(0xFFB45309), Color(0xFFF59E0B)];
      case DashboardScoreState.noAccess:
      case DashboardScoreState.calculating:
      case DashboardScoreState.stable:
        return const [AppColors.primary, AppColors.primaryGlow];
    }
  }

  Color _badgeColorForState(DashboardScoreState scoreState) {
    switch (scoreState) {
      case DashboardScoreState.risk:
        return const Color(0x40EF4444);
      case DashboardScoreState.attention:
        return const Color(0x40F59E0B);
      case DashboardScoreState.noAccess:
      case DashboardScoreState.calculating:
      case DashboardScoreState.stable:
        return const Color(0x40FFFFFF);
    }
  }
}
