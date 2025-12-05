// lib/screens/my_courses_screen.dart (New File)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:course/screens/course_detail_screen.dart';
import 'package:course/services/auth_service.dart';
import 'package:course/services/firestore_service.dart';
import 'package:course/widgets/course_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


// class UserProfileScreen {
//   const UserProfileScreen({
//     required this.uid,
//     required this.name,
//     required this.email,
//     this.role,
//     this.streak,
//   });
//   final String uid;
//   final String email;
//   final String? name;
//   final String? role;
//   final int? streak;


// }

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService(); // Or get from Provider

  // final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  int? outInt(){} // placeholders
  String? out(){} // placeholders

  @override
  Widget build(BuildContext context) {
    // final user = Provider.of<User?>(context); // Example if using Provider for user
    final user = _authService.currentUser;
    FirebaseAuth.instance.currentUser?.email;

    final String _email = FirebaseAuth.instance.currentUser?.email ?? '?';
    final String? _name = out();
    final String? _role = out();
    final int? _streak = outInt();


    if (user == null) {
      const Center(
          child: Text('Please log in to see your profile.'),
      );
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar( // avatar from first letter of name or email
              radius: 40,
              child:Text(
                _name != null ? _name[0].toUpperCase() : _email[0].toUpperCase(),
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _name ?? 'name not setted',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),

            Text(
              _email,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),

            const SizedBox(height: 16),

            // if (_role != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.badge_outlined),
                  const SizedBox(width: 8),
                  Text('Role: ${_role ?? 'not found'}'),
                ],
              ),

            // if (_streak != null) 
              ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department_outlined),
                  const SizedBox(width: 8),
                  Text('Strick: ${_streak} days'),
                ],
              ),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Редактирование пока не реализовано')),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Редактировать профиль'),
            ),
          ],
        ),
      );
  }

  
  // Widget _buildBody() {
  //   // ... (keep _buildBody as is, it already uses _filteredCourses)
  //   if (_isLoadingCourses) {
  //     return const Center(child: CircularProgressIndicator(key: Key("all_courses_loading")));
  //   }

  //   if (_allCourses.isEmpty && !_isLoadingCourses) {
  //     return const Center(child: Text('No courses available. Try adding sample data.'));
  //   }

  //   if (_searchQuery.isNotEmpty && _filteredCourses.isEmpty) {
  //     return Center(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           const Icon(Icons.search_off_rounded, size: 60, color: Colors.grey),
  //           const SizedBox(height: 16),
  //           Text('No courses found for "$_searchQuery".', style: const TextStyle(fontSize: 16)),
  //           const SizedBox(height: 8),
  //           Text('Try a different search term.', style: TextStyle(color: Colors.grey.shade600)),
  //         ],
  //       ),
  //     );
  //   }

  //   return ListView.builder(
  //     padding: const EdgeInsets.all(8.0),
  //     itemCount: _filteredCourses.length,
  //     itemBuilder: (context, index) {
  //       final course = _filteredCourses[index];
  //       return CourseCard(
  //         course: course,
  //         enrollmentDetails: _enrolledDetailsMap[course.id],
  //         onTap: () {
  //           FocusScope.of(context).unfocus(); // Hide keyboard
  //           if (_isSearching) _stopSearch(); // Optionally close search on tap
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(builder: (context) => CourseDetailScreen(courseId: course.id)),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }
}
