// lib/widgets/spinning_image_loader.dart
import 'package:flutter/material.dart';

class SpinningImageLoader extends StatefulWidget {
  const SpinningImageLoader({super.key});

  @override
  State<SpinningImageLoader> createState() => _SpinningImageLoaderState();
}

class _SpinningImageLoaderState extends State<SpinningImageLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/time.png',
        width: 80,
        height: 80,
      ),
    );
  }
}
