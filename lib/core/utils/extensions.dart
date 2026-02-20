import 'package:flutter/material.dart';

extension BuildContextExtensions on BuildContext {
  /// Get the current theme
  ThemeData get theme => Theme.of(this);

  /// Get the current color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Get the current text theme
  TextTheme get textTheme => theme.textTheme;

  /// Get the screen size
  Size get screenSize => MediaQuery.of(this).size;

  /// Get the screen width
  double get screenWidth => screenSize.width;

  /// Get the screen height
  double get screenHeight => screenSize.height;

  /// Check if the device is in dark mode
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Show a snackbar
  void showSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Hide keyboard
  void hideKeyboard() {
    FocusScope.of(this).unfocus();
  }
}

extension StringExtensions on String {
  /// Capitalize the first letter
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Check if string is a valid email
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }
}

extension DateTimeExtensions on DateTime {
  /// Format date as 'MMM dd, yyyy'
  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[month - 1]} $day, $year';
  }

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}

extension DoubleExtensions on double {
  /// Format double to string with specified decimal places
  String toStringAsFixedNoZero(int fractionDigits) {
    final str = toStringAsFixed(fractionDigits);
    if (str.contains('.')) {
      return str.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }
}

