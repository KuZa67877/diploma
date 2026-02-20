import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/reports_cubit.dart';
import '../models/reports_ui_models.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReportsCubit>()..load(),
      child: BlocListener<ReportsCubit, ReportsState>(
        listenWhen: (_, current) =>
            current.maybeWhen(
              exportReady: (_, __, ___) => true,
              exportFailed: (_, __) => true,
              orElse: () => false,
            ),
        listener: (context, state) {
          final localizations = AppLocalizations.of(context);
          state.whenOrNull(
            exportReady: (_, itemsCount, sourcesCount) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizations
                        .get('exportSuccess')
                        .replaceFirst('{items}', '$itemsCount')
                        .replaceFirst('{sources}', '$sourcesCount'),
                  ),
                ),
              );
            },
            exportFailed: (_, message) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            },
          );
        },
        child: BlocBuilder<ReportsCubit, ReportsState>(
          builder: (context, state) {
            final localizations = AppLocalizations.of(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final viewData = state.whenOrNull(
              loaded: (data) => data,
              exportReady: (data, __, ___) => data,
              exportFailed: (data, _) => data,
            );
            final errorMessage = state.whenOrNull(error: (message) => message);

            if (errorMessage != null) {
              return Scaffold(
                body: GradientBackground(
                  child: SafeArea(
                    child: _ErrorState(
                      message: errorMessage,
                      onRetry: () => context.read<ReportsCubit>().load(),
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
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.all(
                                AppConstants.spacingLg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.get('reports'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.darkForeground
                                          : AppColors.lightForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    localizations.get('exportAndShare'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? AppColors.darkMutedForeground
                                          : AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Filters
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingLg,
                              ),
                              child: Row(
                                children: viewData.filters.map((filter) {
                                  final isSelected =
                                      viewData.selectedFilterId == filter.id;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(localizations.get(filter.labelKey)),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        context
                                            .read<ReportsCubit>()
                                            .selectFilter(filter.id);
                                      },
                                      backgroundColor: isDark
                                          ? AppColors.darkMuted
                                          : AppColors.muted,
                                      selectedColor: isDark
                                          ? AppColors.darkPrimary
                                          : AppColors.primary,
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                ? AppColors.darkMutedForeground
                                                : AppColors.mutedForeground),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            const SizedBox(height: AppConstants.spacingLg),

                            // Export Options
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingLg,
                              ),
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppConstants.spacingMd,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localizations.get('quickExport'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.darkForeground
                                              : AppColors.lightForeground,
                                        ),
                                      ),
                                      const SizedBox(height: AppConstants.spacingMd),
                                      Row(
                                        children: viewData.exportOptions.map((option) {
                                          final label = option.useLocalization
                                              ? localizations.get(option.labelKey)
                                              : option.labelKey;
                                          return Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: _buildExportButton(
                                                context,
                                                option.id,
                                                label,
                                                option.icon,
                                                option.color,
                                                isDark,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: AppConstants.spacingLg),

                            // Reports List
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingLg,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    localizations.get('recentReports'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkForeground
                                          : AppColors.lightForeground,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.filter,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          localizations.get('filter'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppConstants.spacingMd),

                            ...viewData.reports.asMap().entries.map((entry) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  left: AppConstants.spacingLg,
                                  right: AppConstants.spacingLg,
                                  bottom: entry.key < viewData.reports.length - 1
                                      ? AppConstants.spacingMd
                                      : 0,
                                ),
                                child: _buildAnimatedCard(
                                  delay: 200 + (entry.key * 50),
                                  child: _buildReportCard(
                                    entry.value,
                                    localizations,
                                    isDark,
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: AppConstants.spacingLg),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildExportButton(
    BuildContext context,
    String optionId,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => context.read<ReportsCubit>().exportOption(optionId),
      borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMuted : AppColors.muted,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkForeground
                    : AppColors.lightForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    ReportItemUiModel report,
    AppLocalizations localizations,
    bool isDark,
  ) {
    Color bgColor;
    Color iconColor;

    switch (report.type) {
      case 'diagnostics':
        bgColor = AppColors.accentLight;
        iconColor = AppColors.accent;
        break;
      case 'trends':
        bgColor = AppColors.aiPurpleLight;
        iconColor = AppColors.aiPurple;
        break;
      default:
        bgColor = AppColors.primaryLight;
        iconColor = AppColors.primary;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
                  child: Icon(
                    LucideIcons.fileText,
                    size: 24,
                    color: iconColor,
                  ),
                ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.get(report.titleKey),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkForeground
                          : AppColors.lightForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.calendar,
                        size: 12,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (report.status == 'processing')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  localizations.get('processing'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              )
            else
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.eye,
                      size: 16,
                    ),
                    onPressed: () {},
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.darkMuted : AppColors.muted,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.download,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    onPressed: () {},
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingLg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              size: 32,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
