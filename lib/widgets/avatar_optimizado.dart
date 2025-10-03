import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:firebase_storage/firebase_storage.dart';

class _AvatarCacheManager extends CacheManager {
  static const key = 'avatar_optimizado_cache';
  _AvatarCacheManager()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 400,
        ));
}

class AvatarOptimizado extends StatelessWidget {
  final String? url; // URL directa (photoUrl, profileImageUrl, etc.)
  final String? storagePath; // Ruta en Firebase Storage (avatarPath)
  final int? avatarVersion; // Versión para invalidación controlada
  final double radius; // Mantener tamaño exacto (CircleAvatar usa radius)
  final Color? backgroundColor; // Mantener color de fondo
  final bool isCircle; // Mantener forma
  final Widget? placeholder;

  const AvatarOptimizado({
    super.key,
    this.url,
    this.storagePath,
    this.avatarVersion,
    required this.radius,
    this.backgroundColor,
    this.isCircle = true,
    this.placeholder,
  });

  String _sanitizeUrlForKey(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final filtered = Map<String, String>.from(uri.queryParameters)
        ..remove('token');
      final sanitized = uri.replace(queryParameters: filtered);
      return sanitized.toString();
    } catch (_) {
      // Fallback: usar la URL tal cual si algo falla
      return rawUrl;
    }
  }

  String? _deriveCacheKey({String? effectiveUrl}) {
    if (storagePath != null && storagePath!.isNotEmpty) {
      final v = avatarVersion ?? 1;
      return '${storagePath!}?v=$v';
    }
    if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
      return _sanitizeUrlForKey(effectiveUrl);
    }
    return null;
  }

  Future<String?> _resolveUrl() async {
    if (storagePath != null && storagePath!.isNotEmpty) {
      try {
        return await FirebaseStorage.instance.ref().child(storagePath!).getDownloadURL();
      } catch (_) {
        return null;
      }
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final double diameter = radius * 2;

    return FutureBuilder<String?>(
      future: _resolveUrl(),
      builder: (context, snapshot) {
        final effectiveUrl = snapshot.data;
        final cacheKey = _deriveCacheKey(effectiveUrl: effectiveUrl);

        // Placeholder consistente para evitar saltos visuales
        final Widget consistentPlaceholder = placeholder ?? CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey[700],
          child: const Icon(Icons.person, color: Colors.white70),
        );

        if (effectiveUrl == null || effectiveUrl.isEmpty) {
          return consistentPlaceholder;
        }

        return SizedBox(
          width: diameter,
          height: diameter,
          child: CachedNetworkImage(
            imageUrl: effectiveUrl,
            cacheKey: cacheKey,
            cacheManager: _AvatarCacheManager(),
            fadeInDuration: const Duration(milliseconds: 120),
            fadeOutDuration: const Duration(milliseconds: 60),
            memCacheWidth: diameter.round(),
            memCacheHeight: diameter.round(),
            placeholder: (_, __) => consistentPlaceholder,
            errorWidget: (_, __, ___) => CircleAvatar(
              radius: radius,
              backgroundColor: backgroundColor ?? Colors.grey[700],
              child: const Icon(Icons.person, color: Colors.white70),
            ),
            imageBuilder: (context, imageProvider) {
              final avatar = CircleAvatar(
                radius: radius,
                backgroundColor: backgroundColor ?? Colors.grey[700],
                backgroundImage: imageProvider,
              );
              if (isCircle) return avatar;
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: diameter,
                  height: diameter,
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}