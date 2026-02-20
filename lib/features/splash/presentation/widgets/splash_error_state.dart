import 'package:flutter/material.dart';

class SplashErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const SplashErrorState({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onRetry,
        child: const Text('Retry'),
      ),
    );
  }
}
