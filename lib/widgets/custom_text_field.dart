// lib/widgets/custom_text_field.dart
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? hintText;
  final bool enabled; // Para controlar si el campo está activo

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.hintText,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // Padding estándar
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        enabled: enabled, // Aplica el estado de enabled
        style: const TextStyle(color: Colors.white), // Color del texto de entrada
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          labelStyle: const TextStyle(color: Colors.white70), // Color del label
          hintStyle: const TextStyle(color: Colors.white54), // Color del hint
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white54), // Borde por defecto
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white54), // Borde cuando está habilitado
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.amber), // Borde cuando tiene el foco
          ),
          filled: true,
          fillColor: Colors.grey[800], // Color de fondo del campo
        ),
      ),
    );
  }
}