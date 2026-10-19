import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    required this.validator,
    super.key,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final String? Function(String?) validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: enabled,
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: MediaQuery.textScalerOf(context).scale(16) > 24 ? null : hint,
        helperText: MediaQuery.textScalerOf(context).scale(16) > 24
            ? hint
            : null,
        prefixIcon:
            prefixIcon == null ||
                MediaQuery.textScalerOf(context).scale(16) > 24
            ? null
            : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
