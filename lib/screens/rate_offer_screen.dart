// lib/screens/rate_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Importar GoRouter

class RateOfferScreen extends StatelessWidget {
  final String requestId;
  final String helperId;
  final Map<String, dynamic>? requestData; // Recibir requestData como opcional

  const RateOfferScreen({
    super.key,
    required this.requestId,
    required this.helperId,
    this.requestData, // Hazlo opcional o requerido según tu necesidad. Lo dejo opcional por si no siempre se pasa.
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificar Oferta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop(); // Permite volver atrás
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Calificando oferta para solicitud ID: $requestId'),
            Text('Ayudante ID: $helperId'),
            if (requestData != null)
              Text('Descripción de Solicitud: ${requestData!['descripcion'] ?? 'N/A'}'),
            const SizedBox(height: 20),
            // Aquí iría tu UI para calificar
            const Text('UI de Calificación Aquí'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Lógica para enviar la calificación
                // Después de calificar, puedes volver a la pantalla principal o a la lista de notificaciones
                context.go('/main'); // O a donde sea apropiado después de calificar
              },
              child: const Text('Enviar Calificación (Ejemplo)'),
            ),
          ],
        ),
      ),
    );
  }
}
