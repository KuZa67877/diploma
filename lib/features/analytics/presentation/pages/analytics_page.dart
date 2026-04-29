import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/analytics_cubit.dart';
import '../widgets/analytics_content.dart';
import '../widgets/analytics_error_state.dart';

class AnalyticsPage extends StatefulWidget {
  final VoidCallback onOpenExport;

  const AnalyticsPage({super.key, required this.onOpenExport});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late final AnalyticsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<AnalyticsCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _cubit.load();
    });
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          final viewData = state.whenOrNull(loaded: (data) => data);
          final errorMessage = state.whenOrNull(error: (message) => message);

          if (errorMessage != null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: AnalyticsErrorState(
                    message: errorMessage,
                    onRetry: () => context.read<AnalyticsCubit>().load(),
                  ),
                ),
              ),
            );
          }

          if (viewData == null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(child: _AnalyticsLoadingShimmer()),
              ),
            );
          }

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: AnalyticsContent(
                  viewData: viewData,
                  onOpenExport: widget.onOpenExport,
                  onFilterSelected: (filterId) =>
                      context.read<AnalyticsCubit>().selectFilter(filterId),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsLoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Row(
              children: [
                Expanded(
                  child: AppShimmerBox(
                    height: 26,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                SizedBox(width: 12),
                AppShimmerBox(
                  width: 84,
                  height: 30,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ],
            ),
            SizedBox(height: 10),
            AppShimmerBox(height: 14),
            SizedBox(height: 16),
            Row(
              children: [
                AppShimmerBox(width: 42, height: 24),
                SizedBox(width: 8),
                AppShimmerBox(width: 42, height: 24),
                SizedBox(width: 8),
                AppShimmerBox(width: 42, height: 24),
              ],
            ),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 160,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 180,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            SizedBox(height: 10),
            AppShimmerBox(
              height: 44,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            SizedBox(height: 10),
            AppShimmerBox(
              height: 140,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}
