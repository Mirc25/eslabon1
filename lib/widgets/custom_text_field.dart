// lib/widgets/custom_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para TextInputType

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String labelText;
  final String? hintText; // âœ… AÃ‘ADIDO: hintText
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool readOnly; // âœ… AÃ‘ADIDO: readOnly
  final int? maxLines; // âœ… AÃ‘ADIDO: maxLines
  final Function(String)? onChanged; // âœ… AÃ‘ADIDO: onChanged
  final bool enabled; // âœ… AÃ‘ADIDO: enabled

  const CustomTextField({
    Key? key,
    this.controller,
    required this.labelText,
    this.hintText, // âœ… AÃ‘ADIDO: hintText en constructor
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.readOnly = false, // âœ… AÃ‘ADIDO: readOnly en constructor con valor por defecto
    this.maxLines = 1, // âœ… AÃ‘ADIDO: maxLines en constructor con valor por defecto
    this.onChanged, // âœ… AÃ‘ADIDO: onChanged en constructor
    this.enabled = true, // âœ… AÃ‘ADIDO: enabled en constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly, // âœ… PASADO: readOnly al TextFormField
      maxLines: maxLines, // âœ… PASADO: maxLines al TextFormField
      onChanged: onChanged, // âœ… PASADO: onChanged al TextFormField
      enabled: enabled, // âœ… PASADO: enabled al TextFormField
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText, // âœ… PASADO: hintText al InputDecoration
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
