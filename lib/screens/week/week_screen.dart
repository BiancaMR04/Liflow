import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/activity.dart';
import '../../services/date_ids.dart';
import '../../services/firestore_activity_service.dart';
import '../../services/widget_task_snapshot_service.dart';
import '../../services/notification_service.dart';
import '../activity/activity_edit_screen.dart';

import '../../ui/components/day_selector.dart';
import '../../ui/components/task_card.dart';
import '../../ui/components/soft_card.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> with WidgetsBindingObserver {
  final FirestoreActivityService _service = FirestoreActivityService();
  late final WidgetTaskSnapshotService _widgetSnapshot =
      WidgetTaskSnapshotService(_service);

  static const int _basePage = 10000;

  late final PageController _selectorController;
  late final PageController _contentController;

  late DateTime _anchorDate;
  int _selectedPage = _basePage;

  bool _authWarningShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Firestore security rules commonly require authenticated requests.
    // We keep the UX "no-login" by trying anonymous auth.
    _ensureAnonymousAuth();

    _anchorDate = _today();
    _selectedPage = _basePage;

    _selectorController = PageController(
      initialPage: _basePage,
      viewportFraction: 0.30,
    );
    _contentController = PageController(initialPage: _basePage);

    _refreshWidgetSnapshotToday();
  }

  Future<void> _ensureAnonymousAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return;

    try {
      await auth.signInAnonymously();
    } catch (_) {
      if (!mounted || _authWarningShown) return;
      _authWarningShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firebase: não foi possível autenticar. Ative "Anonymous" em Authentication > Sign-in method, ou ajuste as regras do Firestore.',
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selectorController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWidgetSnapshotToday();
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfWeek(DateTime date) {
    // Monday = 1
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dateForPage(int page) {
    return _anchorDate.add(Duration(days: page - _basePage));
  }

  List<DateTime> _daysOfWeek(DateTime date) {
    final start = _startOfWeek(date);
    return List<DateTime>.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _weekdayLabel(DateTime date) {
    const labels = <String>['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return labels[date.weekday - 1];
  }

  int? _parseMinutes(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23) return null;
    if (m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  bool _isMorning(Activity a) {
    final minutes = _parseMinutes(a.scheduledTime);
    if (minutes == null) return false;
    return minutes >= 5 * 60 && minutes < 12 * 60;
  }

  bool _isAfternoon(Activity a) {
    final minutes = _parseMinutes(a.scheduledTime);
    if (minutes == null) return false;
    return minutes >= 12 * 60 && minutes < 18 * 60;
  }

  bool _isNight(Activity a) {
    final minutes = _parseMinutes(a.scheduledTime);
    if (minutes == null) return true;
    return minutes < 5 * 60 || minutes >= 18 * 60;
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _ritualCard({
    required DateTime date,
    required String weekId,
    required String dayId,
  }) {
    return StreamBuilder<String?>(
      stream: _service.watchDayRitualMood(weekId: weekId, dayId: dayId),
      builder: (context, snap) {
        final theme = Theme.of(context);
        final mood = snap.data;

        Future<void> setMoodAndNotify(String value) async {
          try {
            await _service.setDayRitualMood(
              weekId: weekId,
              dayId: dayId,
              date: date,
              mood: value,
            );

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ritual do dia salvo.'),
                duration: Duration(seconds: 2),
              ),
            );
          } on FirebaseException {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível salvar agora.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        // Já respondeu: não mostra mais o card.
        if (mood != null) {
          return const SizedBox.shrink();
        }

        FilledButton moodButton({
          required String value,
          required String label,
        }) {
          return FilledButton.tonal(
            onPressed: () async => setMoodAndNotify(value),
            child: Text(label),
          );
        }

        return SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ritual do dia',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Como você está hoje?',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: moodButton(value: 'low', label: 'Baixa'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: moodButton(value: 'ok', label: 'Ok'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: moodButton(value: 'high', label: 'Alta'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshWidgetSnapshotToday() async {
    // Keep widget in sync with today's pending tasks.
    try {
      await _widgetSnapshot.updateToday(cutoffTime: '12:00');
    } on FirebaseException {
      // Firestore may be unavailable due to security rules; don't crash the UI.
    }
  }

  Future<void> _refreshWidgetIfToday(DateTime date) async {
    if (_isSameDay(date, _today())) {
      await _refreshWidgetSnapshotToday();
    }
  }

  Future<void> _toggleDone({
    required DateTime date,
    required String weekId,
    required String dayId,
    required Activity activity,
    required bool done,
  }) async {
    final activityId = activity.id;
    if (activityId == null) return;

    try {
      await _service.setActivityDone(
        weekId: weekId,
        dayId: dayId,
        activityId: activityId,
        done: done,
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        final msg =
            (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED')
            ? 'Sem permissão no Firestore (regras).'
            : 'Erro ao atualizar (${e.code}).';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }

    // Notifications: cancel when done; re-schedule when undone (if reminder enabled).
    if (done) {
      await NotificationService.instance.cancelForActivity(
        weekId: weekId,
        dayId: dayId,
        activityId: activityId,
      );
    } else {
      await NotificationService.instance.scheduleForActivityIfEnabled(
        weekId: weekId,
        dayId: dayId,
        activityId: activityId,
        title: activity.title,
        reminder: activity.reminder,
      );
    }

    await _refreshWidgetIfToday(date);
  }

  Future<void> _openCreateActivity(DateTime date) async {
    final weekId = DateIds.weekId(date);
    final dayId = DateIds.dayId(date);

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ActivityEditScreen(date: date, weekId: weekId, dayId: dayId),
      ),
    );

    if (changed == true && mounted) {
      // Force rebuild to ensure the StreamBuilder re-subscribes immediately.
      setState(() {});
    }

    await _refreshWidgetIfToday(date);
  }

  Future<void> _openEditActivity({
    required DateTime date,
    required Activity activity,
  }) async {
    final weekId = DateIds.weekId(date);
    final dayId = DateIds.dayId(date);

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ActivityEditScreen(
          date: date,
          weekId: weekId,
          dayId: dayId,
          existing: activity,
        ),
      ),
    );

    if (changed == true && mounted) {
      // Force rebuild to ensure the StreamBuilder re-subscribes immediately.
      setState(() {});
    }

    await _refreshWidgetIfToday(date);
  }

  Future<void> _duplicateDayFlow(DateTime sourceDate) async {
    final sourceWeekId = DateIds.weekId(sourceDate);
    final sourceDayId = DateIds.dayId(sourceDate);

    final daysInWeek = _daysOfWeek(sourceDate);

    final targetDate = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: daysInWeek
                .where((d) => !_isSameDay(d, sourceDate))
                .map(
                  (d) => ListTile(
                    title: Text(
                      '${_weekdayLabel(d)} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                    ),
                    onTap: () => Navigator.of(context).pop(d),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (targetDate == null) return;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Substituir dia?'),
          content: const Text(
            'Isso vai apagar tudo no dia destino e copiar as atividades do dia atual (SUBSTITUIR).',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final targetWeekId = DateIds.weekId(targetDate);
    final targetDayId = DateIds.dayId(targetDate);

    // Cancel notifications for activities that will be removed.
    final existingTargetActivities = await _service.getDayActivities(
      weekId: targetWeekId,
      dayId: targetDayId,
    );
    for (final a in existingTargetActivities) {
      final id = a.id;
      if (id == null) continue;
      await NotificationService.instance.cancelForActivity(
        weekId: targetWeekId,
        dayId: targetDayId,
        activityId: id,
      );
    }

    await _service.duplicateDayReplace(
      sourceWeekId: sourceWeekId,
      sourceDayId: sourceDayId,
      targetWeekId: targetWeekId,
      targetDayId: targetDayId,
      targetDate: targetDate,
    );

    // Schedule notifications for copied reminders (best effort).
    final copiedTargetActivities = await _service.getDayActivities(
      weekId: targetWeekId,
      dayId: targetDayId,
    );
    for (final a in copiedTargetActivities) {
      final id = a.id;
      if (id == null) continue;
      await NotificationService.instance.scheduleForActivityIfEnabled(
        weekId: targetWeekId,
        dayId: targetDayId,
        activityId: id,
        title: a.title,
        reminder: a.reminder,
      );
    }

    // Widget refresh if today was affected.
    await _refreshWidgetIfToday(sourceDate);
    await _refreshWidgetIfToday(targetDate);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dia duplicado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _dateForPage(_selectedPage);
    final selectedWeekId = DateIds.weekId(selectedDate);
    final selectedDayId = DateIds.dayId(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liflow'),
        actions: [
          IconButton(
            tooltip: 'Duplicar dia',
            onPressed: () => _duplicateDayFlow(selectedDate),
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: Column(
        children: [
          DaySelector(
            anchorDate: _anchorDate,
            basePage: _basePage,
            selectedPage: _selectedPage,
            controller: _selectorController,
            weekdayLabel: _weekdayLabel,
            isToday: (d) => _isSameDay(d, _today()),
            onPageChanged: (page) {
              if (page == _selectedPage) return;
              setState(() => _selectedPage = page);
              _contentController.animateToPage(
                page,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _ritualCard(
              date: selectedDate,
              weekId: selectedWeekId,
              dayId: selectedDayId,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _contentController,
              onPageChanged: (page) {
                if (page == _selectedPage) return;
                setState(() => _selectedPage = page);
                _selectorController.animateToPage(
                  page,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              },
              itemBuilder: (context, page) {
                final date = _dateForPage(page);
                final weekId = DateIds.weekId(date);
                final dayId = DateIds.dayId(date);

                return StreamBuilder<List<Activity>>(
                  stream: _service.watchDayActivities(
                    weekId: weekId,
                    dayId: dayId,
                  ),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      final err = snap.error;
                      String msg = 'Erro ao carregar atividades.';
                      if (err is FirebaseException) {
                        if (err.code == 'permission-denied' ||
                            err.code == 'PERMISSION_DENIED') {
                          msg = 'Sem permissão no Firestore (regras).';
                        } else {
                          msg = 'Erro Firestore (${err.code}).';
                        }
                      }
                      return Center(child: Text(msg));
                    }

                    final items = snap.data ?? const <Activity>[];
                    if (snap.connectionState == ConnectionState.waiting &&
                        snap.data == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Sem atividades neste dia.'),
                      );
                    }

                    final morning = items.where(_isMorning).toList();
                    final afternoon = items.where(_isAfternoon).toList();
                    final night = items.where(_isNight).toList();

                    Widget cards(List<Activity> list) {
                      return Column(
                        children: list.map((a) {
                          final done = a.status == ActivityStatus.done;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TaskCard(
                              activity: a,
                              done: done,
                              onTap: () =>
                                  _openEditActivity(date: date, activity: a),
                              onToggle: (v) {
                                _toggleDone(
                                  date: date,
                                  weekId: weekId,
                                  dayId: dayId,
                                  activity: a,
                                  done: v,
                                );
                              },
                            ),
                          );
                        }).toList(),
                      );
                    }

                    final children = <Widget>[];

                    if (morning.isNotEmpty) {
                      children.add(_sectionHeader(context, 'MANHÃ'));
                      children.add(cards(morning));
                    }

                    if (afternoon.isNotEmpty) {
                      children.add(_sectionHeader(context, 'TARDE'));
                      children.add(cards(afternoon));
                    }

                    if (night.isNotEmpty) {
                      children.add(_sectionHeader(context, 'NOITE'));
                      children.add(cards(night));
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: children,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Nova atividade',
        onPressed: () => _openCreateActivity(selectedDate),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova'),
      ),
    );
  }
}
