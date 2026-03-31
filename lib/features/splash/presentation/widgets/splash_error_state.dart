import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';

class SplashErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const SplashErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: TextButton(
        onPressed: onRetry,
        child: Text(localizations.get('retry')),
      ),
    );
  }
}
