// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? profilePicture;
  final String? province;
  final Map<String, dynamic> country;
  final DateTime? lastGlobalChatRead;
  final int? birthDay;
  final int? birthMonth;
  final int? birthYear;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePicture,
    this.province,
    required this.country,
    this.lastGlobalChatRead,
    this.birthDay,
    this.birthMonth,
    this.birthYear,
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      name: data['name'] as String? ?? 'Usuario',
      email: data['email'] as String? ?? '',
      profilePicture: data['profilePicture'] as String?,
      province: data['province'] as String?,
      country: data['country'] as Map<String, dynamic>? ?? {},
      lastGlobalChatRead: (data['lastGlobalChatRead'] as Timestamp?)?.toDate(),
      birthDay: (data['birthDay'] as num?)?.toInt(),
      birthMonth: (data['birthMonth'] as num?)?.toInt(),
      birthYear: (data['birthYear'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'profilePicture': profilePicture,
      'province': province,
      'country': country,
      'lastGlobalChatRead': lastGlobalChatRead != null ? Timestamp.fromDate(lastGlobalChatRead!) : null,
      'birthDay': birthDay,
      'birthMonth': birthMonth,
      'birthYear': birthYear,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profilePicture,
    String? province,
    Map<String, dynamic>? country,
    DateTime? lastGlobalChatRead,
    int? birthDay,
    int? birthMonth,
    int? birthYear,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
      province: province ?? this.province,
      country: country ?? this.country,
      lastGlobalChatRead: lastGlobalChatRead ?? this.lastGlobalChatRead,
      birthDay: birthDay ?? this.birthDay,
      birthMonth: birthMonth ?? this.birthMonth,
      birthYear: birthYear ?? this.birthYear,
    );
  }
}

