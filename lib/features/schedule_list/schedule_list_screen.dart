import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/db/app_database.dart';
import '../providers/schedule_providers.dart';
import '../confirm/confirm_event_screen.dart';
import '../voice_input/voice_input_screen.dart';

class ScheduleListScreen extends ConsumerStatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  ConsumerState<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends ConsumerState<ScheduleListScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<ScheduleEvent> _eventsForDay(
      List<ScheduleEvent> all, DateTime day) {
    return all.where((e) {
      final local = e.startAt.toLocal();
      return local.year == day.year &&
          local.month == day.month &&
          local.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(scheduleEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('音声スケジュール'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (events) => Column(
          children: [
            TableCalendar<ScheduleEvent>(
              locale: 'ja_JP',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => _eventsForDay(events, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                setState(() => _focusedDay = focused);
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withAlpha(100),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle:
                    const TextStyle(color: Colors.red),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildEventList(events),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'voice',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoiceInputScreen(),
              ),
            ),
            tooltip: '音声で追加',
            child: const Icon(Icons.mic),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'manual',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConfirmEventScreen(),
              ),
            ),
            tooltip: '手動で追加',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(List<ScheduleEvent> all) {
    final displayed = _selectedDay != null
        ? _eventsForDay(all, _selectedDay!)
        : all;

    if (displayed.isEmpty) {
      return Center(
        child: Text(
          _selectedDay != null ? 'この日の予定はありません' : '予定がありません',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: displayed.length,
      itemBuilder: (context, i) => _EventTile(event: displayed[i]),
    );
  }
}

class _EventTile extends ConsumerWidget {
  final ScheduleEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = event.isAllDay
        ? DateFormat('M月d日(E)', 'ja').format(event.startAt.toLocal())
        : DateFormat('M月d日(E) HH:mm', 'ja').format(event.startAt.toLocal());

    return ListTile(
      title: Text(event.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: const TextStyle(fontSize: 12)),
          if (event.location != null)
            Text('📍 ${event.location}',
                style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () async {
          await ref
              .read(scheduleRepositoryProvider)
              .softDelete(event.id);
        },
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmEventScreen(editEvent: event),
        ),
      ),
    );
  }
}
