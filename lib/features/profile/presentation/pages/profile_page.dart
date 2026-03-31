import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/profile_cubit.dart';
import '../widgets/profile_content.dart';
import '../widgets/profile_error_state.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;

  const ProfilePage({
    super.key,
    required this.onLogout,
    required this.onBack,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProfileCubit>()..load(),
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final viewData = state.whenOrNull(loaded: (data) => data);
          final errorMessage = state.whenOrNull(error: (message) => message);

          if (errorMessage != null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: ProfileErrorState(
                    message: errorMessage,
                    onRetry: () => context.read<ProfileCubit>().load(),
                  ),
                ),
              ),
            );
          }

          if (viewData == null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(child: _ProfileLoadingShimmer()),
              ),
            );
          }

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: ProfileContent(
                  viewData: viewData,
                  onBack: onBack,
                  onLogout: onLogout,
                  onOpenSettings: onOpenSettings,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileLoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 92),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppShimmerBox(width: 34, height: 34, shape: BoxShape.circle),
                SizedBox(width: 10),
                Expanded(child: AppShimmerBox(height: 18)),
                SizedBox(width: 10),
                AppShimmerBox(width: 34, height: 34, shape: BoxShape.circle),
              ],
            ),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 210,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: AppShimmerBox(height: 76)),
                SizedBox(width: 10),
                Expanded(child: AppShimmerBox(height: 76)),
                SizedBox(width: 10),
                Expanded(child: AppShimmerBox(height: 76)),
              ],
            ),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 130,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 110,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            SizedBox(height: 20),
            AppShimmerBox(
              height: 48,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}
