import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../domain/entities/wellbeing_entry.dart';
import '../../domain/entities/wellbeing_mood.dart';
import '../bloc/wellbeing_cubit.dart';

class WellbeingCheckInPage extends StatefulWidget {
  final DateTime initialDate;

  const WellbeingCheckInPage({super.key, required this.initialDate});

  @override
  State<WellbeingCheckInPage> createState() => _WellbeingCheckInPageState();
}

class _WellbeingCheckInPageState extends State<WellbeingCheckInPage> {
  static const List<String> _tagKeys = [
    'calm',
    'focused',
    'productive',
    'social',
    'anxious',
    'tired',
    'grateful',
    'overloaded',
    'restless',
  ];

  late DateTime _selectedDate;
  final TextEditingController _noteController = TextEditingController();
  WellbeingMood? _selectedMood;
  Set<String> _selectedTags = <String>{};
  bool _didInitialHydration = false;
  bool _hasExistingEntry = false;
  bool _isEditMode = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialHydration) {
      return;
    }
    final state = context.read<WellbeingCubit>().state;
    if (!state.isLoading || state.entriesByDate.isNotEmpty) {
      _applyEntry(state.entryForDate(_selectedDate));
      _didInitialHydration = true;
    }
  }

  void _applyEntry(WellbeingEntry? entry) {
    setState(() {
      _hasExistingEntry = entry != null;
      _isEditMode = entry == null;
      _selectedMood = entry?.mood;
      _selectedTags = entry?.tags.toSet() ?? <String>{};
      _noteController.text = entry?.note ?? '';
    });
  }

  void _toggleTag(String key) {
    final next = Set<String>.from(_selectedTags);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    setState(() {
      _selectedTags = next;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localeCode = AppLocalizations.of(context).language.code;
    DateTime? picked;
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS) {
      picked = await _pickDateCupertino(
        context: context,
        initialDate: _selectedDate,
        minDate: DateTime(2020, 1, 1),
        maxDate: today,
      );
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020, 1, 1),
        lastDate: today,
        locale: Locale(localeCode),
      );
    }
    if (picked == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final selected = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _selectedDate = selected;
    });
    _applyEntry(context.read<WellbeingCubit>().state.entryForDate(selected));
  }

  Future<DateTime?> _pickDateCupertino({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime minDate,
    required DateTime maxDate,
  }) async {
    DateTime tempDate = initialDate;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (sheetContext) {
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(AppLocalizations.of(context).get('cancel')),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(sheetContext).pop(tempDate),
                      child: Text(AppLocalizations.of(context).get('done')),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: minDate,
                  maximumDate: maxDate,
                  onDateTimeChanged: (value) {
                    tempDate = DateTime(value.year, value.month, value.day);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final localizations = AppLocalizations.of(context);
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.get('selectMoodToSave'))),
      );
      return;
    }

    final ok = await context.read<WellbeingCubit>().saveForDate(
      date: _selectedDate,
      mood: _selectedMood!,
      tags: _selectedTags,
      note: _noteController.text,
    );

    if (!mounted) {
      return;
    }

    if (ok) {
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.get('checkInSaveFailed'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.darkForeground : AppColors.lightForeground;
    final muted = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final today = DateTime.now();
    final isSelectedToday = DateUtils.isSameDay(today, _selectedDate);
    final appBarTitle = isSelectedToday
        ? localizations.get('todaysCheckIn')
        : localizations.get('checkInForDate');
    final dateLabel = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_selectedDate);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: BlocListener<WellbeingCubit, WellbeingState>(
            listenWhen: (previous, current) =>
                previous.entriesByDate != current.entriesByDate,
            listener: (context, state) {
              if (!_didInitialHydration) {
                _applyEntry(state.entryForDate(_selectedDate));
                _didInitialHydration = true;
              }
            },
            child: BlocBuilder<WellbeingCubit, WellbeingState>(
              builder: (context, state) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 18,
                                color: muted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  appBarTitle,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateLabel,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: _hasExistingEntry
                                ? IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      setState(() {
                                        _isEditMode = true;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                      color: _isEditMode
                                          ? AppColors.primary
                                          : muted,
                                    ),
                                    tooltip: localizations.get('editEntry'),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                        child: Column(
                          children: [
                            _SectionCard(
                              title: localizations.get('entryDate'),
                              subtitle: null,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      dateLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: fg,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _pickDate,
                                    icon: const Icon(
                                      Icons.event_rounded,
                                      size: 16,
                                    ),
                                    label: Text(localizations.get('pickDate')),
                                  ),
                                ],
                              ),
                            ),
                            if (_hasExistingEntry && !_isEditMode) ...[
                              const SizedBox(height: 10),
                              _SectionCard(
                                title: localizations.get('viewMode'),
                                subtitle: localizations.get('tapEditToUpdate'),
                                child: const SizedBox.shrink(),
                              ),
                            ],
                            const SizedBox(height: 10),
                            _SectionCard(
                              title: localizations.get(
                                'howAreYouFeelingQuestion',
                              ),
                              subtitle: localizations.get(
                                'moveFromVeryUnpleasantToVeryPleasant',
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                runSpacing: 12,
                                spacing: 8,
                                children: WellbeingMood.values
                                    .map((mood) {
                                      final tone = _moodTone(mood);
                                      return _MoodOption(
                                        icon: tone.icon,
                                        label: localizations.get(
                                          mood.localizationKey,
                                        ),
                                        fg: tone.foreground,
                                        bg: tone.background,
                                        selected: _selectedMood == mood,
                                        onTap: _isEditMode
                                            ? () {
                                                setState(() {
                                                  _selectedMood = mood;
                                                });
                                              }
                                            : null,
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _SectionCard(
                              title: localizations.get('tags'),
                              subtitle: null,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _tagKeys
                                    .map((key) {
                                      final selected = _selectedTags.contains(
                                        key,
                                      );
                                      return _TagChip(
                                        text: localizations.get(key),
                                        selected: selected,
                                        onTap: _isEditMode
                                            ? () => _toggleTag(key)
                                            : null,
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _SectionCard(
                              title: localizations.get('note'),
                              subtitle: null,
                              child: TextField(
                                controller: _noteController,
                                readOnly: !_isEditMode,
                                minLines: 3,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: localizations.get('writeNote'),
                                ),
                              ),
                            ),
                            if (state.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                state.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state.isSaving || !_isEditMode
                              ? null
                              : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: state.isSaving
                              ? const SizedBox(
                                  width: 110,
                                  height: 12,
                                  child: AppShimmer(
                                    baseColor: Color(0x66FFFFFF),
                                    highlightColor: Color(0xAAFFFFFF),
                                    child: AppShimmerBox(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(999),
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  _hasExistingEntry
                                      ? localizations.get('updateCheckIn')
                                      : localizations.get('saveCheckIn'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.darkForeground : AppColors.lightForeground;
    final muted = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(fontSize: 11, color: muted)),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MoodOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final bool selected;
  final VoidCallback? onTap;

  const _MoodOption({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: const Color(0xFF86EFAC), width: 2)
                    : null,
              ),
              child: Icon(icon, size: 18, color: fg),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  const _TagChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primaryLight : const Color(0xFFF1F5F9);
    final fg = selected ? AppColors.primary : const Color(0xFF334155);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _MoodTone {
  final IconData icon;
  final Color foreground;
  final Color background;

  const _MoodTone({
    required this.icon,
    required this.foreground,
    required this.background,
  });
}

_MoodTone _moodTone(WellbeingMood mood) {
  switch (mood) {
    case WellbeingMood.veryLow:
      return const _MoodTone(
        icon: Icons.sentiment_very_dissatisfied_rounded,
        foreground: Color(0xFF991B1B),
        background: Color(0xFFFEE2E2),
      );
    case WellbeingMood.low:
      return const _MoodTone(
        icon: Icons.sentiment_dissatisfied_rounded,
        foreground: Color(0xFF9A3412),
        background: Color(0xFFFFEDD5),
      );
    case WellbeingMood.neutral:
      return const _MoodTone(
        icon: Icons.sentiment_neutral_rounded,
        foreground: Color(0xFF92400E),
        background: Color(0xFFFEF3C7),
      );
    case WellbeingMood.good:
      return const _MoodTone(
        icon: Icons.sentiment_satisfied_rounded,
        foreground: Color(0xFF166534),
        background: Color(0xFFDCFCE7),
      );
    case WellbeingMood.great:
      return const _MoodTone(
        icon: Icons.sentiment_very_satisfied_rounded,
        foreground: Color(0xFF0F766E),
        background: Color(0xFFCCFBF1),
      );
  }
}
