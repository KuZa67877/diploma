import 'package:flutter/material.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../bloc/health_sources_cubit.dart';
import 'health_sources_error_state.dart';
import 'health_sources_loaded_content.dart';

/// Контент экрана управления источниками данных.
class HealthSourcesContent extends StatelessWidget {
  /// Текущее состояние.
  final HealthSourcesState state;

  /// Коллбек возврата назад.
  final VoidCallback onBack;

  /// Коллбек повторной загрузки.
  final VoidCallback onRetry;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final bool showSkipAction;
  final bool showContinueAction;

  /// Коллбек переключения источника.
  final ValueChanged<String> onToggle;

  /// Создает контент экрана.
  const HealthSourcesContent({
    super.key,
    required this.state,
    required this.onBack,
    required this.onRetry,
    required this.onComplete,
    required this.onSkip,
    required this.showSkipAction,
    required this.showContinueAction,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return state.when(
      initial: _HealthSourcesLoadingShimmer.new,
      loading: _HealthSourcesLoadingShimmer.new,
      error: (message) =>
          HealthSourcesErrorState(message: message, onRetry: onRetry),
      loaded: (sources, updatingSourceId) => HealthSourcesLoadedContent(
        sources: sources,
        updatingSourceId: updatingSourceId,
        onBack: onBack,
        onComplete: onComplete,
        onSkip: onSkip,
        showSkipAction: showSkipAction,
        showContinueAction: showContinueAction,
        onToggle: onToggle,
      ),
    );
  }
}

class _HealthSourcesLoadingShimmer extends StatelessWidget {
  const _HealthSourcesLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Row(
              children: [
                AppShimmerBox(width: 36, height: 36, shape: BoxShape.circle),
                SizedBox(width: 12),
                Expanded(child: AppShimmerBox(height: 18)),
              ],
            ),
            SizedBox(height: 16),
            AppShimmerBox(height: 20, width: 180),
            SizedBox(height: 8),
            AppShimmerBox(height: 14),
            SizedBox(height: 14),
            AppShimmerBox(
              height: 92,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            SizedBox(height: 12),
            AppShimmerBox(
              height: 92,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            SizedBox(height: 12),
            AppShimmerBox(
              height: 92,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            Spacer(),
            AppShimmerBox(
              height: 52,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}
