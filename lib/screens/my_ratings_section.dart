// lib/screens/my_ratings_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';
import '../widgets/spinning_image_loader.dart'; // �o. A�'ADIDO: Importa el widget
import '../widgets/avatar_optimizado.dart';

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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SpinningImageLoader()); // �o. CORREGIDO: Usando el nuevo widget
        }
        if (snapshot.hasError) {
          final err = snapshot.error;
          String msg = 'Error al cargar calificaciones: $err';
          if (err is FirebaseException && err.code == 'failed-precondition') {
            msg = 'Error al cargar calificaciones: consulta sin índice. Ajustamos la consulta; si persiste, intenta reiniciar la app.';
          }
          return Center(child: Text(msg, style: const TextStyle(color: Colors.red)));
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

        // Ordenar en cliente para evitar requerir índice compuesto
        final ratings = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['timestamp'];
            final tb = (b.data() as Map<String, dynamic>)['timestamp'];
            final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da); // descendente
          });

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
                    leading: AvatarOptimizado(
                      url: (sourceUserPhoto != null && sourceUserPhoto.startsWith('http')) ? sourceUserPhoto : null,
                      storagePath: (sourceUserPhoto != null && !sourceUserPhoto.startsWith('http')) ? sourceUserPhoto : null,
                      radius: 25,
                      backgroundColor: Colors.grey[700],
                      placeholder: const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                        backgroundImage: AssetImage('assets/default_avatar.png'),
                      ),
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
                    onTap: () => context.pushNamed(
                      'user_profile_view',
                      pathParameters: {'userId': sourceUserId},
                      extra: {
                        'userName': sourceUserName,
                        'userPhotoUrl': sourceUserPhoto,
                      },
                    ),
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

