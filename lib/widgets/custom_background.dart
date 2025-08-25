// lib/widgets/custom_background.dart
import 'package:flutter/material.dart';

class CustomBackground extends StatelessWidget {
  final Widget child;
  final bool showAds; // Se mantiene si quieres banners de publicidad en el fondo

  const CustomBackground({
    Key? key,
    required this.child,
    this.showAds = false, // Por defecto, no muestra ads si no se especifica
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/eslabon_background.png'), // Ruta de tu imagen de fondo
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black87.withOpacity(0.5),
                  Colors.black54.withOpacity(0.5),
                ],
              ),
            ),
          ),
          // âœ… ELIMINADO: La lÃ³gica del logo ya no estÃ¡ aquÃ­.
          child, // El contenido de la pantalla
          if (showAds)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 50,
                color: Colors.black54,
                child: Center(
                  child: Image.asset(
                    'assets/ad_banner1.png', // Tu banner de publicidad
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
