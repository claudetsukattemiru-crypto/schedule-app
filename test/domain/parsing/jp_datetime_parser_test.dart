import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_app/domain/parsing/jp_datetime_parser.dart';

void main() {
  final parser = JpDateTimeParser();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('relative day', () {
    test('今日', () {
      final r = parser.parse('今日15時に会議');
      expect(r.title, '会議');
      expect(r.startAt.toLocal().day, today.day);
      expect(r.startAt.toLocal().hour, 15);
      expect(r.isAllDay, false);
    });

    test('明日', () {
      final r = parser.parse('明日の午後3時に歯医者');
      expect(r.title, '歯医者');
      expect(r.startAt.toLocal().day, today.add(const Duration(days: 1)).day);
      expect(r.startAt.toLocal().hour, 15);
    });

    test('明後日 終日', () {
      final r = parser.parse('明後日に出張');
      expect(r.title, '出張');
      expect(r.isAllDay, true);
    });
  });

  group('weekday', () {
    test('来週火曜 15時', () {
      final r = parser.parse('来週火曜の15時に会議');
      expect(r.title, '会議');
      expect(r.startAt.toLocal().weekday, 2); // 火=2
      expect(r.startAt.toLocal().hour, 15);
    });

    test('単独曜日', () {
      final r = parser.parse('金曜日に打ち合わせ');
      expect(r.title, '打ち合わせ');
      expect(r.startAt.toLocal().weekday, 5); // 金=5
    });
  });

  group('absolute date', () {
    test('N月N日', () {
      final r = parser.parse('8月3日に出張');
      expect(r.title, '出張');
      expect(r.startAt.toLocal().month, 8);
      expect(r.startAt.toLocal().day, 3);
    });
  });

  group('time', () {
    test('午前時刻', () {
      final r = parser.parse('今日の午前10時30分に打ち合わせ');
      expect(r.startAt.toLocal().hour, 10);
      expect(r.startAt.toLocal().minute, 30);
    });

    test('19時', () {
      final r = parser.parse('今日19時から飲み会');
      expect(r.startAt.toLocal().hour, 19);
      expect(r.title, '飲み会');
    });
  });

  group('vague time', () {
    test('朝 → warning', () {
      final r = parser.parse('明日の朝に打ち合わせ');
      expect(r.startAt.toLocal().hour, 9);
      expect(r.warnings, isNotEmpty);
    });

    test('夜', () {
      final r = parser.parse('今日の夜に夕食');
      expect(r.startAt.toLocal().hour, 20);
    });
  });

  group('location', () {
    test('場所は◯◯', () {
      final r = parser.parse('明日15時に会議、場所は新宿');
      expect(r.location, '新宿');
      expect(r.title, '会議');
    });
  });
}
