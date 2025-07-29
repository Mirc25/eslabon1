import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserReputationWidget extends StatelessWidget {
  final String userId;
  final bool fromRequesters; // true si queremos mostrar la reputación como solicitante, false como ayudador

  const UserReputationWidget({
    super.key,
    required this.userId,
    this.fromRequesters = false, // Por defecto, asume reputación como ayudador
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error', style: TextStyle(color: Colors.red, fontSize: 10));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Cargando...', style: TextStyle(color: Colors.white54, fontSize: 10));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Sin datos de reputación', style: TextStyle(color: Colors.white54, fontSize: 10));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final double averageRating = userData['averageRating'] as double? ?? 0.0;
        final int ratingCount = userData['ratingCount'] as int? ?? 0;

        // Puedes ajustar la lógica si tienes diferentes campos para reputación de solicitantes/ayudadores
        // Por ahora, usamos el mismo 'averageRating' y 'ratingCount'

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              color: averageRating > 0 ? Colors.amber : Colors.grey,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '${averageRating.toStringAsFixed(1)} (${ratingCount})',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}