import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/subtask.dart';
import '../../services/firestore_activity_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_task_snapshot_service.dart';

class ActivityEditScreen extends StatefulWidget {
  final DateTime date;
  final String weekId;
  final String dayId;
  final Activity? existing;

  const ActivityEditScreen({
    super.key,
    required this.date,
    required this.weekId,
    required this.dayId,
    this.existing,
  });

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  final FirestoreActivityService _service = FirestoreActivityService();
  late final WidgetTaskSnapshotService _widgetSnapshot =
      WidgetTaskSnapshotService(_service);

  late final TextEditingController _title;
  late final TextEditingController _description;

  TimeOfDay? _scheduledTime;

  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;

  bool _saving = false;

  String? _createdActivityId;

  String? get _activityId => widget.existing?.id ?? _createdActivityId;

  @override
  void initState() {
    super.initState();

    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );

    _scheduledTime = _parseHHmm(widget.existing?.scheduledTime);

    final reminder = widget.existing?.reminder ?? const <String, dynamic>{};
    _reminderEnabled = reminder['enabled'] == true;
    _reminderTime = _parseReminderTime(reminder) ?? _scheduledTime;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  TimeOfDay? _parseHHmm(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23) return null;
    if (m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  TimeOfDay? _parseReminderTime(Map<String, dynamic> reminder) {
    final remindAt = reminder['remindAt'];
    if (remindAt is Timestamp) {
      final dt = remindAt.toDate();
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
    return null;
  }

  String? _formatHHmm(TimeOfDay? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime _atTimeOfDay(DateTime day, TimeOfDay tod) {
    return DateTime(day.year, day.month, day.day, tod.hour, tod.minute);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _refreshWidgetIfToday() async {
    if (_isToday(widget.date)) {
      await _widgetSnapshot.updateToday(cutoffTime: '12:00');
    }
  }

  Future<void> _pickScheduledTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _scheduledTime = picked);

    // If reminder is enabled but had no explicit time, follow scheduled time.
    if (_reminderEnabled && _reminderTime == null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _reminderTime = picked);
  }

  Future<String?> _createActivityIfNeeded({required bool popOnCreate}) async {
    final existingId = _activityId;
    if (existingId != null) return existingId;

    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Título é obrigatório.')));
      return null;
    }

    await _service.ensureDayExists(
      weekId: widget.weekId,
      dayId: widget.dayId,
      date: widget.date,
    );

    final now = DateTime.now();

    final reminder = <String, dynamic>{'enabled': _reminderEnabled};

    if (_reminderEnabled) {
      final rt = _reminderTime ?? _scheduledTime;
      if (rt != null) {
        reminder['remindAt'] = Timestamp.fromDate(
          _atTimeOfDay(widget.date, rt),
        );
      }
    }

    final createdId = await _service.createActivity(
      weekId: widget.weekId,
      dayId: widget.dayId,
      activity: Activity(
        title: title,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        status: ActivityStatus.pending,
        order: now.millisecondsSinceEpoch,
        scheduledTime: _formatHHmm(_scheduledTime),
        reminder: reminder,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Schedule + persist notificationId (best effort).
    try {
      await NotificationService.instance.scheduleAndPersistForActivity(
        service: _service,
        weekId: widget.weekId,
        dayId: widget.dayId,
        activityId: createdId,
        title: title,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        status: ActivityStatus.pending,
        order: now.millisecondsSinceEpoch,
        scheduledTime: _formatHHmm(_scheduledTime),
        reminder: reminder,
        createdAt: now,
        updatedAt: now,
      );
    } catch (_) {
      // Ignore notification failures; the activity itself was created.
    }

    if (!mounted) return createdId;

    setState(() => _createdActivityId = createdId);

    if (popOnCreate) {
      Navigator.of(context).pop(true);
    }

    return createdId;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Título é obrigatório.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.ensureDayExists(
        weekId: widget.weekId,
        dayId: widget.dayId,
        date: widget.date,
      );

      final now = DateTime.now();

      final reminder = <String, dynamic>{'enabled': _reminderEnabled};

      if (_reminderEnabled) {
        final rt = _reminderTime ?? _scheduledTime;
        if (rt != null) {
          reminder['remindAt'] = Timestamp.fromDate(
            _atTimeOfDay(widget.date, rt),
          );
        }
      }

      final existing = widget.existing;

      if (existing?.id == null) {
        await _createActivityIfNeeded(popOnCreate: true);
      } else {
        // Update.
        final id = existing!.id!;

        // Cancel previous notification if any; we'll re-schedule below if enabled.
        await NotificationService.instance.cancelForActivity(
          weekId: widget.weekId,
          dayId: widget.dayId,
          activityId: id,
        );

        final updated = existing.copyWith(
          title: title,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          scheduledTime: _formatHHmm(_scheduledTime),
          reminder: reminder,
          updatedAt: now,
        );

        await _service.upsertActivity(
          weekId: widget.weekId,
          dayId: widget.dayId,
          activity: updated,
        );

        await NotificationService.instance.scheduleForActivityIfEnabled(
          weekId: widget.weekId,
          dayId: widget.dayId,
          activityId: id,
          title: title,
          reminder: reminder,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }

      await _refreshWidgetIfToday();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'permission-denied' || 'PERMISSION_DENIED' =>
          'Sem permissão no Firestore (regras).\nConfira autenticação/regras do Firebase.',
        'unauthenticated' => 'Você não está autenticado no Firebase.',
        _ => 'Erro ao salvar (${e.code}).',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = _activityId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir atividade?'),
        content: const Text('Isso também remove as subtarefas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await NotificationService.instance.cancelForActivity(
      weekId: widget.weekId,
      dayId: widget.dayId,
      activityId: id,
    );

    await _service.deleteActivity(
      weekId: widget.weekId,
      dayId: widget.dayId,
      activityId: id,
    );

    await _refreshWidgetIfToday();

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _addSubtask(String title) async {
    if (_saving) return;

    final activityId = _activityId;
    if (activityId == null) {
      setState(() => _saving = true);
      try {
        final createdId = await _createActivityIfNeeded(popOnCreate: false);
        if (createdId == null) return;
      } on FirebaseException catch (e) {
        if (!mounted) return;
        final msg = switch (e.code) {
          'permission-denied' ||
          'PERMISSION_DENIED' => 'Sem permissão no Firestore (regras).',
          'unauthenticated' => 'Você não está autenticado no Firebase.',
          _ => 'Erro ao salvar (${e.code}).',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    final ensuredId = _activityId;
    if (ensuredId == null) return;

    await _service.createSubtask(
      weekId: widget.weekId,
      dayId: widget.dayId,
      activityId: ensuredId,
      subtask: Subtask(
        title: title,
        done: false,
        order: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing?.id == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nova atividade' : 'Editar atividade'),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: 'Excluir',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Horário'),
              subtitle: Text(
                _scheduledTime == null
                    ? 'Sem horário'
                    : _formatHHmm(_scheduledTime)!,
              ),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: _pickScheduledTime,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lembrete'),
              value: _reminderEnabled,
              onChanged: (v) async {
                setState(() => _reminderEnabled = v);
                if (v) {
                  // Best effort: ask Android for notification permission.
                  await NotificationService.instance.ensurePermissions();
                }
              },
            ),
            if (_reminderEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora do lembrete'),
                subtitle: Text(
                  _reminderTime == null
                      ? 'Escolher'
                      : _formatHHmm(_reminderTime)!,
                ),
                trailing: const Icon(Icons.notifications_outlined),
                onTap: _pickReminderTime,
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Subtarefas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _SubtasksSection(
              service: _service,
              weekId: widget.weekId,
              dayId: widget.dayId,
              activityId: _activityId,
              onAdd: _addSubtask,
              enabled: !_saving,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtasksSection extends StatefulWidget {
  final FirestoreActivityService service;
  final String weekId;
  final String dayId;
  final String? activityId;
  final Future<void> Function(String title) onAdd;
  final bool enabled;

  const _SubtasksSection({
    required this.service,
    required this.weekId,
    required this.dayId,
    required this.activityId,
    required this.onAdd,
    required this.enabled,
  });

  @override
  State<_SubtasksSection> createState() => _SubtasksSectionState();
}

class _SubtasksSectionState extends State<_SubtasksSection> {
  final TextEditingController _newTitle = TextEditingController();

  @override
  void dispose() {
    _newTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityId = widget.activityId;

    return Column(
      children: [
        if (activityId != null)
          StreamBuilder<List<Subtask>>(
            stream: widget.service.watchSubtasks(
              weekId: widget.weekId,
              dayId: widget.dayId,
              activityId: activityId,
            ),
            builder: (context, snap) {
              final items = snap.data ?? const <Subtask>[];
              return Column(
                children: items
                    .map(
                      (s) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: s.done,
                        onChanged: widget.enabled
                            ? (v) {
                                if (v == null || s.id == null) return;
                                widget.service.setSubtaskDone(
                                  weekId: widget.weekId,
                                  dayId: widget.dayId,
                                  activityId: activityId,
                                  subtaskId: s.id!,
                                  done: v,
                                );
                              }
                            : null,
                        title: Text(s.title),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newTitle,
                decoration: const InputDecoration(
                  hintText: 'Nova subtarefa',
                  border: OutlineInputBorder(),
                ),
                enabled: widget.enabled,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.enabled
                  ? () async {
                      final t = _newTitle.text.trim();
                      if (t.isEmpty) return;
                      _newTitle.clear();
                      await widget.onAdd(t);
                    }
                  : null,
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ],
    );
  }
}
