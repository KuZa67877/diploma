import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _baseStyle => GoogleFonts.inter();

  // Display Styles
  static TextStyle displayLarge(Color color) => _baseStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: color,
      );

  static TextStyle displayMedium(Color color) => _baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: color,
      );

  static TextStyle displaySmall(Color color) => _baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: color,
      );

  // Heading Styles
  static TextStyle headingLarge(Color color) => _baseStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: color,
      );

  static TextStyle headingMedium(Color color) => _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  static TextStyle headingSmall(Color color) => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color,
      );

  // Body Styles
  static TextStyle bodyLarge(Color color) => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: color,
      );

  static TextStyle bodySmall(Color color) => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: color,
      );

  // Label Styles
  static TextStyle labelLarge(Color color) => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color,
      );

  static TextStyle labelMedium(Color color) => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color,
      );

  static TextStyle labelSmall(Color color) => _baseStyle.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color,
      );

  // Button Styles
  static TextStyle button(Color color) => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  static TextStyle buttonLarge(Color color) => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  // Caption Style
  static TextStyle caption(Color color) => _baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        height: 1.4,
        color: color,
      );
}

