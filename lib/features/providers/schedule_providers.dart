import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/schedule_repository.dart';

part 'schedule_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
ScheduleRepository scheduleRepository(Ref ref) {
  return ScheduleRepository(ref.watch(databaseProvider));
}

@riverpod
Stream<List<ScheduleEvent>> scheduleEvents(Ref ref) {
  return ref.watch(scheduleRepositoryProvider).watchAll();
}
