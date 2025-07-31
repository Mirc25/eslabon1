// lib/screens/ranking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importa tus widgets de branding y AppBar
import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomBackground(
      showLogo: true, // Muestra el logo centrado arriba
      showAds: false, // Puedes decidir si mostrar publicidad aquí
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Ranking de Usuarios'),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('averageRating', descending: true) // Ordenar por reputación de mayor a menor
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No hay rankings aún. ¡Sé el primero en ayudar!',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              );
            }

            final users = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userData = users[index].data() as Map<String, dynamic>;
                final int rank = index + 1; // Posición en el ranking

                final String name = userData['name'] ?? 'Usuario Anónimo';
                final String? photoUrl = userData['photoUrl'];
                final double averageRating = (userData['averageRating'] ?? 0.0).toDouble();
                final int helpCount = (userData['helpCount'] ?? 0); // Cantidad de calificaciones/ayudas

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  color: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Posición en el ranking
                        SizedBox(
                          width: 40,
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: rank <= 3 ? Colors.amber[700] : Colors.grey[700], // Destaca el top 3
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Foto de perfil
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        ),
                        const SizedBox(width: 16),
                        // Nombre y reputación
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    averageRating.toStringAsFixed(1), // Muestra 1 decimal
                                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${helpCount} ayudas)',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}