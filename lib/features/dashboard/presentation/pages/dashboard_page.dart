import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/dashboard_cubit.dart';
import '../widgets/dashboard_content.dart';
import '../widgets/dashboard_error_state.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback onOpenProfile;

  const DashboardPage({super.key, required this.onOpenProfile});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..load(),
      child: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          final viewData = state.whenOrNull(loaded: (data) => data);
          final errorMessage = state.whenOrNull(error: (message) => message);

          if (errorMessage != null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: DashboardErrorState(
                    message: errorMessage,
                    onRetry: () => context.read<DashboardCubit>().load(),
                  ),
                ),
              ),
            );
          }

          if (viewData == null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(child: _DashboardLoadingShimmer()),
              ),
            );
          }

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: DashboardContent(
                  viewData: viewData,
                  onOpenProfile: widget.onOpenProfile,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardLoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 92),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: AppShimmerBox(height: 20)),
                SizedBox(width: 12),
                AppShimmerBox(width: 40, height: 40, shape: BoxShape.circle),
              ],
            ),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 240,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            SizedBox(height: 14),
            AppShimmerBox(height: 22, width: 200),
            SizedBox(height: 10),
            AppShimmerBox(
              height: 50,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            SizedBox(height: 10),
            AppShimmerBox(
              height: 50,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            SizedBox(height: 10),
            AppShimmerBox(
              height: 50,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ],
        ),
      ),
    );
  }
}
