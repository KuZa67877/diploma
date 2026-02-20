import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/data_input_cubit.dart';
import '../models/data_input_ui_models.dart';

class DataInputPage extends StatefulWidget {
  const DataInputPage({super.key});

  @override
  State<DataInputPage> createState() => _DataInputPageState();
}

class _DataInputPageState extends State<DataInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _weightController = TextEditingController();
  final _temperatureController = TextEditingController();

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _glucoseController.dispose();
    _weightController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    context.read<DataInputCubit>().submit(
          systolicText: _systolicController.text,
          diastolicText: _diastolicController.text,
          glucoseText: _glucoseController.text,
          weightText: _weightController.text,
          temperatureText: _temperatureController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DataInputCubit>()..load(),
      child: BlocListener<DataInputCubit, DataInputState>(
        listenWhen: (previous, current) =>
            current.maybeWhen(success: (_) => true, orElse: () => false),
        listener: (context, state) {
          context.showSnackBar(
            AppLocalizations.of(context).get('dataSaved'),
            duration: const Duration(seconds: 2),
          );
          _systolicController.clear();
          _diastolicController.clear();
          _glucoseController.clear();
          _weightController.clear();
          _temperatureController.clear();
          context.read<DataInputCubit>().resetStatus();
        },
        child: BlocBuilder<DataInputCubit, DataInputState>(
          builder: (context, state) {
            final localizations = AppLocalizations.of(context);
            final isDark = context.isDarkMode;
            final isSubmitting =
                state.maybeWhen(submitting: (_) => true, orElse: () => false);

            final viewData = state.whenOrNull(
              ready: (data) => data,
              submitting: (data) => data,
              success: (data) => data,
            );

            final errorMessage = state.whenOrNull(error: (message) => message);
            if (errorMessage != null) {
              return Scaffold(
                body: GradientBackground(
                  child: SafeArea(
                    child: _ErrorState(
                      message: errorMessage,
                      onRetry: () => context.read<DataInputCubit>().load(),
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
                                      localizations.get('manualInput'),
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
                                      localizations.get('recordMeasurements'),
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

                              Form(
                                key: _formKey,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.spacingLg,
                                  ),
                                  child: Column(
                                    children: [
                                      // Blood Pressure Card
                                      _buildAnimatedCard(
                                        delay: 100,
                                        child: _buildBloodPressureCard(
                                          localizations,
                                          isDark,
                                          viewData.errors,
                                        ),
                                      ),
                                      const SizedBox(height: AppConstants.spacingMd),

                                      // Blood Glucose Card
                                      _buildAnimatedCard(
                                        delay: 150,
                                        child: _buildGlucoseCard(
                                          localizations,
                                          isDark,
                                          viewData.errors,
                                        ),
                                      ),
                                      const SizedBox(height: AppConstants.spacingMd),

                                      // Weight & Temperature Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildAnimatedCard(
                                              delay: 200,
                                              child: _buildWeightCard(
                                                localizations,
                                                isDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppConstants.spacingMd,
                                          ),
                                          Expanded(
                                            child: _buildAnimatedCard(
                                              delay: 250,
                                              child: _buildTemperatureCard(
                                                localizations,
                                                isDark,
                                                viewData.errors,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppConstants.spacingMd),

                                      // Date & Time Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildAnimatedCard(
                                              delay: 300,
                                              child: _buildDateCard(
                                                localizations,
                                                isDark,
                                                viewData.selectedDate,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppConstants.spacingMd,
                                          ),
                                          Expanded(
                                            child: _buildAnimatedCard(
                                              delay: 350,
                                              child: _buildTimeCard(
                                                localizations,
                                                isDark,
                                                viewData.selectedTime,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppConstants.spacingLg),

                                      // Symptoms
                                      _buildAnimatedCard(
                                        delay: 400,
                                        child: _buildSymptomsSection(
                                          localizations,
                                          isDark,
                                          viewData.symptoms,
                                          viewData.selectedSymptoms,
                                        ),
                                      ),
                                      const SizedBox(height: AppConstants.spacingLg),

                                      // Submit Button
                                      _buildAnimatedCard(
                                        delay: 450,
                                        child: CustomButton(
                                          text: localizations.get('saveData'),
                                          onPressed: isSubmitting ? null : _handleSubmit,
                                          variant: ButtonVariant.primary,
                                          size: ButtonSize.large,
                                          fullWidth: true,
                                          isLoading: isSubmitting,
                                        ),
                                      ),
                                      const SizedBox(height: AppConstants.spacingLg),
                                    ],
                                  ),
                                ),
                              ),
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

  Widget _buildBloodPressureCard(
    AppLocalizations localizations,
    bool isDark,
    Map<String, String> errors,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  ),
                  child: const Icon(
                    LucideIcons.activity,
                    size: 20,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.get('bloodPressure'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkForeground
                              : AppColors.lightForeground,
                        ),
                      ),
                      Text(
                        'mmHg',
                        style: TextStyle(
                          fontSize: 12,
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
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _systolicController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: localizations.get('systolic'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '/',
                    style: TextStyle(
                      fontSize: 24,
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _diastolicController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: localizations.get('diastolic'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    if (errors['bloodPressure'] != null) ...[
      const SizedBox(height: 8),
      Row(
        children: [
                  const Icon(
                    LucideIcons.alertCircle,
                    size: 12,
                    color: AppColors.danger,
                  ),
          const SizedBox(width: 4),
          Text(
            localizations.get(errors['bloodPressure']!),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.danger,
            ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlucoseCard(
    AppLocalizations localizations,
    bool isDark,
    Map<String, String> errors,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  ),
                  child: const Icon(
                    LucideIcons.droplet,
                    size: 20,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.get('bloodGlucose'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkForeground
                              : AppColors.lightForeground,
                        ),
                      ),
                      Text(
                        'mg/dL',
                        style: TextStyle(
                          fontSize: 12,
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
            const SizedBox(height: AppConstants.spacingMd),
            TextFormField(
              controller: _glucoseController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: localizations.get('enterValue'),
              ),
            ),
    if (errors['glucose'] != null) ...[
      const SizedBox(height: 8),
      Row(
        children: [
                  const Icon(
                    LucideIcons.alertCircle,
                    size: 12,
                    color: AppColors.danger,
                  ),
          const SizedBox(width: 4),
          Text(
            localizations.get(errors['glucose']!),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.danger,
            ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard(AppLocalizations localizations, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.scale, size: 20, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  localizations.get('weight'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: 'kg'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureCard(
    AppLocalizations localizations,
    bool isDark,
    Map<String, String> errors,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.thermometer, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizations.get('temperature'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            TextFormField(
              controller: _temperatureController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '°C'),
            ),
            if (errors['temperature'] != null) ...[
              const SizedBox(height: 8),
              Text(
                localizations.get(errors['temperature']!),
                style: const TextStyle(fontSize: 10, color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(
    AppLocalizations localizations,
    bool isDark,
    DateTime selectedDate,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (!mounted) return;
          if (date != null) {
            context.read<DataInputCubit>().setDate(date);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    localizations.get('date'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard(
    AppLocalizations localizations,
    bool isDark,
    TimeOfDay selectedTime,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: selectedTime,
          );
          if (!mounted) return;
          if (time != null) {
            context.read<DataInputCubit>().setTime(time);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.clock, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    localizations.get('time'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomsSection(
    AppLocalizations localizations,
    bool isDark,
    List<SymptomUiModel> symptoms,
    Set<String> selectedSymptoms,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.get('symptoms'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: symptoms.map((symptom) {
            final isSelected = selectedSymptoms.contains(symptom.id);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(LucideIcons.check, size: 12),
                    const SizedBox(width: 4),
                  ],
                  Text(localizations.get(symptom.labelKey)),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                context.read<DataInputCubit>().toggleSymptom(symptom.id);
              },
              backgroundColor: isDark ? AppColors.darkMuted : AppColors.muted,
              selectedColor: isDark ? AppColors.darkPrimary : AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground),
              ),
            );
          }).toList(),
        ),
      ],
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
            CustomButton(
              text: 'Retry',
              onPressed: onRetry,
              variant: ButtonVariant.secondary,
              size: ButtonSize.medium,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
