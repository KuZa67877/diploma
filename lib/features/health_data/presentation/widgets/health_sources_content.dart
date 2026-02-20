import 'package:flutter/material.dart';
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

  /// Коллбек переключения источника.
  final ValueChanged<String> onToggle;

  /// Создает контент экрана.
  const HealthSourcesContent({
    super.key,
    required this.state,
    required this.onBack,
    required this.onRetry,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return state.when(
      initial: () => const Center(child: CircularProgressIndicator()),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (message) => HealthSourcesErrorState(
        message: message,
        onRetry: onRetry,
      ),
      loaded: (sources, updatingSourceId) => HealthSourcesLoadedContent(
        sources: sources,
        updatingSourceId: updatingSourceId,
        onBack: onBack,
        onToggle: onToggle,
      ),
    );
  }
}
