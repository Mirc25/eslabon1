// lib/screens/rate_requester_screen.dart
import 'package:flutter/material.dart';

class RateRequesterScreen extends StatelessWidget {
  final String requestId;
  final String requesterId; // ✅ AÑADIDO: Recibir requesterId
  final Map<String, dynamic>? requestData; // Puedes hacerlo opcional si no siempre lo pasas

  const RateRequesterScreen({
    super.key,
    required this.requestId,
    required this.requesterId, // ✅ AÑADIDO: Requerir requesterId
    this.requestData, // Hazlo opcional o requerido según tu necesidad
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificar Solicitante'),
      ),
      body: Center(
        child: Text('Calificando solicitante (ID: $requesterId) para solicitud ID: $requestId'),
      ),
    );
  }
}