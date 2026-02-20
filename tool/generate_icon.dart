import 'package:flutter/material.dart';

/// Скрипт для генерации иконки приложения
/// Запуск: flutter run -d macos tool/generate_icon.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Создаем виджет иконки
  final iconWidget = Container(
    width: 1024,
    height: 1024,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(226), // ~22% от 1024
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1F7A71), // primary
          Color(0xFF2A9D8F), // primaryGlow
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1F7A71).withValues(alpha: 0.3),
          blurRadius: 40,
          spreadRadius: 4,
        ),
      ],
    ),
    child: const Center(
      child: Icon(
        Icons.psychology_outlined, // Используем Material Icons т.к. Lucide не поддерживается в скрипте
        size: 512,
        color: Colors.white,
      ),
    ),
  );

  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 20),
            const Text(
              'Иконка создана!\nСкопируйте из assets/images/app_icon.png',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  ));
}
