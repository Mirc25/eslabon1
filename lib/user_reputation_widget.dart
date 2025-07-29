// lib/user_reputation_widget.dart

import 'package:flutter/material.dart';
import 'package:eslabon_flutter/reputation_utils.dart'; // ¡Ruta corregida: ahora reputation_utils.dart está en lib/!

/// A widget that displays a user's average rating in the form of stars.
class UserReputationWidget extends StatelessWidget {
  final String userId;
  final bool fromRequesters;

  const UserReputationWidget({
    Key? key,
    required this.userId,
    required this.fromRequesters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si userId es nulo o vacío, no intentar obtener la reputación para evitar el error.
    if (userId.isEmpty) {
      return Row( // Muestra 5 estrellas vacías si no hay rating válido
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          return const Icon(
            Icons.star_border,
            color: Colors.grey,
            size: 20,
          );
        }),
      );
    }

    return FutureBuilder<double>(
      future: getAverageRating(userId: userId, fromRequesters: fromRequesters),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber,));
        }

        if (snapshot.hasError) {
          print('DEBUG REPUTATION WIDGET: Error en FutureBuilder para userId $userId: ${snapshot.error}'); // Más info en debug
          return const Icon(Icons.error, color: Colors.red, size: 20); // Icono de error
        }

        if (!snapshot.hasData || snapshot.data == null) { // También verifica si snapshot.data es nulo
          return Row( // Muestra 5 estrellas vacías si no hay rating
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return const Icon(
                Icons.star_border,
                color: Colors.grey,
                size: 20,
              );
            }),
          );
        }

        final average = snapshot.data!;
        final int stars = average.round(); // Redondea el promedio a un entero para las estrellas

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < stars ? Icons.star : Icons.star_border,
                  color: Colors.amber, // Estrellas doradas para calificación
                  size: 20,
                );
              }),
            ),
            const SizedBox(width: 8),
            Text(
              average.toStringAsFixed(1), // Muestra el promedio con un decimal
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }
}