// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading; // Parámetro para el widget a la izquierda (ej. botón de regreso)
  final List<Widget>? actions;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.leading, // Ahora es un parámetro opcional
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).primaryColor, // Usando el color primario del tema
      elevation: 4,
      centerTitle: true,
      automaticallyImplyLeading: false, // Controlado por el parámetro 'leading'
      leading: leading, // Usa el widget 'leading' proporcionado
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white, // Color del texto de la AppBar
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}