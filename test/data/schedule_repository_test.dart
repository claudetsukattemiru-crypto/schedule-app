import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_app/data/db/app_database.dart';
import 'package:schedule_app/data/repositories/schedule_repository.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ScheduleRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert then getAll returns the inserted event', () async {
    final inserted = await repository.insert(
      title: '会議',
      startAt: DateTime.utc(2026, 7, 10, 15, 0),
    );

    final all = await repository.getAll();

    expect(all, hasLength(1));
    expect(all.single.id, inserted.id);
    expect(all.single.title, '会議');
    expect(all.single.deletedAt, isNull);
  });

  test('insert generates a client-side UUID primary key', () async {
    final a = await repository.insert(
      title: '予定A',
      startAt: DateTime.utc(2026, 7, 1),
    );
    final b = await repository.insert(
      title: '予定B',
      startAt: DateTime.utc(2026, 7, 2),
    );

    expect(a.id, isNot(equals(b.id)));
    expect(a.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('getAll orders events by startAt ascending', () async {
    await repository.insert(title: '後', startAt: DateTime.utc(2026, 7, 20));
    await repository.insert(title: '先', startAt: DateTime.utc(2026, 7, 5));

    final all = await repository.getAll();

    expect(all.map((e) => e.title), ['先', '後']);
  });

  test('softDelete hides the event from getAll without removing the row', () async {
    final inserted = await repository.insert(
      title: '削除予定',
      startAt: DateTime.utc(2026, 7, 15),
    );

    await repository.softDelete(inserted.id);
    final all = await repository.getAll();

    expect(all, isEmpty);

    final rawRow = await (db.select(db.scheduleEvents)
          ..where((t) => t.id.equals(inserted.id)))
        .getSingle();
    expect(rawRow.deletedAt, isNotNull);
  });

  test('update persists changed fields and bumps updatedAt', () async {
    final inserted = await repository.insert(
      title: '仮タイトル',
      startAt: DateTime.utc(2026, 7, 1, 9, 0),
    );

    // updatedAt is stored with second-level precision in SQLite, so the
    // delay must exceed 1s for the bump to be observable.
    await Future.delayed(const Duration(seconds: 1, milliseconds: 100));
    await repository.update(inserted.copyWith(title: '確定タイトル'));

    final all = await repository.getAll();
    expect(all.single.title, '確定タイトル');
    expect(all.single.updatedAt.isAfter(inserted.updatedAt), isTrue);
  });

  test('watchAll emits an updated list after insert', () async {
    final future =
        repository.watchAll().firstWhere((list) => list.isNotEmpty);
    await repository.insert(
      title: '通知予定',
      startAt: DateTime.utc(2026, 7, 8),
    );

    final emitted = await future;
    expect(emitted.map((e) => e.title), contains('通知予定'));
  });
}
