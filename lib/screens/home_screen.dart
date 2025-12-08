import 'dart:async';

import 'package:course/customWidgets/progressbar.dart';
import 'package:course/models/course.dart';
import 'package:course/screens/course_detail_screen.dart';
import 'package:course/screens/my_courses_screen.dart';
import 'package:course/screens/settings_screen.dart';
import 'package:course/screens/user_profile_screen.dart';
import 'package:course/services/auth_service.dart';
import 'package:course/services/firestore_service.dart';
import 'package:course/widgets/course_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:course/generated/app_localizations.dart';


// Debouncer class
class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  dispose() {
    _timer?.cancel();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Debouncer _debouncer = Debouncer(milliseconds: 500);

  String _searchQuery = "";
  List<Course> _allCourses = [];
  List<Course> _filteredCourses = [];
  Map<String, EnrollmentDetails> _enrolledDetailsMap = {};
  StreamSubscription? _enrollmentSubscription;
  bool _isLoadingCourses = true;
  bool _isSearching = false;

  final List<({IconData icon, IconData selectedIcon, String label})> _destinations = [
    (icon: Icons.home_outlined,   selectedIcon: Icons.home,        label: 'Главная'),
    (icon: Icons.favorite_border, selectedIcon: Icons.favorite,    label: 'Мои курсы'),
    (icon: Icons.person_outline,  selectedIcon: Icons.person,      label: 'Профиль'),
  ];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAllCourses();
    _listenToEnrollments();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debouncer.dispose();
    _enrollmentSubscription?.cancel();
    super.dispose();
  }

  // === загрузка курсов ===
  void _loadAllCourses() async {
    setState(() {
      _isLoadingCourses = true;
    });
    _firestoreService.getCourses().first.then((courses) {
      if (mounted) {
        setState(() {
          _allCourses = courses;
          _filteredCourses = courses;
          _isLoadingCourses = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoadingCourses = false;
        });
        debugPrint("Error loading all courses: $error");
      }
    });
  }

  // === подписка на мои курсы с прогрессом ===
  void _listenToEnrollments() {
    if (_authService.currentUser != null) {
      _enrollmentSubscription = _firestoreService
          .getMyCoursesWithProgress()
          .listen((myCourseInfoList) {
        if (mounted) {
          Map<String, EnrollmentDetails> tempMap = {};
          for (var info in myCourseInfoList) {
            tempMap[info.course.id] = info.enrollmentDetails;
          }
          setState(() {
            _enrolledDetailsMap = tempMap;
          });
        }
      });
    } else {
      if (mounted && _enrolledDetailsMap.isNotEmpty) {
        setState(() {
          _enrolledDetailsMap.clear();
        });
      }
    }
  }

  // === поиск ===
  void _onSearchChanged() {
    _debouncer.run(() {
      if (mounted) {
        final query = _searchController.text.toLowerCase().trim();
        if (query != _searchQuery) {
          setState(() {
            _searchQuery = query;
            _filterCourses();
          });
        } else if (query.isEmpty && _searchQuery.isNotEmpty) {
          setState(() {
            _searchQuery = "";
            _filterCourses();
          });
        }
      }
    });
  }

  void _filterCourses() {
    if (_searchQuery.isEmpty) {
      _filteredCourses = List.from(_allCourses);
    } else {
      _filteredCourses = _allCourses.where((course) {
        final titleMatch = course.title.toLowerCase().contains(_searchQuery);
        final instructorMatch =
            course.instructorName.toLowerCase().contains(_searchQuery);
        return titleMatch || instructorMatch;
      }).toList();
    }
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  // === UI поиска в AppBar ===
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.homeSearchHint,
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: Theme.of(context).hintColor.withAlpha((252 * 0.8).toInt()),
        ),
      ),
      style: TextStyle(
        color: Theme.of(context).appBarTheme.foregroundColor ??
            Theme.of(context).colorScheme.onSurface,
        fontSize: 18,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopSearch,
          tooltip: AppLocalizations.of(context)!.homeSearchCloseTooltip,
        ),
        title: _buildSearchField(),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: "Clear Search",
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      );
    } else {
      return AppBar(
        title: const Text('e-learn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: AppLocalizations.of(context)!.homeSearchTooltip,
            onPressed: _startSearch,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: AppLocalizations.of(context)!.homeSettingsTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "--- MainScreen BUILD METHOD CALLED --- (Query: $_searchQuery, IsSearching: $_isSearching)");
    return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Builder(builder: (_) => _buildStore()),              // главная
          const MyCoursesScreen(),                             // мои курсы
          const UserProfileScreen(),                           // профиль
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
        },
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _destinations.map((dest) {
          return NavigationDestination(
            icon: Icon(dest.icon),
            selectedIcon: Icon(dest.selectedIcon),
            label: dest.label,
          );
        }).toList(),
      ),
      
      floatingActionButton: (kReleaseMode || _isSearching || _selectedIndex != 0)
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await _firestoreService.addSampleCoursesWithLessons();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Attempted to add/update sample courses.')),
                  );
                }
              },
              label: Text(AppLocalizations.of(context)!.homeSampleDataLabel),
              icon: const Icon(Icons.data_exploration_outlined),
            ),
    );
  }

  // === главный экран / витрина курсов + стрик ===
  Widget _buildStore() {
    if (_isLoadingCourses) {
      return const Center(
        child: CircularProgressIndicator(key: Key("all_courses_loading")),
      );
    }

    if (_allCourses.isEmpty && !_isLoadingCourses) {
      return Center(
        child: Text(AppLocalizations.of(context)!.homeNoCourses),
      );
    }

    if (_searchQuery.isNotEmpty && _filteredCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.homeNoCoursesForQuery(_searchQuery),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.homeTryDifferentTerm,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // один общий ListView:
    //   index 0  -> карточка стрика в рамке
    //   дальше -> карточки курсов
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _filteredCourses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // карточка стрика в начале списка
          return _buildStreakCard(context);
        }

        final course = _filteredCourses[index - 1];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: CourseCard(
            course: course,
            enrollmentDetails: _enrolledDetailsMap[course.id],
            onTap: () {
              FocusScope.of(context).unfocus();
              if (_isSearching) _stopSearch();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CourseDetailScreen(courseId: course.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStreakCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = _authService.currentUser;

    if (user == null) {
      // На всякий случай, если не залогинен
      return const SizedBox.shrink();
    }

    return StreamBuilder<UserProfile>(
      stream: _firestoreService.userProfileStream(user),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: colorScheme.surfaceContainerLow,
            child: const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final profile = snapshot.data!;
        // ✅ streak = очки (наружнее кольцо)
        // ✅ streakDays = дни стрика (внутреннее кольцо)
        final int outerProgress = profile.streak;       // очки за сегодня
        final int innerProgress = profile.streakDays;   // дни стрика

        const int outerGoal = 50; // цель очков за день
        const int innerGoal = 7;  // цель стрика (7 дней подряд)

        final double outerTarget =
            (outerProgress / outerGoal).clamp(0.0, 1.0) * 10;
        final double innerTarget =
            (innerProgress / innerGoal).clamp(0.0, 1.0);

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // заголовок
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.homeLearningProgressTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      AppLocalizations.of(context)!.homeInnerProgressLabel(innerProgress),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                TweenAnimationBuilder<double>(
                  key: ValueKey('$outerProgress-$innerProgress'),
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, t, _) {
                    return AnimatedProgressIndicator(
                      // 🔹 Наружнее кольцо — очки
                      progress: outerTarget * t,
                      // 🔹 Внутреннее — дни стрика
                      innerProgress: innerTarget * t,
                      // подписи
                      label: '${outerProgress * 10}',                     // крупная цифра — очки
                      subLabel: 'Дней стрика: $innerProgress',     // подпись — дни стрика
                      size: 220,
                      strokeWidth: 16,
                      innerStrokeWidth: 14,
                      outerColor: Colors.green,
                      innerColor: Colors.amber,
                    );
                  },
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 20, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.homeTodayPoints,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 20, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.homeStreakDays,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    ((outerTarget >= 1)
                    ? AppLocalizations.of(context)!.homeStatusDone
                    : (outerTarget >= 0.8
                    ? AppLocalizations.of(context)!.homeStatusAlmost
                    : ((outerTarget >= 0.6 && outerTarget < 0.8)
                    ? AppLocalizations.of(context)!.homeStatusFewLessons
                    : ((outerTarget > 0 && outerTarget < 0.6)
                    ? AppLocalizations.of(context)!.homeStatusGoodStart
                    : AppLocalizations.of(context)!.homeStatusStart
                    )))),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
