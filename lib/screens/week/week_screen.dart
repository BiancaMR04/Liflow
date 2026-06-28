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

class _RitualMoodOption {
  final String value;
  final String assetPath;
  final String label;

  const _RitualMoodOption({
    required this.value,
    required this.assetPath,
    required this.label,
  });
}

const List<_RitualMoodOption> _ritualMoodOptions = [
  _RitualMoodOption(
    value: 'chock',
    assetPath: 'assets/chock.jpeg',
    label: 'chocada',
  ),
  _RitualMoodOption(
    value: 'cocacola',
    assetPath: 'assets/cocacola.jpeg',
    label: 'querendo uma pausa',
  ),
  _RitualMoodOption(
    value: 'feliz',
    assetPath: 'assets/feliz.jpeg',
    label: 'feliz',
  ),
  _RitualMoodOption(
    value: 'furiosa',
    assetPath: 'assets/furiosa.jpeg',
    label: 'furiosa',
  ),
  _RitualMoodOption(
    value: 'linda',
    assetPath: 'assets/linda.jpeg',
    label: 'linda',
  ),
  _RitualMoodOption(
    value: 'maldosa',
    assetPath: 'assets/maldosa.jpeg',
    label: 'maldosa',
  ),
  _RitualMoodOption(
    value: 'pensante',
    assetPath: 'assets/pensante.jpeg',
    label: 'pensante',
  ),
  _RitualMoodOption(
    value: 'preocupada',
    assetPath: 'assets/preocupada.jpeg',
    label: 'preocupada',
  ),
  _RitualMoodOption(
    value: 'programadora',
    assetPath: 'assets/programadora.jpeg',
    label: 'programadora',
  ),
  _RitualMoodOption(
    value: 'socadora',
    assetPath: 'assets/socadora.jpeg',
    label: 'com energia',
  ),
  _RitualMoodOption(
    value: 'suspeito',
    assetPath: 'assets/suspeito.jpeg',
    label: 'suspeita',
  ),
  _RitualMoodOption(
    value: 'triste',
    assetPath: 'assets/triste.jpeg',
    label: 'triste',
  ),
];

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> with WidgetsBindingObserver {
  final FirestoreActivityService _service = FirestoreActivityService();
  late final WidgetTaskSnapshotService _widgetSnapshot =
      WidgetTaskSnapshotService(_service);

  static const int _todayIndex = 1;
  static const int _visibleDayCount = 8;

  late final PageController _selectorController;
  late final PageController _contentController;

  late DateTime _windowToday;
  int _selectedIndex = _todayIndex;

  bool _authWarningShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Firestore security rules commonly require authenticated requests.
    // We keep the UX "no-login" by trying anonymous auth.
    _ensureAnonymousAuth();

    _windowToday = _today();
    _selectedIndex = _todayIndex;

    _selectorController = PageController(
      initialPage: _todayIndex,
      viewportFraction: 0.30,
    );
    _contentController = PageController(initialPage: _todayIndex);

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
      final today = _today();
      if (!_isSameDay(today, _windowToday)) {
        setState(() {
          _windowToday = today;
          _selectedIndex = _todayIndex;
        });
        _selectorController.jumpToPage(_todayIndex);
        _contentController.jumpToPage(_todayIndex);
      }

      _refreshWidgetSnapshotToday();
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> _visibleDates() {
    return List<DateTime>.generate(
      _visibleDayCount,
      (index) => _windowToday.add(Duration(days: index - _todayIndex)),
    );
  }

  String _routineWeekId() {
    return DateIds.routineWeekId;
  }

  String _routineDayId(DateTime date) {
    return DateIds.routineDayId(date);
  }

  String _weekdayLabel(DateTime date) {
    const labels = <String>['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return labels[date.weekday - 1];
  }

  String _weekdayFullLabel(DateTime date) {
    const labels = <String>[
      'segunda',
      'terça',
      'quarta',
      'quinta',
      'sexta',
      'sábado',
      'domingo',
    ];
    return labels[date.weekday - 1];
  }

  DateTime _dateForWeekday(int weekday) {
    final delta = (weekday - _windowToday.weekday) % DateTime.daysPerWeek;
    return _windowToday.add(Duration(days: delta));
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

  bool _isDoneForDate(Activity activity, DateTime date) {
    if (activity.status != ActivityStatus.done) return false;
    final completedAt = activity.completedAt;
    if (completedAt == null) return false;

    return _isSameDay(completedAt, date);
  }

  DateTime _completionTimeForDate(DateTime date) {
    final now = DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
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
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ritualMoodOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final option = _ritualMoodOptions[index];

                  return Semantics(
                    button: true,
                    label: 'Responder ${option.label}',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async => setMoodAndNotify(option.value),
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.asset(
                              option.assetPath,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
        completedAt: done ? _completionTimeForDate(date) : null,
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
        scheduledTime: activity.scheduledTime,
        reminder: activity.reminder,
      );
    }

    await _refreshWidgetIfToday(date);
  }

  Future<void> _openCreateActivity(DateTime date) async {
    final weekId = _routineWeekId();
    final dayId = _routineDayId(date);

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
    final weekId = _routineWeekId();
    final dayId = _routineDayId(date);

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

  Future<void> _cancelNotificationsForRoutineDay({
    required String weekId,
    required String dayId,
  }) async {
    final existingActivities = await _service.getDayActivities(
      weekId: weekId,
      dayId: dayId,
    );
    for (final activity in existingActivities) {
      final id = activity.id;
      if (id == null) continue;
      await NotificationService.instance.cancelForActivity(
        weekId: weekId,
        dayId: dayId,
        activityId: id,
      );
    }
  }

  Future<void> _scheduleNotificationsForRoutineDay({
    required String weekId,
    required String dayId,
  }) async {
    final activities = await _service.getDayActivities(
      weekId: weekId,
      dayId: dayId,
    );
    for (final activity in activities) {
      final id = activity.id;
      if (id == null) continue;
      await NotificationService.instance.scheduleForActivityIfEnabled(
        weekId: weekId,
        dayId: dayId,
        activityId: id,
        title: activity.title,
        scheduledTime: activity.scheduledTime,
        reminder: activity.reminder,
      );
    }
  }

  Future<void> _replaceRoutineDay({
    required DateTime sourceDate,
    required DateTime targetDate,
  }) async {
    final weekId = _routineWeekId();
    final sourceDayId = _routineDayId(sourceDate);
    final targetDayId = _routineDayId(targetDate);

    if (sourceDayId == targetDayId) return;

    await _cancelNotificationsForRoutineDay(weekId: weekId, dayId: targetDayId);

    await _service.duplicateDayReplace(
      sourceWeekId: weekId,
      sourceDayId: sourceDayId,
      targetWeekId: weekId,
      targetDayId: targetDayId,
      targetDate: targetDate,
    );

    await _scheduleNotificationsForRoutineDay(
      weekId: weekId,
      dayId: targetDayId,
    );

    if (targetDate.weekday == _today().weekday) {
      await _refreshWidgetSnapshotToday();
    }
  }

  Future<void> _duplicateDayFlow(DateTime sourceDate) async {
    final theme = Theme.of(context);
    final sourceLabel = _weekdayFullLabel(sourceDate);

    final targetWeekday = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        final targetDates = List<DateTime>.generate(
          DateTime.daysPerWeek,
          (index) => _dateForWeekday(index + DateTime.monday),
        );

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                title: Text(
                  'Copiar $sourceLabel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('Escolha onde substituir a rotina.'),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_motion_outlined),
                title: const Text('Aplicar a todos os dias'),
                subtitle: const Text('Todos os dias ficam iguais a este.'),
                onTap: () => Navigator.of(context).pop(0),
              ),
              const Divider(height: 10),
              ...targetDates
                  .where((date) => date.weekday != sourceDate.weekday)
                  .map(
                    (date) => ListTile(
                      leading: const Icon(Icons.copy),
                      title: Text(_weekdayFullLabel(date)),
                      subtitle: Text(
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                      ),
                      onTap: () => Navigator.of(context).pop(date.weekday),
                    ),
                  ),
            ],
          ),
        );
      },
    );

    if (!mounted || targetWeekday == null) return;

    final applyingToAll = targetWeekday == 0;
    final targetDate = applyingToAll ? null : _dateForWeekday(targetWeekday);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(applyingToAll ? 'Aplicar a todos?' : 'Substituir dia?'),
          content: Text(
            applyingToAll
                ? 'Isso vai substituir todos os outros dias pela rotina de $sourceLabel.'
                : 'Isso vai substituir ${_weekdayFullLabel(targetDate!)} pela rotina de $sourceLabel.',
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

    if (applyingToAll) {
      for (
        var weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++
      ) {
        if (weekday == sourceDate.weekday) continue;
        await _replaceRoutineDay(
          sourceDate: sourceDate,
          targetDate: _dateForWeekday(weekday),
        );
      }
    } else {
      await _replaceRoutineDay(sourceDate: sourceDate, targetDate: targetDate!);
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rotina copiada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleDates = _visibleDates();
    final selectedDate = visibleDates[_selectedIndex];
    final selectedRitualWeekId = DateIds.weekId(selectedDate);
    final selectedRitualDayId = DateIds.dayId(selectedDate);

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
            dates: visibleDates,
            selectedIndex: _selectedIndex,
            controller: _selectorController,
            weekdayLabel: _weekdayLabel,
            isToday: (d) => _isSameDay(d, _today()),
            onIndexChanged: (index) {
              if (index == _selectedIndex) return;
              setState(() => _selectedIndex = index);
              _selectorController.animateToPage(
                index,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
              _contentController.animateToPage(
                index,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _ritualCard(
              date: selectedDate,
              weekId: selectedRitualWeekId,
              dayId: selectedRitualDayId,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _contentController,
              itemCount: visibleDates.length,
              onPageChanged: (index) {
                if (index == _selectedIndex) return;
                setState(() => _selectedIndex = index);
                _selectorController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              },
              itemBuilder: (context, index) {
                final date = visibleDates[index];
                final weekId = _routineWeekId();
                final dayId = _routineDayId(date);

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
                          final done = _isDoneForDate(a, date);
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
