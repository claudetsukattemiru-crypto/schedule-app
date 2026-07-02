import 'parsed_schedule_result.dart';

class JpDateTimeParser {
  ParsedScheduleResult parse(String text) {
    var remaining = text.trim();
    final warnings = <String>[];

    DateTime? date;
    int? hour;
    int? minute;
    bool isAllDay = false;
    String? location;

    // Extract location: 「場所は/が ◯◯」
    final locMatch = RegExp(
      r'場所(?:は|が)?\s*([^\s、,。.]+?)(?:で|$|(?=[\s、,。.]))',
    ).firstMatch(remaining);
    if (locMatch != null) {
      location = locMatch.group(1);
      remaining = remaining.replaceFirst(locMatch.group(0)!, '').trim();
    }

    final now = DateTime.now();

    // --- Absolute date: N月N日 ---
    final absDateMatch = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(remaining);
    if (absDateMatch != null) {
      int month = int.parse(absDateMatch.group(1)!);
      int day = int.parse(absDateMatch.group(2)!);
      date = DateTime(now.year, month, day);
      if (date.isBefore(now)) date = DateTime(now.year + 1, month, day);
      remaining = remaining.replaceFirst(absDateMatch.group(0)!, '').trim();
    }

    // --- Relative day: 今日/明日/明後日/昨日 ---
    if (date == null) {
      final relMap = {
        '今日': 0,
        'きょう': 0,
        '明日': 1,
        'あした': 1,
        '明後日': 2,
        'あさって': 2,
        '昨日': -1,
        'きのう': -1,
      };
      for (final entry in relMap.entries) {
        if (remaining.contains(entry.key)) {
          date = DateTime(now.year, now.month, now.day)
              .add(Duration(days: entry.value));
          remaining = remaining.replaceFirst(entry.key, '').trim();
          break;
        }
      }
    }

    // --- Week + weekday: 今週/来週/再来週 + 曜日 ---
    if (date == null) {
      final weekMatch = RegExp(
        r'(今週|来週|再来週)(の?)([月火水木金土日])曜日?',
      ).firstMatch(remaining);
      if (weekMatch != null) {
        final weekOffset = {'今週': 0, '来週': 7, '再来週': 14}[weekMatch.group(1)!]!;
        final weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];
        final targetWeekday = weekdayNames.indexOf(weekMatch.group(3)!) + 1;
        final todayWeekday = now.weekday; // 1=月 ... 7=日
        int daysToTarget = targetWeekday - todayWeekday;
        final baseDate = DateTime(now.year, now.month, now.day)
            .add(Duration(days: weekOffset + daysToTarget));
        date = baseDate;
        remaining = remaining.replaceFirst(weekMatch.group(0)!, '').trim();
      }
    }

    // --- Bare weekday: 月〜日曜日 (next occurrence) ---
    if (date == null) {
      final weekdayMatch =
          RegExp(r'([月火水木金土日])曜日?').firstMatch(remaining);
      if (weekdayMatch != null) {
        final weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];
        final targetWeekday = weekdayNames.indexOf(weekdayMatch.group(1)!) + 1;
        final todayWeekday = now.weekday;
        int daysUntil = targetWeekday - todayWeekday;
        if (daysUntil <= 0) daysUntil += 7;
        date = DateTime(now.year, now.month, now.day)
            .add(Duration(days: daysUntil));
        remaining =
            remaining.replaceFirst(weekdayMatch.group(0)!, '').trim();
      }
    }

    // Default date: today
    date ??= DateTime(now.year, now.month, now.day);

    // --- Explicit time: 午前/午後 N時 N分 ---
    final afternoonMatch =
        RegExp(r'午後(\d{1,2})時(?:(\d{1,2})分)?').firstMatch(remaining);
    if (afternoonMatch != null) {
      hour = int.parse(afternoonMatch.group(1)!) + 12;
      minute = int.tryParse(afternoonMatch.group(2) ?? '') ?? 0;
      if (hour == 24) hour = 12;
      remaining = remaining.replaceFirst(afternoonMatch.group(0)!, '').trim();
    }

    if (hour == null) {
      final morningMatch =
          RegExp(r'午前(\d{1,2})時(?:(\d{1,2})分)?').firstMatch(remaining);
      if (morningMatch != null) {
        hour = int.parse(morningMatch.group(1)!);
        minute = int.tryParse(morningMatch.group(2) ?? '') ?? 0;
        remaining =
            remaining.replaceFirst(morningMatch.group(0)!, '').trim();
      }
    }

    if (hour == null) {
      final timeMatch =
          RegExp(r'(\d{1,2})時(?:(\d{1,2})分)?').firstMatch(remaining);
      if (timeMatch != null) {
        hour = int.parse(timeMatch.group(1)!);
        minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
        remaining = remaining.replaceFirst(timeMatch.group(0)!, '').trim();
      }
    }

    // --- Vague time words ---
    if (hour == null) {
      const vagueMap = {
        '朝': (9, '朝 → 9:00（推定）'),
        '午前中': (10, '午前中 → 10:00（推定）'),
        '正午': (12, null),
        'お昼': (12, 'お昼 → 12:00（推定）'),
        '夕方': (17, '夕方 → 17:00（推定）'),
        '夜': (20, '夜 → 20:00（推定）'),
        '夜中': (23, '夜中 → 23:00（推定）'),
      };
      for (final entry in vagueMap.entries) {
        if (remaining.contains(entry.key)) {
          hour = entry.value.$1;
          minute = 0;
          if (entry.value.$2 != null) warnings.add(entry.value.$2!);
          remaining = remaining.replaceFirst(entry.key, '').trim();
          break;
        }
      }
    }

    if (hour == null) {
      isAllDay = true;
    }

    final startAt = isAllDay
        ? DateTime(date.year, date.month, date.day).toUtc()
        : DateTime(date.year, date.month, date.day, hour!, minute ?? 0).toUtc();

    // Clean up title: remove leading/trailing particles
    final title = remaining
        .replaceAll(RegExp(r'^[にのはをがでもから、。\s]+'), '')
        .replaceAll(RegExp(r'[にのはをがでもから、。\s]+$'), '')
        .trim();

    return ParsedScheduleResult(
      title: title.isEmpty ? '(タイトルなし)' : title,
      location: location,
      startAt: startAt,
      isAllDay: isAllDay,
      warnings: warnings,
    );
  }
}
