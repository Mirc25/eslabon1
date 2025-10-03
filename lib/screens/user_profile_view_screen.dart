import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? userPhotoUrl;
  final String? message;

  const UserProfileViewScreen({
    Key? key,
    required this.userId,
    this.userName,
    this.userPhotoUrl,
    this.message,
  }) : super(key: key);

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  String _displayName = 'Cargando...';
  String _displayPhotoUrl = '';
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  
  // ✅ Sistema de caché para URLs de imágenes de perfil
  final Map<String, String> _profilePictureUrlCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (docSnapshot.exists) {
        _userData = docSnapshot.data() as Map<String, dynamic>;
        final String profilePicturePath = _userData['profilePicture'] ?? widget.userPhotoUrl ?? '';
        
        setState(() {
          _displayName = _userData['name'] ?? widget.userName ?? 'Usuario Desconocido';
        });
        
        // Optimización de carga de imagen de perfil
        if (profilePicturePath.isNotEmpty) {
          if (profilePicturePath.startsWith('http')) {
            // Ya es una URL completa
            setState(() {
              _displayPhotoUrl = profilePicturePath;
            });
          } else {
            // Es un path de Firebase Storage
            // 1. Verificar si el path está en el caché:
            if (_profilePictureUrlCache.containsKey(profilePicturePath)) {
              setState(() {
                _displayPhotoUrl = _profilePictureUrlCache[profilePicturePath]!;
              });
            } else {
              // 2. Si no está en caché, llamar a Storage:
              try {
                final url = await _storage.ref().child(profilePicturePath).getDownloadURL();
                // 3. Guardar en el caché:
                _profilePictureUrlCache[profilePicturePath] = url;
                setState(() {
                  _displayPhotoUrl = url;
                });
              } catch (e) {
                print('Error loading profile picture from Storage: $e');
                setState(() {
                  _displayPhotoUrl = '';
                });
              }
            }
          }
        }
      } else {
        setState(() {
          _displayName = widget.userName ?? 'Usuario no encontrado';
          _displayPhotoUrl = widget.userPhotoUrl ?? '';
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _displayName = widget.userName ?? 'Error al cargar';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_displayName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: (_displayPhotoUrl.isNotEmpty && _displayPhotoUrl.startsWith('http'))
                        ? NetworkImage(_displayPhotoUrl)
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                    child: _displayPhotoUrl.isEmpty || !_displayPhotoUrl.startsWith('http')
                        ? const Icon(Icons.person, size: 60, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _displayName,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Miembro desde: ${_userData['createdAt'] != null ? (_userData['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0] : 'N/A'}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  Text(
                    'Ayudó a: ${_userData['helpedCount'] ?? 0} personas',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  Text(
                    'Recibió ayuda de: ${_userData['receivedHelpCount'] ?? 0} personas',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),

                  if (widget.message != null && widget.message!.isNotEmpty)
                    Card(
                      color: Colors.blueGrey[800],
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mensaje de la notificación:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.message!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                  const Text(
                    'Más detalles del perfil irían aquí, cargados desde Firestore.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

