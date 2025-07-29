import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId; 

  const RequestDetailScreen({
    super.key,
    required this.requestId, 
  });

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Solicitud'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ID de Solicitud: ${widget.requestId}'),
            const SizedBox(height: 20),
            const Text('Aquí se mostrarán los detalles completos de la solicitud.'),
          ],
        ),
      ),
    );
  }
}