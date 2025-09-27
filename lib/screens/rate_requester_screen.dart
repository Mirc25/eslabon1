import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart';
import 'package:eslabon_flutter/theme/app_colors.dart';

class RateRequesterScreen extends StatefulWidget {
  final String requestId;
  final String requesterId;
  final String requesterName;

  const RateRequesterScreen({
    super.key,
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
  });

  @override
  State<RateRequesterScreen> createState() => _RateRequesterScreenState();
}

class _RateRequesterScreenState extends State<RateRequesterScreen>
    with TickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  bool _hasRated = false;
  bool _isValidHelper = false;
  late AnimationController _animationController;
  late AnimationController _starAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _starAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _validateAndCheckRating();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _starAnimationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _validateAndCheckRating() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Verificar que el usuario actual sea el helper de esta solicitud
      final requestDoc = await FirebaseFirestore.instance
          .collection('solicitudes-de-ayuda')
          .doc(widget.requestId)
          .get();

      if (!requestDoc.exists) return;

      final requestData = requestDoc.data() as Map<String, dynamic>;
      final helperId = requestData['helperId'];

      if (helperId != currentUser.uid) {
        setState(() {
          _isValidHelper = false;
        });
        return;
      }

      setState(() {
        _isValidHelper = true;
      });

      // Verificar si ya calificó
      final ratingDoc = await FirebaseFirestore.instance
          .collection('ratings')
          .where('requestId', isEqualTo: widget.requestId)
          .where('sourceUserId', isEqualTo: currentUser.uid)
          .where('targetUserId', isEqualTo: widget.requesterId)
          .get();

      if (mounted) {
        setState(() {
          _hasRated = ratingDoc.docs.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error validating helper: $e');
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      _showSnackBar('Por favor selecciona una calificación', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('Usuario no autenticado', isError: true);
        return;
      }

      if (currentUser.uid == widget.requesterId) {
        _showSnackBar('No puedes calificarte a ti mismo', isError: true);
        return;
      }

      await FirestoreUtils.saveRating(
        requestId: widget.requestId,
        targetUserId: widget.requesterId,
        sourceUserId: currentUser.uid,
        rating: _rating.toDouble(),
        comment: _commentController.text.trim(),
        type: 'requester_rating',
      );

      if (mounted) {
        // Navegar a la pantalla de confirmación
        context.pushReplacement('/rating-confirmation', extra: {
          'helperName': widget.requesterName,
          'rating': _rating,
          'isHelper': false,
        });
      }
    } catch (e) {
      _showSnackBar('Error al enviar la calificación: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _rating = index + 1;
            });
            _starAnimationController.forward().then((_) {
              _starAnimationController.reverse();
            });
          },
          child: AnimatedBuilder(
            animation: _starAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _rating == index + 1 ? 1.0 + (_starAnimationController.value * 0.3) : 1.0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: index < _rating ? Colors.amber : Colors.grey[400],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidHelper) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Error', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'No tienes permisos para calificar\na este usuario',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => context.go('/main'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasRated) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Calificación', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                'Ya has calificado a ${widget.requesterName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => context.go('/main'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Calificar Solicitante', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header con avatar y nombre
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent.withOpacity(0.8), AppColors.primary.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            widget.requesterName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '¿Cómo fue tu experiencia ayudando?',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Rating stars
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Calificación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildStarRating(),
                          const SizedBox(height: 10),
                          if (_rating > 0)
                            Text(
                              _getRatingText(_rating),
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Comentario
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _commentController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Comparte tu experiencia (opcional)',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Botón de enviar
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Enviar Calificación',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }
}

