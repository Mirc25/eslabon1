// lib/user_reputation_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserReputationWidget extends StatelessWidget {
  final String userId;
  final bool fromRequesters; // true si queremos mostrar la reputaciÃ³n como solicitante, false como ayudador

  const UserReputationWidget({
    super.key,
    required this.userId,
    this.fromRequesters = false, // Por defecto, asume reputaciÃ³n como ayudador
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
          return const Text('Sin datos de reputaciÃ³n', style: TextStyle(color: Colors.white54, fontSize: 10));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final double averageRating = (userData['averageRating'] as num? ?? 0.0).toDouble();
        final int ratingCount = (userData['ratingCount'] as num? ?? 0).toInt();

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
