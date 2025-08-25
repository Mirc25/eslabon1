import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ImportaciÃ³n corregida para el nuevo nombre del archivo RateHelperScreen
import 'package:eslabon_flutter/screens/rate_helper_screen.dart'; 

// Este archivo ahora contiene la clase ConfirmHelpReceivedScreen
class ConfirmHelpReceivedScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  const ConfirmHelpReceivedScreen({Key? key, required this.requestData}) : super(key: key);

  @override
  State<ConfirmHelpReceivedScreen> createState() => _ConfirmHelpReceivedScreenState();
}

class _ConfirmHelpReceivedScreenState extends State<ConfirmHelpReceivedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _hasRated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfilesAndRatingStatus();
  }

  Future<void> _loadProfilesAndRatingStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      final requestId = widget.requestData['requestId'];

      if (userId != null && requestId != null) {
        final ratingDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('ratings') 
            .doc(requestId)
            .get();

        setState(() {
          _hasRated = ratingDoc.exists;
        });
      }
    } catch (e) {
      debugPrint("DEBUG CONFIRM: Error al cargar estado de valoraciÃ³n: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToRateScreen() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RateHelperScreen(
        requestId: widget.requestData['requestId'],
        requestData: widget.requestData,
        helperId: widget.requestData['helperId'],                 // <- nombre correcto
        helperName: widget.requestData['helperName'] ?? 'el usuario', // <- requerido
      ),
    ),
  ).then((_) => _loadProfilesAndRatingStatus());
}

  @override
  Widget build(BuildContext context) {
    final helperName = widget.requestData['helperName'] ?? 'el usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Ayuda'),
        backgroundColor: Colors.green,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Â¿Confirmas que $helperName te ayudÃ³?',
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _hasRated ? null : _navigateToRateScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasRated ? Colors.grey : Colors.green,
                    ),
                    child: Text(_hasRated ? 'Ya calificaste' : 'SÃ­, confirmar y calificar'),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  )
                ],
              ),
            ),
    );
  }
}
