import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';

class ScheduleRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  ScheduleRepository(this._db);

  Stream<List<ScheduleEvent>> watchAll() {
    return (_db.select(_db.scheduleEvents)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startAt)]))
        .watch();
  }

  Future<List<ScheduleEvent>> getAll() {
    return (_db.select(_db.scheduleEvents)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startAt)]))
        .get();
  }

  Future<ScheduleEvent> insert({
    required String title,
    String? location,
    required DateTime startAt,
    DateTime? endAt,
    bool isAllDay = false,
    String? notes,
    String sourceType = 'manual',
    String? rawTranscript,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final companion = ScheduleEventsCompanion.insert(
      id: id,
      title: title,
      location: Value(location),
      startAt: startAt.toUtc(),
      endAt: Value(endAt?.toUtc()),
      isAllDay: Value(isAllDay),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
      sourceType: Value(sourceType),
      rawTranscript: Value(rawTranscript),
    );
    await _db.into(_db.scheduleEvents).insert(companion);
    return (_db.select(_db.scheduleEvents)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> update(ScheduleEvent event) async {
    final updated = event.copyWith(updatedAt: DateTime.now().toUtc());
    await _db.update(_db.scheduleEvents).replace(updated);
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.scheduleEvents)..where((t) => t.id.equals(id)))
        .write(ScheduleEventsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }
}
