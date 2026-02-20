import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/profile_ui_models.dart';
import 'profile_animated_card.dart';
import 'profile_service_card.dart';

class ProfileServicesSection extends StatelessWidget {
  final List<ProfileServiceUiModel> services;

  const ProfileServicesSection({
    super.key,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.get('connectedServices'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          ...services.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < services.length - 1 ? 8 : 0,
              ),
              child: ProfileAnimatedCard(
                delay: 200 + (entry.key * 50),
                child: ProfileServiceCard(service: entry.value),
              ),
            );
          }),
        ],
      ),
    );
  }
}
