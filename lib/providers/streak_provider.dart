import 'package:shared_preferences/shared_preferences.dart';

class LocalStreakService {
  static const _keyTodayDate = 'today_date';
  static const _keyTodayCount = 'today_count';
  static const _keyPrevDate = 'prev_date';
  static const _keyPrevCount = 'prev_count';
  static const _keyStreak = 'streak';

  // Приводим дату к формату yyyy-MM-dd, чтобы не париться со временем
  String _dateToString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  DateTime? _dateFromString(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _yesterdayDateOnly() {
    final today = _todayDateOnly();
    return today.subtract(const Duration(days: 1));
  }

  /// Внутренний метод: убедиться, что для текущего дня
  /// корректно расставлены today/prev значения.
  Future<void> _ensureDayInitialized(SharedPreferences prefs) async {
    final today = _todayDateOnly();
    final todayStr = _dateToString(today);

    final storedTodayStr = prefs.getString(_keyTodayDate);

    // Первый запуск — ничего не сохранено
    if (storedTodayStr == null) {
      await prefs.setString(_keyTodayDate, todayStr);
      await prefs.setInt(_keyTodayCount, 0);
      // prev пусть будет пустым
      await prefs.remove(_keyPrevDate);
      await prefs.setInt(_keyPrevCount, 0);
      await prefs.setInt(_keyStreak, 0);
      return;
    }

    // Если дата совпадает — всё ок, ничего не меняем
    if (storedTodayStr == todayStr) {
      return;
    }

    // Если сегодня новый день — переносим today -> prev
    final storedTodayDate = _dateFromString(storedTodayStr);
    final storedTodayCount = prefs.getInt(_keyTodayCount) ?? 0;

    await prefs.setString(_keyPrevDate, storedTodayStr);
    await prefs.setInt(_keyPrevCount, storedTodayCount);

    // Обнуляем счётчик для нового дня
    await prefs.setString(_keyTodayDate, todayStr);
    await prefs.setInt(_keyTodayCount, 0);
  }

  /// Вызываем КАЖДЫЙ раз, когда ученик завершил урок.
  /// Возвращает новый streak.
  Future<int> onLessonCompleted() async {
    final prefs = await SharedPreferences.getInstance();

    // Следим за сменой дня
    await _ensureDayInitialized(prefs);

    final today = _todayDateOnly();
    final yesterday = _yesterdayDateOnly();

    final todayDateStr = prefs.getString(_keyTodayDate);
    final prevDateStr = prefs.getString(_keyPrevDate);
    final prevCount = prefs.getInt(_keyPrevCount) ?? 0;
    int todayCount = prefs.getInt(_keyTodayCount) ?? 0;
    int streak = prefs.getInt(_keyStreak) ?? 0;

    final todayDate = _dateFromString(todayDateStr) ?? today;
    final prevDate = _dateFromString(prevDateStr);

    final bool isFirstLessonToday = todayCount == 0;
    todayCount += 1;

    if (isFirstLessonToday) {
      final bool studiedYesterday =
          prevDate != null &&
          _dateToString(prevDate) == _dateToString(yesterday) &&
          prevCount > 0;

      if (studiedYesterday) {
        streak += 1; // продолжаем стрик
      } else {
        streak = 1; // начинаем новый стрик с сегодняшнего дня
      }
    }

    // сохраняем обновлённые значения
    await prefs.setString(_keyTodayDate, _dateToString(todayDate));
    await prefs.setInt(_keyTodayCount, todayCount);
    await prefs.setInt(_keyStreak, streak);

    return streak;
  }

  /// Просто получить текущий стрик (без изменений).
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDayInitialized(prefs);
    return prefs.getInt(_keyStreak) ?? 0;
  }

  /// По желанию: получить debug-инфу по дням
  Future<Map<String, dynamic>> getDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'today_date': prefs.getString(_keyTodayDate),
      'today_count': prefs.getInt(_keyTodayCount),
      'prev_date': prefs.getString(_keyPrevDate),
      'prev_count': prefs.getInt(_keyPrevCount),
      'streak': prefs.getInt(_keyStreak),
    };
  }

  /// Сбросить всё (удобно для тестов)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTodayDate);
    await prefs.remove(_keyTodayCount);
    await prefs.remove(_keyPrevDate);
    await prefs.remove(_keyPrevCount);
    await prefs.remove(_keyStreak);
  }
}
