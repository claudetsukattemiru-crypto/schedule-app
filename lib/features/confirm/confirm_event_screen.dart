import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/db/app_database.dart';
import '../../domain/parsing/parsed_schedule_result.dart';
import '../providers/schedule_providers.dart';

class ConfirmEventScreen extends ConsumerStatefulWidget {
  final ParsedScheduleResult? parsed;
  final ScheduleEvent? editEvent;

  const ConfirmEventScreen({super.key, this.parsed, this.editEvent});

  @override
  ConsumerState<ConfirmEventScreen> createState() => _ConfirmEventScreenState();
}

class _ConfirmEventScreenState extends ConsumerState<ConfirmEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late DateTime _date;
  late TimeOfDay _time;
  late bool _isAllDay;

  @override
  void initState() {
    super.initState();

    if (widget.editEvent != null) {
      final e = widget.editEvent!;
      _titleCtrl = TextEditingController(text: e.title);
      _locationCtrl = TextEditingController(text: e.location ?? '');
      final local = e.startAt.toLocal();
      _date = DateTime(local.year, local.month, local.day);
      _time = TimeOfDay(hour: local.hour, minute: local.minute);
      _isAllDay = e.isAllDay;
    } else if (widget.parsed != null) {
      final p = widget.parsed!;
      _titleCtrl = TextEditingController(text: p.title);
      _locationCtrl = TextEditingController(text: p.location ?? '');
      final local = p.startAt.toLocal();
      _date = DateTime(local.year, local.month, local.day);
      _time = TimeOfDay(hour: local.hour, minute: local.minute);
      _isAllDay = p.isAllDay;
    } else {
      final now = DateTime.now();
      _titleCtrl = TextEditingController();
      _locationCtrl = TextEditingController();
      _date = DateTime(now.year, now.month, now.day);
      _time = TimeOfDay(hour: now.hour, minute: 0);
      _isAllDay = false;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(scheduleRepositoryProvider);
    final startAt = _isAllDay
        ? DateTime.utc(_date.year, _date.month, _date.day)
        : DateTime.utc(
            _date.year, _date.month, _date.day, _time.hour, _time.minute);

    if (widget.editEvent != null) {
      final updated = widget.editEvent!.copyWith(
        title: _titleCtrl.text.trim(),
        location: Value(_locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim()),
        startAt: startAt,
        isAllDay: _isAllDay,
        updatedAt: DateTime.now().toUtc(),
      );
      await repo.update(updated);
    } else {
      await repo.insert(
        title: _titleCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        startAt: startAt,
        isAllDay: _isAllDay,
        sourceType: widget.parsed != null ? 'voice' : 'manual',
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editEvent != null;
    final warnings = widget.parsed?.warnings ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '予定を編集' : '予定を確認'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (warnings.isNotEmpty) ...[
                ...warnings.map(
                  (w) => Card(
                    color: Colors.amber[100],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: '場所（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日付',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('yyyy年M月d日(E)', 'ja').format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('終日'),
                value: _isAllDay,
                onChanged: (v) => setState(() => _isAllDay = v!),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (!_isAllDay) ...[
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '時刻',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(_time.format(context)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEdit ? '更新' : '保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
