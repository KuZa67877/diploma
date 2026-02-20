import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/analytics_cubit.dart';
import '../widgets/analytics_content.dart';
import '../widgets/analytics_error_state.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AnalyticsCubit>()..load(),
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
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: AnalyticsContent(
                  viewData: viewData,
                  onFilterSelected: (filterId) => context
                      .read<AnalyticsCubit>()
                      .selectFilter(filterId),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
