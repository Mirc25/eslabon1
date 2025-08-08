// lib/widgets/custom_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para TextInputType

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String labelText;
  final String? hintText; // ✅ AÑADIDO: hintText
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool readOnly; // ✅ AÑADIDO: readOnly
  final int? maxLines; // ✅ AÑADIDO: maxLines
  final Function(String)? onChanged; // ✅ AÑADIDO: onChanged
  final bool enabled; // ✅ AÑADIDO: enabled

  const CustomTextField({
    Key? key,
    this.controller,
    required this.labelText,
    this.hintText, // ✅ AÑADIDO: hintText en constructor
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.readOnly = false, // ✅ AÑADIDO: readOnly en constructor con valor por defecto
    this.maxLines = 1, // ✅ AÑADIDO: maxLines en constructor con valor por defecto
    this.onChanged, // ✅ AÑADIDO: onChanged en constructor
    this.enabled = true, // ✅ AÑADIDO: enabled en constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly, // ✅ PASADO: readOnly al TextFormField
      maxLines: maxLines, // ✅ PASADO: maxLines al TextFormField
      onChanged: onChanged, // ✅ PASADO: onChanged al TextFormField
      enabled: enabled, // ✅ PASADO: enabled al TextFormField
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText, // ✅ PASADO: hintText al InputDecoration
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[800],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
