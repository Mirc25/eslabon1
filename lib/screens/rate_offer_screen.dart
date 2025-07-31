// lib/screens/rate_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../services/app_services.dart'; // Importa AppServices

class RateOfferScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String helperId;

  const RateOfferScreen({
    Key? key,
    required this.requestId,
    required this.helperId,
  }) : super(key: key);

  @override
  ConsumerState<RateOfferScreen> createState() => _RateOfferScreenState();
}

class _RateOfferScreenState extends ConsumerState<RateOfferScreen> {
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

    final QuerySnapshot existingRatings = await _firestore
        .collection('ratings')
        .where('requestId', isEqualTo: widget.requestId)
        .where('raterUserId', isEqualTo: currentUser.uid)
        .where('ratedUserId', isEqualTo: widget.helperId)
        .where('type', isEqualTo: 'helper_rating')
        .limit(1)
        .get();

    if (existingRatings.docs.isNotEmpty) {
      print('Esta oferta ya ha sido calificada por este solicitante.');
    }
  }

  Future<void> _submitRating(
      Map<String, dynamic> helperData, Map<String, dynamic> requestData) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para calificar.', Colors.red); // Usa el método estático
      return;
    }

    if (currentUser.uid != requestData['userId']) {
      AppServices.showSnackBar(context, 'Solo el solicitante puede calificar esta oferta.', Colors.red); // Usa el método estático
      return;
    }

    try {
      await _firestore.collection('ratings').add({
        'requestId': widget.requestId,
        'ratedUserId': widget.helperId,
        'raterUserId': currentUser.uid,
        'rating': _currentRating,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'helper_rating',
        'raterUserName': requestData['name'] ?? 'Solicitante',
        'ratedUserName': helperData['name'] ?? 'Ayudador',
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
          title: 'Calificar Oferta',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait([
            _firestore.collection('users').doc(widget.helperId).get(),
            _firestore.collection('requests').doc(widget.requestId).get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData ||
                snapshot.data![0].data() == null ||
                snapshot.data![1].data() == null) {
              return const Center(child: Text('Datos no encontrados.'));
            }

            final helperData = snapshot.data![0].data() as Map<String, dynamic>;
            final requestData = snapshot.data![1].data() as Map<String, dynamic>;

            final String helperName = helperData['name'] ?? 'Ayudador Desconocido';
            final String? helperPhotoUrl = helperData['photoUrl'];
            final String requestDescription = requestData['description'] ?? 'Sin descripción.';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: helperPhotoUrl != null && helperPhotoUrl.isNotEmpty
                        ? NetworkImage(helperPhotoUrl)
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    helperName,
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
                    'Califica la ayuda recibida:',
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
                    onPressed: () => _submitRating(helperData, requestData),
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
        ),
      ),
    );
  }
}