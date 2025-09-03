// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/spinning_image_loader.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Usuario no autenticado.')),
      );
    }

    final String currentUserId = currentUser!.uid;

    return CustomBackground(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
            title: 'history'.tr(),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: Column(
            children: [
              TabBar(
                indicatorColor: Colors.amber,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'help_requests'.tr()),
                  Tab(text: 'offers_sent'.tr()),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMyRequestsSection(currentUserId),
                    _buildMyOffersSection(currentUserId),
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
          .collection('solicitudes-de-ayuda')
          .where('userId', isEqualTo: userId)
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
          return Center(
            child: Text(
              'no_requests_published'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final String description = requestData['descripcion'] ?? 'Sin descripción.'.tr();
            final String status = requestData['estado'] ?? 'activa';
            final Timestamp? timestamp = requestData['timestamp'] as Timestamp?;
            final String requestId = requests[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: ListTile(
                onTap: () {
                  context.pushNamed(
                    'request_detail',
                    pathParameters: {'requestId': requestId},
                    extra: requestData,
                  );
                },
                title: Text(
                  description,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'status'.tr() + ': ${status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: status == 'aceptada' ? Colors.green[400] : Colors.orange[400],
                      ),
                    ),
                    if (timestamp != null)
                      Text(
                        'date'.tr() + ': ${DateFormat('dd/MM/yyyy').format(timestamp.toDate())}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyOffersSection(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('solicitudes-de-ayuda')
          .where('offers', arrayContains: userId)
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
          return Center(
            child: Text(
              'no_offers_sent'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final String description = requestData['descripcion'] ?? 'Sin descripción.'.tr();
            final String status = requestData['estado'] ?? 'activa';
            final Timestamp? timestamp = requestData['timestamp'] as Timestamp?;
            final String requestId = requests[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: ListTile(
                onTap: () {
                  context.pushNamed(
                    'request_detail',
                    pathParameters: {'requestId': requestId},
                    extra: requestData,
                  );
                },
                title: Text(
                  description,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'status'.tr() + ': ${status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: status == 'aceptada' ? Colors.green[400] : Colors.orange[400],
                      ),
                    ),
                    if (timestamp != null)
                      Text(
                        'date'.tr() + ': ${DateFormat('dd/MM/yyyy').format(timestamp.toDate())}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ),
            );
          },
        );
      },
    );
  }
}

