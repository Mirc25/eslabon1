// lib/screens/search_users_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../user_reputation_widget.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({Key? key}) : super(key: key);

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> _users = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers();
    });
  }

  Future<void> _searchUsers() async {
    final String queryText = _searchController.text.trim();
    if (queryText.isEmpty) {
      setState(() {
        _users.clear();
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('lowercaseName', isGreaterThanOrEqualTo: queryText.toLowerCase())
          .where('lowercaseName', isLessThanOrEqualTo: '${queryText.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      setState(() {
        _users = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
        _users.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'search_users_title'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'search_by_name'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[800],
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _users.clear();
                            });
                          },
                        )
                      : const Icon(Icons.search, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : _users.isEmpty
                      ? Center(child: Text(
                          _searchController.text.isEmpty
                              ? 'enter_name_to_search'.tr()
                              : 'no_users_found'.tr(),
                          style: const TextStyle(color: Colors.white70, fontSize: 16)
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final userData = _users[index].data() as Map<String, dynamic>;
                            final String userId = _users[index].id;
                            final String name = userData['name'] ?? 'Usuario Anónimo'.tr();
                            final String? profilePicture = userData['profilePicture'] as String?;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              color: Colors.grey[850],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 4,
                              child: InkWell(
                                onTap: () {
                                  context.pushNamed('user_profile_view', pathParameters: {'userId': userId}, extra: {'userName': name, 'userPhotoUrl': profilePicture});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: (profilePicture != null && profilePicture.startsWith('http'))
                                            ? NetworkImage(profilePicture)
                                            : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                        backgroundColor: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            UserReputationWidget(userId: userId),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}