import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:course/customWidgets/progressbar.dart';
import 'package:course/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // User is not authenticated
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Пожалуйста, войдите, чтобы увидеть профиль.'),
        ),
      );
    }

    return FutureBuilder<UserProfile>(
      future: _firestoreService.getUserProfile(user), // Correct instance call
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Ошибка загрузки профиля: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('Профиль не найден.')),
          );
        }

        final profile = snapshot.data!;
        final String name = profile.name;
        final String email = profile.email;
        final String role = profile.role;
        final int streak = profile.streak;

        return _buildProfileView(
          context,
          name: name,
          email: email,
          role: role,
          streak: streak,
        );
      },
    );
  }

  Widget _buildProfileView(
  BuildContext context, {
  required String name,
  required String email,
  required String role,
  required int streak,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    

    return Scaffold(
      body:  SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        child: Column(
          children: [
          // Заголовочная карточка с аватаром и основной информацией
          Center(child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  // Аватар с акцентным фоном
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      (name.isNotEmpty ? name[0] : email[0]).toUpperCase(),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    name.isNotEmpty ? name : 'Имя не задано',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    email,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Роль и стрик в стиле "чипов"
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        avatar: Icon(Icons.badge_outlined, size: 18, color: colorScheme.primary),
                        label: Text(role),
                        backgroundColor: colorScheme.primaryContainer,
                        labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.local_fire_department,
                          size: 20,
                          color: streak > 0 
                          ? Colors.orange.shade700 
                          : colorScheme.outline,
                        ),
                        label: Text('$streak ${streak == 1 ? 'day' : 'дня'} стрик'),
                        backgroundColor: streak > 0 
                            ? ( Colors.orange.shade50 )
                            : colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          color: streak > 0 ? Colors.orange.shade900 : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton( // Hide FAB when searching
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Редактирование профиля скоро будет доступно'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        materialTapTargetSize: MaterialTapTargetSize.padded,
        child: Icon(Icons.edit_outlined),
        // label: const Text('Редактировать'), // edit
        // icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}


