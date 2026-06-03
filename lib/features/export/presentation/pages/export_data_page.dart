import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
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
          final l10n = AppLocalizations.of(context);

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(
                        context,
                        state: state,
                        cubit: cubit,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildHeroCard(context, state: state, isDark: isDark),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildRangeCard(
                              context,
                              state: state,
                              cubit: cubit,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildOutputCard(
                              context,
                              state: state,
                              cubit: cubit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildIncludedDataCard(
                        context,
                        state: state,
                        cubit: cubit,
                      ),
                      if (state.format == ExportFormat.ai) ...[
                        const SizedBox(height: 10),
                        _buildPromptCard(
                          context,
                          state: state,
                          cubit: cubit,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildPrivacyCard(context, state: state, cubit: cubit),
                      if (state.status != ExportDataStatus.ready) ...[
                        const SizedBox(height: 10),
                        _StatusBanner(state: state),
                      ],
                      const SizedBox(height: 10),
                      _buildPreviewSection(
                        context,
                        state: state,
                        cubit: cubit,
                        isDark: isDark,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 10),
                      _buildActionBar(
                        context,
                        state: state,
                        cubit: cubit,
                        l10n: l10n,
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

  Widget _buildHeader(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
    required bool isDark,
  }) {
    return Row(
      children: [
        _StudioIconButton(
          icon: LucideIcons.arrowLeft,
          onTap: widget.onBack,
          isDark: isDark,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context).get('exportDataTitle'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkForeground
                      : AppColors.lightForeground,
                ),
              ),
              Text(
                'Studio view',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        _StudioIconButton(
          icon: LucideIcons.slidersHorizontal,
          onTap: state.status == ExportDataStatus.loading
              ? null
              : () => _showQuickActionsSheet(context, state: state, cubit: cubit),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required ExportDataState state,
    required bool isDark,
  }) {
    final l10n = AppLocalizations.of(context);
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDFF5EF), Color(0xFFF8FCFB)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radius2xl),
        border: Border.all(color: const Color(0xFFD7EDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StudioTonePill(
                label: _heroModeLabel(l10n, state.format),
                icon: LucideIcons.download,
                color: AppColors.primary,
                background: AppColors.secondaryLight,
              ),
              const Spacer(),
              _StudioTonePill(
                label: _statusPillLabel(state),
                color: _statusPillColor(state),
                background: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Health export package',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Build a clean export for AI, a doctor, or raw review in one tap.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StudioStatPill(label: _heroRangeLabel(l10n, state.range)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudioStatPill(label: _selectedTypeCountText(state)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudioStatPill(
                  label: state.includePersonalData ? 'Privacy shared' : 'Privacy hidden',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeCard(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) {
    final l10n = AppLocalizations.of(context);
    return _StudioCard(
      title: l10n.get('exportPeriod'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StudioSelectionTile(
                  label: l10n.get('exportLast7Days'),
                  selected: state.range.preset == ExportRangePreset.last7Days,
                  onTap: () => cubit.selectPreset(ExportRangePreset.last7Days),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StudioSelectionTile(
                  label: l10n.get('exportLast30Days'),
                  selected: state.range.preset == ExportRangePreset.last30Days,
                  onTap: () => cubit.selectPreset(ExportRangePreset.last30Days),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StudioSelectionTile(
                  label: l10n.get('exportToday'),
                  selected: state.range.preset == ExportRangePreset.today,
                  onTap: () => cubit.selectPreset(ExportRangePreset.today),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StudioSelectionTile(
                  label: state.range.isCustom
                      ? _rangeLabel(state.range)
                      : l10n.get('exportChooseRange'),
                  selected: state.range.isCustom,
                  onTap: () => _pickCustomRange(context, state.range),
                  denseLabel: state.range.isCustom,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutputCard(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) {
    final l10n = AppLocalizations.of(context);
    final rawFamily = {
      ExportFormat.markdown,
      ExportFormat.json,
      ExportFormat.csv,
    };
    return _StudioCard(
      title: l10n.get('exportFormatTitle'),
      child: Column(
        children: [
          _StudioModeRow(
            label: l10n.get('exportFormatAi'),
            trailing: state.format == ExportFormat.ai ? 'Selected' : null,
            selected: state.format == ExportFormat.ai,
            onTap: () => cubit.selectFormat(ExportFormat.ai),
          ),
          const SizedBox(height: 6),
          _StudioModeRow(
            label: l10n.get('exportFormatDoctor'),
            trailing: state.format == ExportFormat.doctor ? 'Selected' : 'PDF',
            selected: state.format == ExportFormat.doctor,
            onTap: () => cubit.selectFormat(ExportFormat.doctor),
          ),
          const SizedBox(height: 6),
          _StudioModeRow(
            label: 'Raw export',
            trailing: rawFamily.contains(state.format)
                ? l10n.get(state.format.labelKey)
                : 'CSV',
            selected: rawFamily.contains(state.format),
            onTap: () => cubit.selectFormat(ExportFormat.csv),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final format in const [
                ExportFormat.markdown,
                ExportFormat.json,
                ExportFormat.csv,
                ExportFormat.shortSummary,
                ExportFormat.detailedReport,
              ])
                _StudioMiniPill(
                  label: l10n.get(format.labelKey),
                  selected: state.format == format,
                  onTap: () => cubit.selectFormat(format),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedDataCard(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) {
    final l10n = AppLocalizations.of(context);
    final visibleTypes = _visibleTypes(state);
    return _StudioCard(
      title: l10n.get('exportWhat'),
      trailing: _StudioCountPill(label: _selectedTypeCountText(state)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleTypes
                .map(
                  (type) => _StudioMiniPill(
                    label: l10n.get(type.labelKey),
                    selected: state.selectedTypes.contains(ExportDataType.everything) ||
                        state.selectedTypes.contains(type),
                    onTap: () => cubit.toggleDataType(type),
                    activeBackground: AppColors.secondaryLight,
                  ),
                )
                .toList(growable: false),
          ),
          if (state.selectedTypes.contains(ExportDataType.everything)) ...[
            const SizedBox(height: 8),
            Text(
              l10n.get('exportSensitiveWarning'),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptCard(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) {
    final l10n = AppLocalizations.of(context);
    return _StudioCard(
      title: l10n.get('exportPromptTitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AiPromptTemplate.values
                .map(
                  (template) => _StudioMiniPill(
                    label: l10n.get(template.labelKey),
                    selected: state.promptTemplate == template,
                    onTap: () => cubit.selectPromptTemplate(template),
                  ),
                )
                .toList(growable: false),
          ),
          if (state.promptTemplate == AiPromptTemplate.custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _promptController,
              minLines: 3,
              maxLines: 4,
              onChanged: cubit.updateCustomPrompt,
              decoration: InputDecoration(
                hintText: l10n.get('exportPromptCustomHint'),
                filled: true,
                fillColor: AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyCard(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7EDE6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              LucideIcons.shield,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).get('exportIncludePersonalData'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.includePersonalData
                      ? 'Identifiers will be included in the export.'
                      : 'Identifiers stay hidden until enabled.',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: state.includePersonalData,
            onChanged: cubit.toggleIncludePersonalData,
            activeThumbColor: AppColors.primary,
            activeTrackColor: const Color(0xFFD8F1EA),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    final previewText = _previewSnippet(state, l10n);
    final tags = _previewTags(state, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.get('exportPreviewTitle'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkForeground
                    : AppColors.lightForeground,
              ),
            ),
            const Spacer(),
            _StudioTonePill(
              label: 'Live preview',
              color: AppColors.primary,
              background: AppColors.secondaryLight,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2429),
            borderRadius: BorderRadius.circular(AppConstants.radius2xl),
            border: Border.all(color: const Color(0xFF323A42)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _previewFileName(state),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  _StudioTonePill(
                    label: _heroModeLabel(l10n, state.format),
                    color: const Color(0xFF7DD3C7),
                    background: const Color(0xFF2B3239),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: state.status == ExportDataStatus.loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _previewHeading(state),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightForeground,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            previewText,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.35,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .map(
                                    (tag) => _StudioTagChip(
                                      label: tag,
                                      color: _tagColorFor(tag),
                                      background: _tagBackgroundFor(tag),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  state.includePersonalData
                                      ? 'Includes identifiers'
                                      : 'Share-ready and de-identified',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Text(
                                _wordCountText(state.previewText),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
    required AppLocalizations l10n,
  }) {
    final disabled = state.status == ExportDataStatus.loading ||
        cubit.buildExportText().trim().isEmpty;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _StudioActionButton(
            icon: LucideIcons.copy,
            label: 'Copy',
            onTap: disabled
                ? null
                : () => _copyText(context, cubit.buildExportText()),
          ),
          const SizedBox(width: 8),
          _StudioActionButton(
            icon: LucideIcons.share2,
            label: l10n.get('share'),
            onTap: disabled
                ? null
                : () => _shareExport(context, state: state, cubit: cubit),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StudioActionButton(
              icon: LucideIcons.download,
              label: l10n.get('exportSaveFile'),
              onTap: disabled
                  ? null
                  : () => _saveFile(context, state: state, cubit: cubit),
              primary: true,
              expand: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickActionsSheet(
    BuildContext context, {
    required ExportDataState state,
    required ExportDataCubit cubit,
  }) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.copy),
                title: Text(l10n.get('exportCopyCurrent')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copyText(context, cubit.buildExportText());
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.bot),
                title: Text(l10n.get('exportCopyAi')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copyText(
                    context,
                    cubit.buildExportText(formatOverride: ExportFormat.ai),
                  );
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.stethoscope),
                title: Text(l10n.get('exportCopyDoctor')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copyText(
                    context,
                    cubit.buildExportText(formatOverride: ExportFormat.doctor),
                  );
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2),
                title: Text(l10n.get('share')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _shareExport(context, state: state, cubit: cubit);
                },
              ),
            ],
          ),
        );
      },
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

  String _heroModeLabel(AppLocalizations l10n, ExportFormat format) {
    return switch (format) {
      ExportFormat.ai => 'AI export',
      ExportFormat.doctor => 'Doctor export',
      ExportFormat.markdown ||
      ExportFormat.json ||
      ExportFormat.csv => 'Raw export',
      ExportFormat.shortSummary => 'Short summary',
      ExportFormat.detailedReport => 'Detailed report',
    };
  }

  String _statusPillLabel(ExportDataState state) {
    return switch (state.status) {
      ExportDataStatus.loading => 'Preparing',
      ExportDataStatus.partial => 'Partial',
      ExportDataStatus.empty => 'No data',
      ExportDataStatus.error => 'Error',
      _ => 'Ready',
    };
  }

  Color _statusPillColor(ExportDataState state) {
    return switch (state.status) {
      ExportDataStatus.partial => AppColors.warning,
      ExportDataStatus.empty => AppColors.accent,
      ExportDataStatus.error => AppColors.danger,
      _ => AppColors.primary,
    };
  }

  String _heroRangeLabel(AppLocalizations l10n, ExportDataRange range) {
    return switch (range.preset) {
      ExportRangePreset.today => l10n.get('exportToday'),
      ExportRangePreset.yesterday => l10n.get('exportYesterday'),
      ExportRangePreset.last7Days => l10n.get('exportLast7Days'),
      ExportRangePreset.last30Days => l10n.get('exportLast30Days'),
      ExportRangePreset.custom => _rangeLabel(range),
    };
  }

  List<ExportDataType> _visibleTypes(ExportDataState state) {
    if (state.selectedTypes.contains(ExportDataType.everything)) {
      return const [
        ExportDataType.sleep,
        ExportDataType.pulse,
        ExportDataType.activity,
        ExportDataType.modelResults,
        ExportDataType.rawMetrics,
      ];
    }
    return ExportDataType.values
        .where((type) => type != ExportDataType.everything)
        .toList(growable: false);
  }

  String _selectedTypeCountText(ExportDataState state) {
    if (state.selectedTypes.contains(ExportDataType.everything)) {
      return 'All export';
    }
    return '${state.selectedTypes.length} selected';
  }

  String _previewFileName(ExportDataState state) {
    final suffix = switch (state.format) {
      ExportFormat.ai => 'md',
      ExportFormat.doctor => 'txt',
      ExportFormat.markdown => 'md',
      ExportFormat.json => 'json',
      ExportFormat.csv => 'csv',
      ExportFormat.shortSummary => 'txt',
      ExportFormat.detailedReport => 'txt',
    };
    final period = switch (state.range.preset) {
      ExportRangePreset.today => 'today',
      ExportRangePreset.yesterday => 'yesterday',
      ExportRangePreset.last7Days => '7d',
      ExportRangePreset.last30Days => '30d',
      ExportRangePreset.custom => 'custom',
    };
    return 'medi_ai_export_$period.$suffix';
  }

  String _previewHeading(ExportDataState state) {
    return switch (state.range.preset) {
      ExportRangePreset.today => 'Health export · today',
      ExportRangePreset.yesterday => 'Health export · yesterday',
      ExportRangePreset.last7Days => 'Health export · last 7 days',
      ExportRangePreset.last30Days => 'Health export · last 30 days',
      ExportRangePreset.custom => 'Health export · custom range',
    };
  }

  String _previewSnippet(ExportDataState state, AppLocalizations l10n) {
    if (state.status == ExportDataStatus.loading) {
      return l10n.get('exportLoading');
    }
    if (state.previewText.trim().isEmpty) {
      return l10n.get('exportNoDataHint');
    }
    return state.previewText
        .replaceAll('\r', '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ');
  }

  List<String> _previewTags(ExportDataState state, AppLocalizations l10n) {
    final types = state.selectedTypes.contains(ExportDataType.everything)
        ? const [
            ExportDataType.sleep,
            ExportDataType.pulse,
            ExportDataType.activity,
          ]
        : state.selectedTypes.take(3).toList(growable: false);
    return types.map((type) => l10n.get(type.labelKey)).toList(growable: false);
  }

  String _wordCountText(String text) {
    final count = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .length;
    return '$count words';
  }

  String _rangeLabel(ExportDataRange range) {
    final format = DateFormat('dd.MM.yy');
    return '${format.format(range.start)} — ${format.format(range.end)}';
  }

  Color _tagColorFor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('sleep') || normalized.contains('сон')) {
      return AppColors.primary;
    }
    if (normalized.contains('pulse') ||
        normalized.contains('heart') ||
        normalized.contains('пульс') ||
        normalized.contains('vitals')) {
      return const Color(0xFF5B6EE1);
    }
    return const Color(0xFF0F766E);
  }

  Color _tagBackgroundFor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('sleep') || normalized.contains('сон')) {
      return AppColors.secondaryLight;
    }
    if (normalized.contains('pulse') ||
        normalized.contains('heart') ||
        normalized.contains('пульс') ||
        normalized.contains('vitals')) {
      return const Color(0xFFEEF2FF);
    }
    return const Color(0xFFF4FBF8);
  }
}

class _StudioCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _StudioCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightForeground,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StudioIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  const _StudioIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? AppColors.mutedForeground
              : isDark
              ? AppColors.darkForeground
              : AppColors.lightForeground,
        ),
      ),
    );
  }
}

class _StudioTonePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color background;

  const _StudioTonePill({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioStatPill extends StatelessWidget {
  final String label;

  const _StudioStatPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6F0EC)),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.lightForeground,
          ),
        ),
      ),
    );
  }
}

class _StudioSelectionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool denseLabel;

  const _StudioSelectionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.denseLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondaryLight : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFC8E6DD) : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: denseLabel ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: denseLabel ? 9 : 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioModeRow extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  const _StudioModeRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondaryLight : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFC8E6DD) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.mutedForeground,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : const Color(0xFF94A3B8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudioMiniPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeBackground;

  const _StudioMiniPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeBackground = AppColors.lightBackground,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeBackground : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFC8E6DD) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _StudioCountPill extends StatelessWidget {
  final String label;

  const _StudioCountPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _StudioTagChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StudioTagChip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StudioActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool expand;

  const _StudioActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: onTap == null
                  ? AppColors.mutedForeground
                  : primary
                  ? Colors.white
                  : AppColors.mutedForeground,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: onTap == null
                    ? AppColors.mutedForeground
                    : primary
                    ? Colors.white
                    : AppColors.mutedForeground,
              ),
            ),
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
