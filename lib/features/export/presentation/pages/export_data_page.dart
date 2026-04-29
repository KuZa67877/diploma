import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../data/services/export_file_service.dart';
import '../../data/services/native_share_service.dart';
import '../../domain/entities/ai_prompt_template.dart';
import '../../domain/entities/export_data_range.dart';
import '../../domain/entities/export_data_type.dart';
import '../../domain/entities/export_format.dart';
import '../bloc/export_data_cubit.dart';

class ExportDataPage extends StatelessWidget {
  final VoidCallback onBack;

  const ExportDataPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return _ExportDataScope(onBack: onBack);
  }
}

class _ExportDataScope extends StatefulWidget {
  final VoidCallback onBack;

  const _ExportDataScope({required this.onBack});

  @override
  State<_ExportDataScope> createState() => _ExportDataScopeState();
}

class _ExportDataScopeState extends State<_ExportDataScope> {
  late final ExportDataCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<ExportDataCubit>();
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
      child: _ExportDataView(onBack: widget.onBack),
    );
  }
}

class _ExportDataView extends StatefulWidget {
  final VoidCallback onBack;

  const _ExportDataView({required this.onBack});

  @override
  State<_ExportDataView> createState() => _ExportDataViewState();
}

class _ExportDataViewState extends State<_ExportDataView> {
  final TextEditingController _promptController = TextEditingController();
  final ExportFileService _exportFileService = getIt<ExportFileService>();
  final NativeShareService _nativeShareService = getIt<NativeShareService>();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<ExportDataCubit, ExportDataState>(
      listenWhen: (previous, current) =>
          previous.customPrompt != current.customPrompt ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (_promptController.text != state.customPrompt) {
          _promptController.value = TextEditingValue(
            text: state.customPrompt,
            selection: TextSelection.collapsed(
              offset: state.customPrompt.length,
            ),
          );
        }
        final error = state.errorMessage;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
      child: BlocBuilder<ExportDataCubit, ExportDataState>(
        builder: (context, state) {
          final cubit = context.read<ExportDataCubit>();

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(LucideIcons.arrowLeft),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.get('exportDataTitle'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkForeground
                                        : AppColors.lightForeground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.get('exportDataSubtitle'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkMutedForeground
                                        : AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoBanner(
                        text: l10n.get('exportSensitiveWarning'),
                        color: AppColors.warningLight,
                        borderColor: AppColors.warning,
                        icon: LucideIcons.shieldAlert,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l10n.get('exportPeriod'),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _choiceChip(
                              context,
                              label: l10n.get('exportToday'),
                              selected:
                                  state.range.preset == ExportRangePreset.today,
                              onSelected: () =>
                                  cubit.selectPreset(ExportRangePreset.today),
                            ),
                            _choiceChip(
                              context,
                              label: l10n.get('exportYesterday'),
                              selected:
                                  state.range.preset ==
                                  ExportRangePreset.yesterday,
                              onSelected: () => cubit.selectPreset(
                                ExportRangePreset.yesterday,
                              ),
                            ),
                            _choiceChip(
                              context,
                              label: l10n.get('exportLast7Days'),
                              selected:
                                  state.range.preset ==
                                  ExportRangePreset.last7Days,
                              onSelected: () => cubit.selectPreset(
                                ExportRangePreset.last7Days,
                              ),
                            ),
                            _choiceChip(
                              context,
                              label: l10n.get('exportLast30Days'),
                              selected:
                                  state.range.preset ==
                                  ExportRangePreset.last30Days,
                              onSelected: () => cubit.selectPreset(
                                ExportRangePreset.last30Days,
                              ),
                            ),
                            ActionChip(
                              label: Text(
                                state.range.isCustom
                                    ? _rangeLabel(state.range)
                                    : l10n.get('exportChooseRange'),
                              ),
                              onPressed: () =>
                                  _pickCustomRange(context, state.range),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l10n.get('exportWhat'),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ExportDataType.values
                              .map((type) {
                                return FilterChip(
                                  label: Text(l10n.get(type.labelKey)),
                                  selected: state.selectedTypes.contains(type),
                                  onSelected: (_) => cubit.toggleDataType(type),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l10n.get('exportFormatTitle'),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ExportFormat.values
                              .map((format) {
                                return _choiceChip(
                                  context,
                                  label: l10n.get(format.labelKey),
                                  selected: state.format == format,
                                  onSelected: () => cubit.selectFormat(format),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      if (state.format == ExportFormat.ai) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: l10n.get('exportPromptTitle'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AiPromptTemplate.values
                                    .map((template) {
                                      return _choiceChip(
                                        context,
                                        label: l10n.get(template.labelKey),
                                        selected:
                                            state.promptTemplate == template,
                                        onSelected: () => cubit
                                            .selectPromptTemplate(template),
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              if (state.promptTemplate ==
                                  AiPromptTemplate.custom) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _promptController,
                                  minLines: 3,
                                  maxLines: 5,
                                  onChanged: cubit.updateCustomPrompt,
                                  decoration: InputDecoration(
                                    hintText: l10n.get(
                                      'exportPromptCustomHint',
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusLg,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l10n.get('personalInfo'),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: state.includePersonalData,
                          onChanged: cubit.toggleIncludePersonalData,
                          title: Text(l10n.get('exportIncludePersonalData')),
                          subtitle: Text(
                            l10n.get('exportIncludePersonalDataHint'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StatusBanner(state: state),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l10n.get('exportPreviewTitle'),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 260),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBackground
                                : Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusLg,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border,
                            ),
                          ),
                          child: state.status == ExportDataStatus.loading
                              ? const Center(child: CircularProgressIndicator())
                              : SelectableText(
                                  state.previewText.isEmpty
                                      ? l10n.get('exportNoData')
                                      : state.previewText,
                                  style: TextStyle(
                                    height: 1.45,
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkForeground
                                        : AppColors.lightForeground,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l10n.get('exportActionsTitle'),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 560;
                            final buttons = [
                              _actionButton(
                                text: l10n.get('exportCopyCurrent'),
                                onPressed:
                                    state.status == ExportDataStatus.loading
                                    ? null
                                    : () => _copyText(
                                        context,
                                        cubit.buildExportText(),
                                      ),
                                fullWidth: true,
                              ),
                              _actionButton(
                                text: l10n.get('exportCopyAi'),
                                variant: ButtonVariant.ai,
                                onPressed:
                                    state.status == ExportDataStatus.loading
                                    ? null
                                    : () => _copyText(
                                        context,
                                        cubit.buildExportText(
                                          formatOverride: ExportFormat.ai,
                                        ),
                                      ),
                              ),
                              _actionButton(
                                text: l10n.get('exportCopyDoctor'),
                                variant: ButtonVariant.medical,
                                onPressed:
                                    state.status == ExportDataStatus.loading
                                    ? null
                                    : () => _copyText(
                                        context,
                                        cubit.buildExportText(
                                          formatOverride: ExportFormat.doctor,
                                        ),
                                      ),
                              ),
                              _actionButton(
                                text: l10n.get('exportSaveFile'),
                                variant: ButtonVariant.secondary,
                                onPressed:
                                    state.status == ExportDataStatus.loading
                                    ? null
                                    : () => _saveFile(
                                        context,
                                        state: state,
                                        cubit: cubit,
                                      ),
                              ),
                              _actionButton(
                                text: l10n.get('share'),
                                variant: ButtonVariant.ghost,
                                onPressed:
                                    state.status == ExportDataStatus.loading
                                    ? null
                                    : () => _shareExport(
                                        context,
                                        state: state,
                                        cubit: cubit,
                                      ),
                              ),
                            ];

                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buttons[0],
                                  const SizedBox(height: 12),
                                  buttons[1],
                                  const SizedBox(height: 12),
                                  buttons[2],
                                  const SizedBox(height: 12),
                                  buttons[3],
                                  const SizedBox(height: 12),
                                  buttons[4],
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                buttons[0],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: buttons[1]),
                                    const SizedBox(width: 12),
                                    Expanded(child: buttons[2]),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: buttons[3]),
                                    const SizedBox(width: 12),
                                    Expanded(child: buttons[4]),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    ExportDataRange current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await context.read<ExportDataCubit>().setCustomRange(
      picked.start,
      picked.end,
    );
  }

  Future<void> _copyText(BuildContext context, String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).get('exportCopied'))),
    );
  }

  Future<void> _saveFile(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) async {
    final text = cubit.buildExportText();
    if (text.trim().isEmpty) {
      return;
    }
    try {
      final file = await _exportFileService.saveExport(
        content: text,
        format: state.format,
        range: state.range,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).get('exportFileCreated').replaceFirst('{file}', file.fileName),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('exportShareFailed')),
        ),
      );
    }
  }

  Future<void> _shareExport(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) async {
    final text = cubit.buildExportText();
    final subject = AppLocalizations.of(context).get('exportDataTitle');
    if (text.trim().isEmpty) {
      return;
    }
    try {
      final file = await _exportFileService.saveExport(
        content: text,
        format: state.format,
        range: state.range,
      );
      await _nativeShareService.shareFile(
        path: file.path,
        mimeType: file.mimeType,
        subject: subject,
        text: state.format == ExportFormat.ai ? text : null,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('exportShareFailed')),
        ),
      );
    }
  }

  Widget _choiceChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _actionButton({
    required String text,
    required VoidCallback? onPressed,
    ButtonVariant variant = ButtonVariant.primary,
    bool fullWidth = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      variant: variant,
      size: ButtonSize.small,
      fullWidth: fullWidth,
    );
  }

  String _rangeLabel(ExportDataRange range) {
    final format = DateFormat('dd.MM.yy');
    return '${format.format(range.start)} — ${format.format(range.end)}';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkForeground
                    : AppColors.lightForeground,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final Color borderColor;
  final IconData icon;

  const _InfoBanner({
    required this.text,
    required this.color,
    required this.borderColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkForeground
                    : AppColors.lightForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final ExportDataState state;

  const _StatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (
      Color background,
      Color border,
      String text,
    ) = switch (state.status) {
      ExportDataStatus.loading => (
        AppColors.primaryLight,
        AppColors.primary,
        l10n.get('exportLoading'),
      ),
      ExportDataStatus.partial => (
        AppColors.warningLight,
        AppColors.warning,
        '${l10n.get('exportPartialData')}${state.missingSections.isEmpty ? '' : ': ${state.missingSections.join(', ')}'}',
      ),
      ExportDataStatus.empty => (
        AppColors.accentLight,
        AppColors.accent,
        l10n.get('exportNoDataHint'),
      ),
      ExportDataStatus.error => (
        AppColors.dangerLight,
        AppColors.danger,
        state.errorMessage ?? l10n.get('exportSoftError'),
      ),
      _ => (
        AppColors.successLight,
        AppColors.success,
        l10n
            .get('exportReadyState')
            .replaceFirst('{records}', '${state.recordCount}')
            .replaceFirst('{sources}', '${state.sourceCount}'),
      ),
    };

    return _InfoBanner(
      text: text,
      color: background,
      borderColor: border,
      icon: state.status == ExportDataStatus.error
          ? LucideIcons.alertTriangle
          : LucideIcons.info,
    );
  }
}
