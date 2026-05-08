import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../../health_data/data/services/health_mock_data_seeder.dart';

class HealthMockDataPage extends StatefulWidget {
  final VoidCallback onBack;

  const HealthMockDataPage({super.key, required this.onBack});

  @override
  State<HealthMockDataPage> createState() => _HealthMockDataPageState();
}

class _HealthMockDataPageState extends State<HealthMockDataPage> {
  final _seeder = getIt<HealthMockDataSeeder>();

  bool _busy = false;
  String? _status;
  List<String> _warnings = const [];

  Future<void> _seedMonth() async {
    setState(() {
      _busy = true;
      _status = 'Заполняю 30 дней тестовых данных в Health...';
      _warnings = const [];
    });

    try {
      final summary = await _seeder.seedLast30Days();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status =
            'Готово: ${summary.daysSeeded} дней, ${summary.samplesWritten} записей.';
        _warnings = summary.warnings;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = 'Ошибка: $error';
      });
    }
  }

  Future<void> _clearSeeded() async {
    setState(() {
      _busy = true;
      _status = 'Удаляю тестовые записи за последние 40 дней...';
      _warnings = const [];
    });

    try {
      await _seeder.clearLast40Days();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = 'Удаление завершено.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = 'Ошибка: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _HeaderIconButton(
                      icon: LucideIcons.chevronLeft,
                      onTap: widget.onBack,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Health mock seeder',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Запись реалистичных данных в приложение Здоровье для моделей за 30 дней',
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Что будет записано',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Сон, шаги, активная энергия, дистанция, пульс, resting HR, HRV и SpO2. Профиль включает спокойные дни, напряжённую фазу и восстановление, чтобы модели видели не только ровную синтетику.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'После записи откройте импорт/синхронизацию Health-данных в приложении, чтобы модели пересчитали свои выводы на новых измерениях.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _seedMonth,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(LucideIcons.database),
                        label: const Text('Заполнить 30 дней'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _clearSeeded,
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        label: const Text('Очистить мои тестовые записи'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                            color: AppColors.danger.withValues(alpha: 0.35),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_status != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLg,
                      ),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      _status!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: titleColor,
                      ),
                    ),
                  ),
                if (_warnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusLg,
                        ),
                        border: Border.all(color: borderColor),
                      ),
                      child: ListView.separated(
                        itemCount: _warnings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => Text(
                          '• ${_warnings[index]}',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
        ),
      ),
    );
  }
}
