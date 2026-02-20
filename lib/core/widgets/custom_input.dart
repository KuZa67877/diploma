import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

class CustomInput extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final bool? isObscured;
  final VoidCallback? onToggleObscure;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final void Function(String)? onChanged;
  final bool enabled;

  const CustomInput({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.isObscured,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldObscure =
        widget.obscureText ? (widget.isObscured ?? true) : false;
    final canToggle = widget.obscureText && widget.onToggleObscure != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          obscureText: shouldObscure,
          keyboardType: widget.keyboardType,
          maxLines: shouldObscure ? 1 : widget.maxLines,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkMuted : AppColors.muted,
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: widget.prefixIcon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      shouldObscure ? Icons.visibility_off : Icons.visibility,
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                    ),
                    onPressed: canToggle ? widget.onToggleObscure : null,
                  )
                : widget.suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: const BorderSide(color: AppColors.danger, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.prefixIcon != null ? 12 : 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
