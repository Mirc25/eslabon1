// lib/screens/user_rating_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../reputation_utils.dart'; // ðŸ”„ CORRECCIÃ“N: Usamos el archivo correcto
import '../widgets/spinning_image_loader.dart';

class UserRatingDetailsScreen extends StatelessWidget {
  final String userId;
  final String? userName;

  const UserRatingDetailsScreen({
    Key? key,
    required this.userId,
    this.userName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'ReseÃ±as de ${userName ?? 'Usuario'}',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/main');
              }
            },
          ),
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: SpinningImageLoader());
            }
            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Center(child: Text('Error o usuario no encontrado.', style: TextStyle(color: Colors.red)));
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final String? profileImagePath = userData['profilePicture'] as String?;
            final String name = userData['name'] ?? 'Usuario Desconocido';
            
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  FutureBuilder<String>(
                    future: profileImagePath != null ? FirebaseStorage.instance.ref().child(profileImagePath).getDownloadURL() : Future.value(''),
                    builder: (context, urlSnapshot) {
                      final String? finalImageUrl = urlSnapshot.data;
                      return CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[700],
                        backgroundImage: (finalImageUrl != null && finalImageUrl.isNotEmpty)
                            ? NetworkImage(finalImageUrl) as ImageProvider
                            : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        child: (finalImageUrl == null || finalImageUrl.isEmpty)
                            ? const Icon(Icons.person, size: 60, color: Colors.white70)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  UserReputationWidget(userId: userId),
                  const SizedBox(height: 24),
                  const Text(
                    'Todas las calificaciones recibidas:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('ratings')
                        .where('targetUserId', isEqualTo: userId)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: SpinningImageLoader());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('Este usuario aÃºn no tiene reseÃ±as.', style: TextStyle(color: Colors.white70)));
                      }

                      final ratings = snapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ratings.length,
                        itemBuilder: (context, index) {
                          final ratingData = ratings[index].data() as Map<String, dynamic>;
                          final String sourceUserId = ratingData['sourceUserId'] as String? ?? 'Desconocido';
                          final String comment = ratingData['comment'] as String? ?? 'Sin reseÃ±a';
                          final double rating = (ratingData['rating'] as num? ?? 0.0).toDouble();
                          final Timestamp? timestamp = ratingData['timestamp'] as Timestamp?;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(sourceUserId).get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                                return const SizedBox.shrink();
                              }
                              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                              final String sourceUserName = userData['name'] ?? 'Usuario anÃ³nimo';

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                color: Colors.grey[850],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Calificado por: $sourceUserName',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, color: Colors.white70)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (comment.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(comment, style: const TextStyle(color: Colors.white70)),
                                        ),
                                      if (timestamp != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate()),
                                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
