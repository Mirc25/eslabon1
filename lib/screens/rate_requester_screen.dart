// lib/screens/rate_requester_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../services/app_services.dart'; // Importa AppServices

class RateRequesterScreen extends ConsumerStatefulWidget {
  final String requestId;

  const RateRequesterScreen({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  ConsumerState<RateRequesterScreen> createState() => _RateRequesterScreenState();
}

class _RateRequesterScreenState extends ConsumerState<RateRequesterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _currentRating = 3.0;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyRated();
  }

  Future<void> _checkIfAlreadyRated() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final requestDoc = await _firestore.collection('requests').doc(widget.requestId).get();
    if (!requestDoc.exists || requestDoc.data() == null) return;
    final requesterId = requestDoc.data()!['userId'];

    if (requesterId == null) return;

    final QuerySnapshot existingRatings = await _firestore
        .collection('ratings')
        .where('requestId', isEqualTo: widget.requestId)
        .where('raterUserId', isEqualTo: currentUser.uid)
        .where('ratedUserId', isEqualTo: requesterId)
        .where('type', isEqualTo: 'requester_rating')
        .limit(1)
        .get();

    if (existingRatings.docs.isNotEmpty) {
      print('Ya has calificado a este solicitante para esta solicitud.');
    }
  }

  Future<void> _submitRating(
      Map<String, dynamic> requesterData, Map<String, dynamic> requestData) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para calificar.', Colors.red); // Usa el método estático
      return;
    }

    final String requesterId = requestData['userId'];
    if (requesterId == null) {
      AppServices.showSnackBar(context, 'Error: No se pudo identificar al solicitante.', Colors.red); // Usa el método estático
      return;
    }

    if (currentUser.uid == requesterId) {
       AppServices.showSnackBar(context, 'No puedes calificar tu propia solicitud aquí.', Colors.red); // Usa el método estático
      return;
    }

    String raterUserName = currentUser.displayName ?? 'Usuario';
    if (currentUser.displayName == null || currentUser.displayName!.isEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          raterUserName = userDoc.data()!['name'] ?? 'Usuario';
        }
      } catch (e) {
        print('Error fetching rater name: $e');
      }
    }

    try {
      await _firestore.collection('ratings').add({
        'requestId': widget.requestId,
        'ratedUserId': requesterId,
        'raterUserId': currentUser.uid,
        'rating': _currentRating,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'requester_rating',
        'raterUserName': raterUserName,
        'ratedUserName': requesterData['name'] ?? 'Solicitante',
      });

      AppServices.showSnackBar(context, 'Calificación enviada con éxito.', Colors.green); // Usa el método estático

      context.go('/');
    } catch (e) {
      AppServices.showSnackBar(context, 'Error al enviar calificación: $e', Colors.red); // Usa el método estático
      print('Error al enviar calificación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showLogo: true,
      showAds: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Calificar Solicitante',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait([
            _firestore.collection('requests').doc(widget.requestId).get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data![0].exists || snapshot.data![0].data() == null) {
              return const Center(child: Text('Solicitud no encontrada o datos incompletos.'));
            }

            final requestData = snapshot.data![0].data() as Map<String, dynamic>;
            final String requesterId = requestData['userId'];

            if (requesterId == null) {
              return const Center(child: Text('Error: No se pudo obtener el ID del solicitante.'));
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(requesterId).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (userSnapshot.hasError) {
                  return Center(child: Text('Error al cargar datos del solicitante: ${userSnapshot.error}'));
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists || userSnapshot.data!.data() == null) {
                  return const Center(child: Text('Datos del solicitante no encontrados.'));
                }

                final requesterData = userSnapshot.data!.data() as Map<String, dynamic>;

                final String requesterName = requesterData['name'] ?? 'Solicitante Desconocido';
                final String? requesterPhotoUrl = requesterData['photoUrl'];
                final String requestDescription = requestData['description'] ?? 'Sin descripción.';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: requesterPhotoUrl != null && requesterPhotoUrl.isNotEmpty
                            ? NetworkImage(requesterPhotoUrl)
                            : const AssetImage('assets/default_avatar.png') as ImageProvider,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        requesterName,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detalles de la Solicitud:',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              requestDescription,
                              style: const TextStyle(fontSize: 16),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Califica al solicitante:',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _currentRating.floor() ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            ),
                            onPressed: () {
                              setState(() {
                                _currentRating = (index + 1).toDouble();
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu calificación: ${_currentRating.round()}/5',
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => _submitRating(requesterData, requestData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Enviar Calificación'),
                      ),
                    ],
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