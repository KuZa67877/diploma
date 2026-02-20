import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/profile_ui_models.dart';
import 'profile_header.dart';
import 'profile_card.dart';
import 'profile_services_section.dart';
import 'profile_settings_section.dart';
import 'profile_security_section.dart';
import 'profile_logout_button.dart';

class ProfileContent extends StatelessWidget {
  final ProfileViewData viewData;
  final VoidCallback onLogout;

  const ProfileContent({
    super.key,
    required this.viewData,
    required this.onLogout,
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
                const ProfileHeader(),
                ProfileCard(viewData: viewData),
                const SizedBox(height: AppConstants.spacingLg),
                ProfileServicesSection(services: viewData.services),
                const SizedBox(height: AppConstants.spacingLg),
                const ProfileSettingsSection(),
                const SizedBox(height: AppConstants.spacingLg),
                const ProfileSecuritySection(),
                const SizedBox(height: AppConstants.spacingLg),
                ProfileLogoutButton(onLogout: onLogout),
                const SizedBox(height: AppConstants.spacingLg),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
