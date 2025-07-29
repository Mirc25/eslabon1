import 'package:flutter/material.dart';

class CustomBackground extends StatelessWidget {
  final Widget child;

  const CustomBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // ✅ Fondo de textura o imagen
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/fondo_textura.png'), // <-- REEMPLAZA CON LA RUTA DE TU IMAGEN DE FONDO
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Si quieres un gradiente oscuro superpuesto sobre la textura
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black87, // Capa más oscura para mejor contraste del texto
                  Colors.black54,
                ],
              ),
            ),
          ),
          // ✅ Logo en la parte superior (ajusta la posición y tamaño según necesites)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, // Un poco de padding desde el top de la safe area
            left: 20, // Ajusta la posición lateral
            child: Image.asset(
              'assets/logo.png', // <-- REEMPLAZA CON LA RUTA REAL DE TU LOGO
              height: 40, // Ajusta el tamaño del logo
              // fit: BoxFit.contain,
            ),
          ),
          // El contenido real de la pantalla
          child,
        ],
      ),
    );
  }
}