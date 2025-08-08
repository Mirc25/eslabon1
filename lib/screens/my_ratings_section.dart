// lib/screens/my_ratings_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';
import '../widgets/spinning_image_loader.dart'; // ✅ AÑADIDO: Importa el widget

class MyRatingsSection extends StatelessWidget {
  const MyRatingsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Debes iniciar sesión para ver tus calificaciones.', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('targetUserId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SpinningImageLoader()); // ✅ CORREGIDO: Usando el nuevo widget
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar calificaciones: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Aún no has recibido calificaciones. ¡Empieza a ayudar!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        final ratings = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: ratings.length,
          itemBuilder: (context, index) {
            final ratingData = ratings[index].data() as Map<String, dynamic>;
            final String sourceUserId = ratingData['sourceUserId'] as String? ?? 'Desconocido';
            final String comment = ratingData['comment'] as String? ?? 'Sin reseña';
            final double rating = (ratingData['rating'] as num? ?? 0.0).toDouble();
            final Timestamp? timestamp = ratingData['timestamp'] as Timestamp?;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(sourceUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final String sourceUserName = userData['name'] ?? 'Usuario anónimo';
                final String? sourceUserPhoto = userData['profilePicture'];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  color: Colors.grey[850],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: (sourceUserPhoto != null && sourceUserPhoto.startsWith('http'))
                          ? NetworkImage(sourceUserPhoto)
                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                      backgroundColor: Colors.grey[700],
                    ),
                    title: Text(sourceUserName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, color: Colors.white)),
                          ],
                        ),
                        if (comment.isNotEmpty) Text(comment, style: const TextStyle(color: Colors.white70)),
                        if (timestamp != null)
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate()),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    onTap: () => context.pushNamed('user_rating_details', pathParameters: {'userId': sourceUserId}, extra: sourceUserName),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}