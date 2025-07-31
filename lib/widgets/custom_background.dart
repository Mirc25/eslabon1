// lib/widgets/custom_background.dart
import 'package:flutter/material.dart';

class CustomBackground extends StatelessWidget {
  final Widget child;
  final bool showLogo;
  final bool showAds;
  final double logoTopPadding; // Para ajustar la posición vertical del logo

  const CustomBackground({
    Key? key, // Usa Key? key en lugar de super.key
    required this.child,
    this.showLogo = true,
    this.showAds = false, // Por defecto, no mostrar anuncios a menos que se especifique
    this.logoTopPadding = 100.0, // Valor por defecto
  }) : super(key: key); // Pasa key a super constructor

  @override
  Widget build(BuildContext context) {
    return Container(
      // ✅ Fondo de textura o imagen
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/eslabon_background.png'), // Ruta de tu imagen de fondo
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Si quieres un gradiente oscuro superpuesto sobre la textura
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black87.withOpacity(0.5), // Capa más oscura para mejor contraste del texto
                  Colors.black54.withOpacity(0.5),
                ],
              ),
            ),
          ),
          // ✅ Logo en la parte superior (ajusta la posición y tamaño según necesites)
          if (showLogo)
            Positioned(
              top: logoTopPadding, // Usa el padding ajustable
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/icon.jpg', // Ruta real de tu logo
                  height: 120, // Ajusta el tamaño del logo
                ),
              ),
            ),
          // El contenido real de la pantalla
          child,
          // ✅ Publicidad integrada (banner_ads) - Ajusta según tu necesidad
          if (showAds)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 50, // Altura del banner
                color: Colors.black54, // Color de fondo del banner
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