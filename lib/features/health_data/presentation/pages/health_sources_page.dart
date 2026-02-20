import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../bloc/health_sources_cubit.dart';
import '../widgets/health_sources_content.dart';

/// Экран управления источниками данных здоровья.
class HealthSourcesPage extends StatelessWidget {
  /// Коллбек возврата назад.
  final VoidCallback onBack;

  /// Создает экран источников данных здоровья.
  const HealthSourcesPage({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<HealthSourcesCubit>()..load(),
      child: BlocBuilder<HealthSourcesCubit, HealthSourcesState>(
        builder: (context, state) {
          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: HealthSourcesContent(
                  state: state,
                  onBack: onBack,
                  onRetry: () => context.read<HealthSourcesCubit>().load(),
                  onToggle: (sourceId) =>
                      context.read<HealthSourcesCubit>().toggleConnection(sourceId),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
