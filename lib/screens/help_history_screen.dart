// lib/screens/help_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../services/app_services.dart'; // Importa AppServices

import 'rate_requester_screen.dart';

class HelpHistoryScreen extends ConsumerStatefulWidget {
  const HelpHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HelpHistoryScreen> createState() => _HelpHistoryScreenState();
}

class _HelpHistoryScreenState extends ConsumerState<HelpHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AppServices _appServices; // Instancia de AppServices

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth); // Inicializa AppServices
  }

  Future<bool> _hasRatedRequester(String requestId, String requesterId) async {
    if (currentUser == null) return false;

    final QuerySnapshot ratings = await _firestore
        .collection('ratings')
        .where('requestId', isEqualTo: requestId)
        .where('raterUserId', isEqualTo: currentUser!.uid)
        .where('ratedUserId', isEqualTo: requesterId)
        .where('type', isEqualTo: 'requester_rating')
        .limit(1)
        .get();
    return ratings.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Usuario no autenticado.')),
      );
    }

    final String currentUserId = currentUser!.uid;

    return CustomBackground(
      showLogo: true,
      showAds: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Historial de Ayuda',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'Mis Solicitudes'),
                  Tab(text: 'Mis Ayudas'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMyRequestsSection(currentUserId),
                    _buildMyHelpsSection(currentUserId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyRequestsSection(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('requests')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
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
              'Aún no has publicado ninguna solicitud.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final String description = requestData['description'] ?? 'Sin descripción.';
            final String status = requestData['status'] ?? 'Desconocido';
            final Timestamp? timestamp = requestData['timestamp'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              color: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text('Estado: ${status.toUpperCase()}',
                        style: TextStyle(
                            fontSize: 14,
                            color: status == 'aceptada' ? Colors.green[700] : Colors.orange[700])),
                    if (timestamp != null)
                      Text(
                        'Fecha: ${timestamp.toDate().toLocal().day}/${timestamp.toDate().toLocal().month}/${timestamp.toDate().toLocal().year}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyHelpsSection(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('offers')
          .where('helperId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .orderBy('timestamp', descending: true)
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
              'Aún no has brindado ninguna ayuda aceptada.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final acceptedOffers = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: acceptedOffers.length,
          itemBuilder: (context, index) {
            final offerData = acceptedOffers[index].data() as Map<String, dynamic>;
            final String requestId = offerData['requestId'];
            final String requesterId = offerData['requesterId'];
            final String requesterName = offerData['requesterName'] ?? 'Solicitante';
            final Timestamp? offerTimestamp = offerData['timestamp'] as Timestamp?;

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('requests').doc(requestId).get(),
              builder: (context, requestSnapshot) {
                if (requestSnapshot.connectionState == ConnectionState.waiting) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: const ListTile(
                      title: Text('Cargando detalles de la solicitud...'),
                    ),
                  );
                }
                if (requestSnapshot.hasError || !requestSnapshot.hasData || !requestSnapshot.data!.exists) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: ListTile(
                      title: Text('Error al cargar solicitud para ${requesterName}'),
                      subtitle: Text('ID de Solicitud: $requestId'),
                    ),
                  );
                }

                final requestDetails = requestSnapshot.data!.data() as Map<String, dynamic>;
                final String requestDescription = requestDetails['description'] ?? 'Descripción no disponible.';

                return FutureBuilder<bool>(
                  future: _hasRatedRequester(requestId, requesterId),
                  builder: (context, ratedSnapshot) {
                    final bool hasRated = ratedSnapshot.data ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      color: Colors.white.withOpacity(0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ayudaste a: ${requesterName}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pedido: "$requestDescription"',
                              style: const TextStyle(fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (offerTimestamp != null)
                              Text(
                                'Fecha de Aceptación: ${offerTimestamp.toDate().toLocal().day}/${offerTimestamp.toDate().toLocal().month}/${offerTimestamp.toDate().toLocal().year}',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            const SizedBox(height: 8),
                            if (!hasRated)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context.go('/rate_requester/$requestId');
                                  },
                                  icon: const Icon(Icons.star),
                                  label: const Text('Calificar Solicitante'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              )
                            else
                              const Align(
                                alignment: Alignment.bottomRight,
                                child: Chip(
                                  label: Text('Solicitante Calificado'),
                                  backgroundColor: Colors.greenAccent,
                                  labelStyle: TextStyle(color: Colors.black87),
                                  avatar: Icon(Icons.check_circle_outline, color: Colors.black87, size: 18),
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
        );
      },
    );
  }
}