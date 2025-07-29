import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'pablooviedo58@gmail.com',
      queryParameters: {'subject': 'Necesito ayuda'},
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'No se pudo abrir el cliente de correo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/eslabon_background.png',
            fit: BoxFit.cover,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Image.asset(
                'assets/logo.png',
                height: 120,
              ),
              const SizedBox(height: 10),
              const Text(
                'Hecho en Argentina',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 5),
              const Text(
                'Powered by Oviedo',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 40),
              const Text(
                'Cadena Solidaria de Favores',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber, width: 1.5),
                    foregroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Iniciar sesión',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber, width: 1.5),
                    foregroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Registrarse',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _launchEmail,
                child: const Text(
                  'Si necesitas ayuda, contáctanos',
                  style: TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
