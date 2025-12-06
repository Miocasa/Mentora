import 'package:course/models/course.dart';
import 'package:course/models/lesson.dart';
import 'package:course/screens/markdown_reader_screen.dart';
import 'package:course/screens/video_player_screen.dart';
import 'package:course/services/auth_service.dart';
import 'package:course/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  void _openVideoLesson(
    BuildContext context,
    Course course,
    Lesson lesson,
    EnrollmentDetails? enrollment,
    bool isEffectivelyEnrolled,
  ) {
    if (!isEffectivelyEnrolled /* && !course.isPubliclyViewable */) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enroll to watch this lesson.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: lesson.videoUrl.toString(),
          lessonTitle: lesson.title,
        ),
      ),
    ).then((_) {
      if (isEffectivelyEnrolled &&
          enrollment != null &&
          !enrollment.isCompleted) {
        _firestoreService
            .markLessonAsCompleted(widget.courseId, lesson.id)
            .then(
              (_) => debugPrint(
                "Attempted to mark lesson ${lesson.id} complete (video)",
              ),
            )
            .catchError(
              (e) => debugPrint("Error marking lesson (video): $e"),
            );
      }
    });
  }

  void _openMarkdownLesson(
    BuildContext context,
    Course course,
    Lesson lesson,
    EnrollmentDetails? enrollment,
    bool isEffectivelyEnrolled,
  ) {
    if (!isEffectivelyEnrolled /* && !course.isPubliclyViewable */) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enroll to view lesson content.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownHomePage(
          markdownUrl: lesson.markdownUrl.toString(),
          lessonTitle: lesson.title,
        ),
      ),
    ).then((_) {
      if (isEffectivelyEnrolled &&
          enrollment != null &&
          !enrollment.isCompleted) {
        _firestoreService
            .markLessonAsCompleted(widget.courseId, lesson.id)
            .then(
              (_) => debugPrint(
                "Attempted to mark lesson ${lesson.id} complete (markdown)",
              ),
            )
            .catchError(
              (e) => debugPrint("Error marking lesson (markdown): $e"),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isUserLoggedIn = _authService.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Course?>(
          future: _firestoreService.getCourseById(widget.courseId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData ||
                snapshot.data == null) {
              return const Text('Loading...');
            }
            return Text(snapshot.data!.title);
          },
        ),
      ),
      body: FutureBuilder<Course?>(
        future: _firestoreService.getCourseById(widget.courseId),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (courseSnapshot.hasError ||
              !courseSnapshot.hasData ||
              courseSnapshot.data == null) {
            return const Center(
              child: Text('Course not found or error loading.'),
            );
          }

          final course = courseSnapshot.data!;

          return StreamBuilder<EnrollmentDetails?>(
            stream: isUserLoggedIn
                ? _firestoreService
                    .getEnrollmentDetailsStream(widget.courseId)
                : Stream.value(null),
            builder: (context, enrollmentSnapshot) {
              if (isUserLoggedIn &&
                  enrollmentSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (enrollmentSnapshot.hasError && isUserLoggedIn) {
                debugPrint(
                  "Enrollment snapshot error: ${enrollmentSnapshot.error}",
                );
              }

              final EnrollmentDetails? enrollment = enrollmentSnapshot.data;
              final bool isEffectivelyEnrolled = enrollment != null;

              double progressPercent = 0.0;
              if (isEffectivelyEnrolled) {
                progressPercent = enrollment!.progressPercentage;
              }

              // 🟢 СПИСОК ЗАВЕРШЁННЫХ УРОКОВ ПО ID
              // Замени `completedLessonIds` на своё название, если нужно
              final List<String> completedLessonIds =
                  enrollment?.completedLessonIds ?? <String>[];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- COURSE IMAGE ---
                    if (course.imageUrl.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.network(
                            course.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (
                              BuildContext context,
                              Widget child,
                              ImageChunkEvent? loadingProgress,
                            ) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 100,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // --- COURSE TITLE & INSTRUCTOR ---
                    Text(
                      course.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Instructor: ${course.instructorName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // --- COURSE DESCRIPTION ---
                    Text(
                      course.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    // --- ENROLLMENT BUTTON / PROGRESS ---
                    if (isUserLoggedIn)
                      Column(
                        children: [
                          if (isEffectivelyEnrolled && enrollment != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: LinearPercentIndicator(
                                animation: true,
                                lineHeight: 20.0,
                                animationDuration: 1000,
                                percent: progressPercent,
                                center: Text(
                                  "${(progressPercent * 100).toStringAsFixed(0)}%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                barRadius: const Radius.circular(10),
                                progressColor:
                                    Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey.shade300,
                              ),
                            ),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                if (isEffectivelyEnrolled) {
                                  bool? confirmUnenroll =
                                      await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text(
                                            'Confirm Unenrollment'),
                                        content: Text(
                                          'Are you sure you want to unenroll from "${course.title}"? Your progress will be lost.',
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('Cancel'),
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                          ),
                                          TextButton(
                                            child: const Text(
                                              'Unenroll',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(true),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (confirmUnenroll == true) {
                                    await _firestoreService
                                        .unenrollFromCourse(widget.courseId);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Successfully unenrolled!',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  await _firestoreService
                                      .enrollInCourse(widget.courseId);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Successfully enrolled!'),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error: ${e.toString().replaceFirst("Exception: ", "")}',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEffectivelyEnrolled
                                  ? Colors.red.shade400
                                  : Theme.of(context).primaryColor,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: Text(
                              isEffectivelyEnrolled
                                  ? 'Unenroll from Course'
                                  : 'Enroll in Course',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          "Please log in to enroll and view lessons.",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // --- LESSONS SECTION ---
                    Text(
                      'Lessons',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    if (course.lessons.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No lessons available for this course yet.',
                        ),
                      )
                    else if (!isUserLoggedIn && course.lessons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Log in to enroll and access lessons.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      )
                    else if (isUserLoggedIn &&
                        !isEffectivelyEnrolled &&
                        course.lessons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Enroll in the course to view lessons.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: course.lessons.length,
                        itemBuilder: (context, index) {
                          final lesson = course.lessons[index];

                          // 🟢 ТЕПЕРЬ УРОК СЧИТАЕТСЯ ЗАВЕРШЁННЫМ
                          // ЕСЛИ ЕГО ID ЕСТЬ В completedLessonIds
                          final bool lessonCompleted =
                              enrollment?.isCompleted == true ||
                                  completedLessonIds.contains(lesson.id);

                          return Card(
                            elevation: 2,
                            margin:
                                const EdgeInsets.symmetric(vertical: 6.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : Theme.of(context)
                                            .primaryColor
                                            .withAlpha(50),
                                child: Text(
                                  '${lesson.order}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context).primaryColorDark,
                                  ),
                                ),
                              ),
                              title: Text(
                                lesson.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: lesson.description.isNotEmpty
                                  ? Text(
                                      lesson.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,

                              // сейчас: тап по плитке = открываем markdown
                              onTap: () => _openMarkdownLesson(
                                context,
                                course,
                                lesson,
                                enrollment,
                                isEffectivelyEnrolled,
                              ),

                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // TEXT ICON
                                  if (!lessonCompleted)
                                    IconButton(
                                      icon: Icon(
                                        Icons.description_outlined,
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer
                                                : Theme.of(context)
                                                    .primaryColorDark,
                                      ),
                                      onPressed: () => _openMarkdownLesson(
                                        context,
                                        course,
                                        lesson,
                                        enrollment,
                                        isEffectivelyEnrolled,
                                      ),
                                    ),

                                  // VIDEO / CHECK ICON
                                  IconButton(
                                    icon: Icon(
                                      lessonCompleted
                                          ? Icons.check_circle
                                          : Icons.play_circle_outline,
                                      color: lessonCompleted
                                          ? Colors.green
                                          : Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : Theme.of(context)
                                                  .primaryColorDark,
                                    ),
                                    onPressed: () => _openVideoLesson(
                                      context,
                                      course,
                                      lesson,
                                      enrollment,
                                      isEffectivelyEnrolled,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
