import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:course/models/course.dart';
import 'package:course/models/lesson.dart';
import 'package:course/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final String email;
  final String role;
  final int streak;      // 🔥 очки за сегодня (наружнее кольцо)
  final int streakDays;  // 🔥 дни стрика подряд (внутреннее кольцо)

  UserProfile({
    required this.name,
    required this.email,
    required this.role,
    required this.streak,
    required this.streakDays,
  });
}

// --- Enrollment Details Model ---
class EnrollmentDetails {
  final String courseId;
  final DateTime enrolledAt;
  int completedLessons;
  final int totalLessons;
  bool isCompleted;
  final List<String> completedLessonIds;

  EnrollmentDetails({
    required this.courseId,
    required this.enrolledAt,
    required this.completedLessons,
    required this.totalLessons,
    required this.isCompleted,
    this.completedLessonIds = const [],
  });

  factory EnrollmentDetails.fromMap(String courseId, Map<String, dynamic> data) {
    return EnrollmentDetails(
      courseId: courseId,
      enrolledAt: (data['enrolledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedLessons: data['completedLessons'] ?? 0,
      totalLessons: data['totalLessons'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      completedLessonIds: List<String>.from(data['completedLessonIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'enrolledAt': Timestamp.fromDate(enrolledAt),
      'completedLessons': completedLessons,
      'totalLessons': totalLessons,
      'isCompleted': isCompleted,
      'completedLessonIds': completedLessonIds,
    };
  }

  double get progressPercentage {
    if (totalLessons == 0) return 0.0;
    if (completedLessonIds.isNotEmpty &&
        completedLessonIds.length != completedLessons) {
      return completedLessonIds.length / totalLessons;
    }
    return completedLessons / totalLessons;
  }
}

// --- My Course Info Helper Class ---
class MyCourseInfo {
  final Course course;
  final EnrollmentDetails enrollmentDetails;
  MyCourseInfo(this.course, this.enrollmentDetails);
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // --- Course Functions ---

  Stream<List<Course>> getCourses() {
    return _db.collection('courses').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Course.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<UserProfile> userProfileStream(User user) {
    return _db.collection('users').doc(user.uid).snapshots().map((doc) {
      final data = doc.data() ?? {};

      final String email = (data['email'] ?? user.email ?? '?') as String;
      final String name = (data['name'] ?? 'Имя не задано') as String;
      final String role = (data['role'] ?? 'student') as String;

      // streak = очки, streakDays = дни стрика
      final int streak = (data['streak'] ?? 0) as int;
      final int streakDays = (data['streakDays'] ?? 0) as int;

      return UserProfile(
        name: name,
        email: email,
        role: role,
        streak: streak,
        streakDays: streakDays,
      );
    });
  }

  Future<UserProfile> getUserProfile(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      final String email = user.email ?? '?';
      return UserProfile(
        name: 'Имя не задано',
        email: email,
        role: 'student',
        streak: 0,
        streakDays: 0,
      );
    }

    final data = doc.data() ?? {};

    final String email = (data['email'] ?? user.email ?? '?') as String;
    final String name = (data['name'] ?? 'Имя не задано') as String;
    final String role = (data['role'] ?? 'student') as String;

    final int streak = (data['streak'] ?? 0) as int;
    final int streakDays = (data['streakDays'] ?? 0) as int;

    return UserProfile(
      name: name,
      email: email,
      role: role,
      streak: streak,
      streakDays: streakDays,
    );
  }

  Future<Course?> getCourseById(String courseId) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('courses').doc(courseId).get();
      debugPrint("--- Courses by id --- (${doc.id})");
      if (doc.exists) {
        return Course.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint("Error fetching course: $e");
    }
    return null;
  }

  // --- Helpers for streak ---

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Обновляет streak (очки за сегодня) и streakDays (дни стрика) после нового урока.
  Future<void> updateUserStatsAfterLessonCompleted() async {
    final user = _authService.currentUser;
    if (user == null) throw Exception("User not logged in.");

    final userRef = _db.collection('users').doc(user.uid);
    final DateTime today = _dateOnly(DateTime.now());

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};

      final int currentPoints = (data['streak'] ?? 0) as int; // очки за сегодня
      final int currentStreakDays =
          (data['streakDays'] ?? 0) as int; // дни стрика
      final Timestamp? lastTs = data['lastStudyDate'] as Timestamp?;

      int newPoints;
      int newStreakDays;

      if (lastTs == null) {
        // первый урок вообще
        newPoints = 1;
        newStreakDays = 1;
      } else {
        final DateTime lastDate = _dateOnly(lastTs.toDate());
        final int diff = today.difference(lastDate).inDays;

        if (diff == 0) {
          // урок уже был сегодня → добавляем очки, дни стрика не меняем
          newPoints = currentPoints + 1;
          newStreakDays = currentStreakDays == 0 ? 1 : currentStreakDays;
        } else if (diff == 1) {
          // вчера были уроки, сегодня тоже → продолжаем стрик
          newPoints = 1; // новый день — очки сначала
          newStreakDays = currentStreakDays + 1;
        } else {
          // пропущено больше одного дня → всё с нуля
          newPoints = 1;
          newStreakDays = 1;
        }
      }

      tx.set(
        userRef,
        {
          'streak': newPoints,         // очки за сегодня
          'streakDays': newStreakDays, // дни стрика
          'lastStudyDate': Timestamp.fromDate(today),
        },
        SetOptions(merge: true),
      );
    });
  }

  // --- Enrollment Functions ---

  Future<void> enrollInCourse(String courseId) async {
    final user = _authService.currentUser;
    if (user == null) {
      throw Exception("User not logged in to enroll.");
    }
    try {
      Course? course = await getCourseById(courseId);
      if (course == null) {
        throw Exception("Course not found.");
      }

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('enrolledCourses')
          .doc(courseId)
          .set({
        'enrolledAt': FieldValue.serverTimestamp(),
        'courseTitle': course.title,
        'completedLessons': 0,
        'totalLessons': course.lessons.length,
        'isCompleted': false,
        'completedLessonIds': [],
      });
      debugPrint(
          "User ${user.uid} enrolled in course $courseId with ${course.lessons.length} total lessons.");
    } catch (e) {
      debugPrint("Error enrolling in course: $e");
      rethrow;
    }
  }

  Future<void> unenrollFromCourse(String courseId) async {
    final user = _authService.currentUser;
    if (user == null) {
      throw Exception("User not logged in to unenroll.");
    }
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('enrolledCourses')
          .doc(courseId)
          .delete();
      debugPrint("User ${user.uid} unenrolled from course $courseId");
    } catch (e) {
      debugPrint("Error unenrolling from course: $e");
      rethrow;
    }
  }

