import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/health_metric_sample.dart';
import '../../domain/entities/health_metric_type.dart';
import '../bloc/health_import_preview_cubit.dart';

class HealthImportPreviewPage extends StatelessWidget {
  final VoidCallback onBack;

  const HealthImportPreviewPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<HealthImportPreviewCubit>()..load(),
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child:
                BlocBuilder<HealthImportPreviewCubit, HealthImportPreviewState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return const _HealthImportPreviewLoadingShimmer();
                    }

                    if (state.errorMessage != null) {
                      return _ErrorState(
                        message: state.errorMessage!,
                        onBack: onBack,
                        onRetry: () =>
                            context.read<HealthImportPreviewCubit>().load(),
                      );
                    }

                    return _LoadedState(
                      state: state,
                      onBack: onBack,
                      onReload: () =>
                          context.read<HealthImportPreviewCubit>().load(),
                    );
                  },
                ),
          ),
        ),
      ),
    );
  }
}

class _HealthImportPreviewLoadingShimmer extends StatelessWidget {
  const _HealthImportPreviewLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Row(
              children: [
                AppShimmerBox(width: 36, height: 36, shape: BoxShape.circle),
                SizedBox(width: 10),
                Expanded(child: AppShimmerBox(height: 18)),
                SizedBox(width: 10),
                AppShimmerBox(width: 56, height: 28),
              ],
            ),
            SizedBox(height: 12),
            AppShimmerBox(
              height: 64,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            SizedBox(height: 12),
            Expanded(
              child: Column(
                children: [
                  AppShimmerBox(
                    height: 90,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  SizedBox(height: 10),
                  AppShimmerBox(
                    height: 90,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  SizedBox(height: 10),
                  AppShimmerBox(
                    height: 90,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadedState extends StatelessWidget {
  final HealthImportPreviewState state;
  final VoidCallback onBack;
  final VoidCallback onReload;

  const _LoadedState({
    required this.state,
    required this.onBack,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.get('importedHealthData'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      '${_formatDate(state.start)} - ${_formatDate(state.end)}',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onReload,
                child: Text(localizations.get('reload')),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: borderColor),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _StatChip(
                  label: localizations.get('records'),
                  value: state.samples.length.toString(),
                ),
                _StatChip(
                  label: localizations.get('sources'),
                  value: state.sourceCount.toString(),
                ),
                _StatChip(
                  label: localizations.get('metricTypes'),
                  value: state.metricTypeCount.toString(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: state.samples.isEmpty
              ? Center(
                  child: Text(
                    localizations.get('noSamplesFound'),
                    style: TextStyle(color: subtitleColor),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemBuilder: (context, index) {
                    final sample = state.samples[index];
                    final sourceName =
                        state.sourceNames[sample.sourceId] ?? sample.sourceId;

                    return _SampleTile(sample: sample, sourceName: sourceName);
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: state.samples.length,
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _SampleTile extends StatelessWidget {
  final HealthMetricSample sample;
  final String sourceName;

  const _SampleTile({required this.sample, required this.sourceName});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localizedMetricName(localizations, sample.type),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sourceName,
                  style: TextStyle(fontSize: 11, color: subtitleColor),
                ),
                Text(
                  _formatDateTime(sample.timestamp),
                  style: TextStyle(fontSize: 11, color: subtitleColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatValue(sample),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _localizedMetricName(
    AppLocalizations localizations,
    HealthMetricType type,
  ) {
    final key = type.key;
    final localized = localizations.get(key);
    return localized == key ? type.displayName : localized;
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  String _formatValue(HealthMetricSample sample) {
    final hasFraction = sample.value % 1 != 0;
    final formatted = hasFraction
        ? sample.value
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
        : sample.value.toInt().toString();

    return sample.unit.isEmpty
        ? formatted
        : '$formatted ${sample.unit.toLowerCase()}';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkMuted : AppColors.primaryLight;
    final fg = isDark ? AppColors.darkForeground : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              child: Text(localizations.get('retry')),
            ),
            TextButton(
              onPressed: onBack,
              child: Text(localizations.get('back')),
            ),
          ],
        ),
      ),
    );
  }
}
