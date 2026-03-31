import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../bloc/data_input_cubit.dart';

class DataInputPage extends StatefulWidget {
  final VoidCallback? onComplete;

  const DataInputPage({super.key, this.onComplete});

  @override
  State<DataInputPage> createState() => _DataInputPageState();
}

class _DataInputPageState extends State<DataInputPage> {
  final _firstNameController = TextEditingController(text: 'Alex');
  final _lastNameController = TextEditingController(text: 'Johnson');
  final _heightController = TextEditingController(text: '178');
  final _weightController = TextEditingController(text: '72');
  final _ageController = TextEditingController(text: '29');
  String _sex = 'male';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _handleSubmit(BuildContext blocContext) {
    blocContext.read<DataInputCubit>().submit(
      systolicText: '',
      diastolicText: '',
      glucoseText: '',
      weightText: _weightController.text,
      temperatureText: '',
      firstNameText: _firstNameController.text,
      lastNameText: _lastNameController.text,
      heightText: _heightController.text,
      ageText: _ageController.text,
      sex: _sex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DataInputCubit>()..load(),
      child: BlocListener<DataInputCubit, DataInputState>(
        listenWhen: (_, current) =>
            current.maybeWhen(success: (_) => true, orElse: () => false),
        listener: (context, state) {
          context.showSnackBar(
            AppLocalizations.of(context).get('dataSaved'),
            duration: const Duration(seconds: 2),
          );
          widget.onComplete?.call();
          context.read<DataInputCubit>().resetStatus();
        },
        child: BlocBuilder<DataInputCubit, DataInputState>(
          builder: (context, state) {
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

            final readyData = state.whenOrNull(
              ready: (data) => data,
              submitting: (data) => data,
              success: (data) => data,
            );
            if (readyData == null) {
              return Scaffold(
                body: GradientBackground(
                  child: SafeArea(child: _DataInputLoadingShimmer()),
                ),
              );
            }

            final isSubmitting = state.maybeWhen(
              submitting: (_) => true,
              orElse: () => false,
            );

            final localizations = AppLocalizations.of(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final titleColor = isDark
                ? AppColors.darkForeground
                : AppColors.lightForeground;
            final subtitleColor = isDark
                ? AppColors.darkMutedForeground
                : AppColors.mutedForeground;
            final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
            final borderColor = isDark
                ? AppColors.darkBorder
                : AppColors.border;

            return Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              localizations.get('step3of4'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localizations.get('basicHealthData'),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          localizations.get('basicHealthDataDesc'),
                          style: TextStyle(fontSize: 13, color: subtitleColor),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _DataCardInput(
                                      label: localizations.get('firstName'),
                                      controller: _firstNameController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DataCardInput(
                                      label: localizations.get('lastName'),
                                      controller: _lastNameController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DataCardInput(
                                      label: localizations.get('height'),
                                      controller: _heightController,
                                      suffix: 'cm',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DataCardInput(
                                      label: localizations.get('weight'),
                                      controller: _weightController,
                                      suffix: 'kg',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DataCardInput(
                                      label: localizations.get('age'),
                                      controller: _ageController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SexCard(
                                      selectedSex: _sex,
                                      onTap: () {
                                        setState(
                                          () => _sex = _sex == 'male'
                                              ? 'female'
                                              : 'male',
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            localizations.get('updateValuesLater'),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                        if (readyData.errors.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...readyData.errors.values.map(
                            (key) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                AppLocalizations.of(context).get(key),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        CustomButton(
                          text: localizations.get('continue'),
                          onPressed: isSubmitting
                              ? null
                              : () => _handleSubmit(context),
                          variant: ButtonVariant.primary,
                          fullWidth: true,
                          size: ButtonSize.large,
                          isLoading: isSubmitting,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DataInputLoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppShimmerBox(width: 72, height: 24),
            ),
            SizedBox(height: 12),
            AppShimmerBox(height: 30, width: 180),
            SizedBox(height: 8),
            AppShimmerBox(height: 14, width: 240),
            SizedBox(height: 16),
            AppShimmerBox(
              height: 290,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            SizedBox(height: 16),
            AppShimmerBox(
              height: 52,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataCardInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffix;
  final TextInputType? keyboardType;

  const _DataCardInput({
    required this.label,
    required this.controller,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkMuted : AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffix != null)
                Text(
                  suffix!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SexCard extends StatelessWidget {
  final String selectedSex;
  final VoidCallback onTap;

  const _SexCard({required this.selectedSex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMuted : AppColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.get('sex'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              selectedSex == 'female'
                  ? localizations.get('female')
                  : localizations.get('male'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
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

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: localizations.get('retry'),
              onPressed: onRetry,
              variant: ButtonVariant.primary,
              size: ButtonSize.medium,
            ),
          ],
        ),
      ),
    );
  }
}