  Stream<EnrollmentDetails?> getEnrollmentDetailsStream(String courseId) {
    final user = _authService.currentUser;
    if (user == null) {
      return Stream.value(null);
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('enrolledCourses')
        .doc(courseId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return EnrollmentDetails.fromMap(courseId, snapshot.data()!);
      }
      return null;
    });
  }

  Future<void> markLessonAsCompleted(String courseId, String lessonId) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception("User not logged in.");

    final enrollmentRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('enrolledCourses')
        .doc(courseId);

    bool lessonJustAdded = false;

    try {
      await _db.runTransaction((transaction) async {
        final enrollmentSnap = await transaction.get(enrollmentRef);
        if (!enrollmentSnap.exists || enrollmentSnap.data() == null) {
          throw Exception("User not enrolled.");
        }

        final data = enrollmentSnap.data() as Map<String, dynamic>;
        final completed =
            List<String>.from(data['completedLessonIds'] ?? []);

        // урок уже отмечен — ничего не делаем
        if (completed.contains(lessonId)) {
          return;
        }

        completed.add(lessonId);
        lessonJustAdded = true;

        final int totalLessons = data['totalLessons'] ?? 0;
        final bool isCompleted = completed.length >= totalLessons;

        transaction.update(enrollmentRef, {
          'completedLessonIds': completed,
          'completedLessons': completed.length,
          'isCompleted': isCompleted,
          'lastProgressTimestamp': FieldValue.serverTimestamp(),
        });
      });

      if (!lessonJustAdded) {
        debugPrint(
            "Lesson $lessonId for course $courseId already completed for user ${user.uid}, stats not updated.");
        return;
      }

      debugPrint(
          "Lesson $lessonId for course $courseId marked complete for user ${user.uid}");

      // новый урок → обновляем очки и дни стрика
      await updateUserStatsAfterLessonCompleted();
    } catch (e) {
      debugPrint("Error marking lesson complete: $e");
      rethrow;
    }
  }

  // --- My Courses Functions ---

  Stream<List<MyCourseInfo>> getMyCoursesWithProgress() {
    final user = _authService.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('enrolledCourses')
        .orderBy('enrolledAt', descending: true)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
      List<MyCourseInfo> myCoursesList = [];
      for (var enrollmentDoc in enrollmentSnapshot.docs) {
        final courseId = enrollmentDoc.id;
        final enrollmentData = enrollmentDoc.data();

        Course? course = await getCourseById(courseId);

        if (course != null) {
          EnrollmentDetails details =
              EnrollmentDetails.fromMap(courseId, enrollmentData);
          myCoursesList.add(MyCourseInfo(course, details));
        } else {
          debugPrint(
              "Course data not found for enrolled course ID: $courseId. User: ${user.uid}");
        }
      }
      return myCoursesList;
    });
  }

  // --- Sample Data (ensure lesson IDs are unique) ---
  Future<void> addSampleCoursesWithLessons() async {
    final coursesCollection = _db.collection('courses');

    final List<Course> sampleCourses = [
      Course(
        id: 'flutter_basics_001',
        title: '🚀 Flutter с нуля до профи 🛠',
        description:
            'В ходе курса, мы вместе разберемся с тем, что такое Flutter и как на нем сделать первое приложение.',
        instructorName: 'Ada Lovelace',
        imageUrl:
            'https://images.unsplash.com/photo-1633356122544-f134324a6cee?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
        lessons: [
          Lesson(
            id: 'fb_l1',
            title: 'Введение',
            videoUrl:
                'https://www.youtube.com/watch?v=FI-VshKxDZ0&list=PLtUuja72DaLIiIYLQP7rUjxItkDjHcSMw&index=1&pp=iAQB',
            order: 1,
            description:
                "Почему Flutter — лучший выбор в 2025 году, обзор курса",
            markdownUrl:
                "https://res.cloudinary.com/dackd9qol/raw/upload/v1765043958/lesson1_zditxn.md",
          ),
          Lesson(
            id: 'fb_l2',
            title: 'Установка и запуск первого приложения',
            videoUrl:
                'https://www.youtube.com/watch?v=SZDF1Y1K1UE&list=PLtUuja72DaLIiIYLQP7rUjxItkDjHcSMw&index=2&pp=iAQB',
            order: 2,
            description:
                "Полная установка на Windows/macOS/Linux, flutter doctor, первое приложение",
            markdownUrl:
                "https://res.cloudinary.com/dackd9qol/raw/upload/v1765043958/lesson2_pprqd1.md",
          ),
          Lesson(
            id: 'fb_l3',
            title: 'Основные виджеты: Stateful vs Stateless, Scaffold',
            videoUrl:
                'https://www.youtube.com/watch?v=6zrgNEDpwMo&list=PLtUuja72DaLIiIYLQP7rUjxItkDjHcSMw&index=3&pp=iAQB',
            order: 3,
            description:
                "Разница между Stateless и Stateful, структура MaterialApp",
            markdownUrl:
                "https://res.cloudinary.com/dackd9qol/raw/upload/v1765043958/lesson3_owoz6v.md",
          ),
          Lesson(
            id: 'fb_l4',
            title: 'Верстка, работа с темой, установка пакетов',
            videoUrl:
                'https://www.youtube.com/watch?v=QN6f3AmoMOE&list=PLtUuja72DaLIiIYLQP7rUjxItkDjHcSMw&index=4&pp=iAQB',
            order: 4,
            description:
                "Container, Row/Column, темы, google_fonts, красивые карточки",
            markdownUrl:
                "https://res.cloudinary.com/dackd9qol/raw/upload/v1765043959/lesson4_ylj410.md",
          ),
          Lesson(
            id: 'fb_l5',
            title: 'Навигация: Navigator, Named Routes, go_router',
            videoUrl:
                'https://www.youtube.com/watch?v=C8Qbk9PQR7M&list=PLtUuja72DaLIiIYLQP7rUjxItkDjHcSMw&index=5&t=6s&pp=iAQB',
            order: 5,
            description:
                "Современная навигация с go_router, переходы с анимацией",
            markdownUrl:
                "https://res.cloudinary.com/dackd9qol/raw/upload/v1765043959/lesson5_awfyds.md",
          ),
          Lesson(
            id: 'fb_l6',
            title: 'Архитектура проекта, рефакторинг, декомпозиция',
            videoUrl:
                'https://www.youtube.com/watch?v=B911Fi5UwwI&list=PLtUuja72DaLIiIYLQP7rUjxItkDjHcSMw&index=6&pp=iAQB',
            order: 6,
            description:
                "Feature-first структура, чистый код, разделение ответственностей",
            markdownUrl:
                "https://res.cloudinary.com/dackd9qol/raw/upload/v1765043959/lesson6_hyjkbo.md",
          ),
          Lesson(
            id: 'fb_l7',
            title: 'Работа с API, http и Dio',
            videoUrl:
                'https://www.youtube.com/watch?v=aT4hddCYSX4&list=PLtUuja72DaLIiIYLQP7rUjxItkDjHcSMw&index=7&pp=iAQB0gcJCRUKAYcqIYzv',
            order: 7,
            description:
                "Dio + retrofit + интерсепторы, обработка ошибок, кэширование",
            markdownUrl:
                "https://res.cloudinary.com/dackd9qol/raw/upload/v1765043959/lesson7_p0mvka.md",
          ),
        ],
      ),
    ];

    WriteBatch batch = _db.batch();
    for (var course in sampleCourses) {
      final courseRef = coursesCollection.doc(course.id);
      batch.set(courseRef, course.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
    debugPrint("Added/Updated sample courses with lessons to Firestore.");
  }
}
