import 'package:drift/drift.dart';

enum SourceType { voice, manual }

class ScheduleEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get sourceType =>
      text().withDefault(const Constant('manual'))();
  TextColumn get rawTranscript => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column> get primaryKey => {id};
}
