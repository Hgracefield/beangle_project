import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
        filled: !enabled || readOnly,
        fillColor: const Color(0xFFF2F4F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
