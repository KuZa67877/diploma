import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../domain/entities/wellbeing_entry.dart';
import '../../domain/entities/wellbeing_mood.dart';
import '../bloc/wellbeing_cubit.dart';

class WellbeingPage extends StatefulWidget {
  final ValueChanged<DateTime> onOpenCheckIn;

  const WellbeingPage({super.key, required this.onOpenCheckIn});

  @override
  State<WellbeingPage> createState() => _WellbeingPageState();
}

class _WellbeingPageState extends State<WellbeingPage> {
  static const int _initialPage = 1200;
  late final DateTime _anchorMonth;
  late final PageController _pageController;

  static const List<String> _weekdayKeys = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorMonth = DateTime(now.year, now.month);
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    final offset = page - _initialPage;
    return DateTime(_anchorMonth.year, _anchorMonth.month + offset);
  }

  void _openPrevMonth() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _openNextMonth() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
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

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: BlocBuilder<WellbeingCubit, WellbeingState>(
            builder: (context, state) {
              final monthTitle = _formatMonthTitle(
                state.focusedMonth,
                Localizations.localeOf(context).toLanguageTag(),
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.get('wellbeingCalendar'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            localizations.get('trackDailyMoodAndMentalState'),
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          _MonthHeader(
                            title: monthTitle,
                            borderColor: border,
                            backgroundColor: isDark
                                ? AppColors.darkMuted
                                : AppColors.lightBackground,
                            iconColor: muted,
                            titleColor: fg,
                            onBack: _openPrevMonth,
                            onNext: _openNextMonth,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _weekdayKeys
                                .map(
                                  (key) => Expanded(
                                    child: Center(
                                      child: Text(
                                        localizations.get(key),
                                        style: const TextStyle(
                                          color: Color(0xFFB45309),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 306,
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (page) {
                                context.read<WellbeingCubit>().setFocusedMonth(
                                  _monthForPage(page),
                                );
                              },
                              itemBuilder: (context, index) {
                                if (state.isLoading &&
                                    state.entriesByDate.isEmpty) {
                                  return _CalendarGridShimmer(
                                    isDark: isDark,
                                    borderColor: border,
                                  );
                                }
                                final month = _monthForPage(index);
                                return _MonthGrid(
                                  month: month,
                                  entriesByDate: state.entriesByDate,
                                  textColor: const Color(0xFF92400E),
                                  mutedColor: muted,
                                  borderColor: border,
                                  onOpenDate: widget.onOpenCheckIn,
                                );
                              },
                            ),
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _LegendRow(
                            moods: const [
                              WellbeingMood.veryLow,
                              WellbeingMood.low,
                              WellbeingMood.neutral,
                              WellbeingMood.good,
                              WellbeingMood.great,
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.get('todaysCheckIn'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            localizations.get('howDidYourDayFeelOverall'),
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () =>
                                  widget.onOpenCheckIn(DateTime.now()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: Text(localizations.get('addTodaysEntry')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatMonthTitle(DateTime month, String localeTag) {
    final raw = DateFormat.yMMMM(localeTag).format(month);
    if (raw.isEmpty) {
      return raw;
    }
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _CalendarGridShimmer extends StatefulWidget {
  final bool isDark;
  final Color borderColor;

  const _CalendarGridShimmer({required this.isDark, required this.borderColor});

  @override
  State<_CalendarGridShimmer> createState() => _CalendarGridShimmerState();
}

class _CalendarGridShimmerState extends State<_CalendarGridShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final highlight = widget.isDark
        ? const Color(0xFF374151)
        : const Color(0xFFF3F4F6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shift = (_controller.value * 2) - 1;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.8 + shift, 0),
              end: Alignment(-0.8 + shift, 0),
              colors: [base, highlight, base],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: GridView.builder(
        itemCount: 42,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 6,
          mainAxisSpacing: 8,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final isGapCell = index < 2 || index > 38;
          if (isGapCell) {
            return const SizedBox.shrink();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.borderColor),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 12,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<String, WellbeingEntry> entriesByDate;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final ValueChanged<DateTime> onOpenDate;

  const _MonthGrid({
    required this.month,
    required this.entriesByDate,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.onOpenDate,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmptyCount = firstDay.weekday - DateTime.monday;
    final totalCells = ((leadingEmptyCount + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      itemCount: totalCells,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final day = index - leadingEmptyCount + 1;
        if (day <= 0 || day > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(month.year, month.month, day);
        final key = _dateKey(date);
        final entry = entriesByDate[key];
        final isToday = DateUtils.isSameDay(date, DateTime.now());

        return _DayCell(
          day: day,
          mood: entry?.mood,
          isToday: isToday,
          textColor: textColor,
          mutedColor: mutedColor,
          borderColor: borderColor,
          onTap: () => onOpenDate(date),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final WellbeingMood? mood;
  final bool isToday;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.mood,
    required this.isToday,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = mood == null ? null : _moodTone(mood!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tone?.background ?? Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isToday
                    ? AppColors.primary
                    : (tone == null ? borderColor : Colors.transparent),
                width: isToday ? 1.5 : 1,
              ),
            ),
            child: tone == null
                ? null
                : Icon(tone.icon, size: 12, color: tone.foreground),
          ),
          const SizedBox(height: 2),
          Text(
            '$day',
            style: TextStyle(
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w600,
              color: mood == null ? mutedColor : textColor,
            ),
          ),
        ],
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

class _MonthHeader extends StatelessWidget {
  final String title;
  final Color borderColor;
  final Color backgroundColor;
  final Color iconColor;
  final Color titleColor;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.title,
    required this.borderColor,
    required this.backgroundColor,
    required this.iconColor,
    required this.titleColor,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    Widget arrow(bool isLeft, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Icon(
            isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 16,
            color: iconColor,
          ),
        ),
      );
    }

    return Row(
      children: [
        arrow(true, onBack),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
        ),
        arrow(false, onNext),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final List<WellbeingMood> moods;

  const _LegendRow({required this.moods});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: moods
          .map((mood) {
            final tone = _moodTone(mood);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: tone.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tone.icon, size: 8, color: tone.foreground),
                ),
                const SizedBox(width: 4),
                Text(
                  localizations.get(mood.localizationKey),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tone.foreground,
                  ),
                ),
              ],
            );
          })
          .toList(growable: false),
    );
  }
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
