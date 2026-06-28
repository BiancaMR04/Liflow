import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/workout.dart';
import '../../models/workout_exercise.dart';
import '../../models/workout_session.dart';
import '../../services/fitness_service.dart';
import '../../ui/components/soft_card.dart';
import 'workout_style.dart';

enum _RunPhase { ready, execution, rest, finished }

class WorkoutRunScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutRunScreen({super.key, required this.workout});

  @override
  State<WorkoutRunScreen> createState() => _WorkoutRunScreenState();
}

class _WorkoutRunScreenState extends State<WorkoutRunScreen> {
  final FitnessService _service = FitnessService();
  final TextEditingController _setNotes = TextEditingController();

  Timer? _timer;
  List<WorkoutExercise> _items = const <WorkoutExercise>[];
  final List<ExerciseHistory> _history = <ExerciseHistory>[];

  late final DateTime _startedAt;

  bool _loading = true;
  bool _autoStart = true;
  bool _failure = false;
  int _rpe = 8;
  int _exerciseIndex = 0;
  int _setNumber = 1;
  int _remaining = 0;
  _RunPhase _phase = _RunPhase.ready;

  WorkoutExercise? get _current {
    if (_items.isEmpty) return null;
    if (_exerciseIndex < 0 || _exerciseIndex >= _items.length) return null;
    return _items[_exerciseIndex];
  }

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _setNotes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final workoutId = widget.workout.id;
    if (workoutId == null) {
      setState(() => _loading = false);
      return;
    }

    final items = await _service.getWorkoutExercises(workoutId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _remaining = items.isEmpty ? 0 : _executionSeconds(items.first);
    });
  }

  int _executionSeconds(WorkoutExercise item) {
    if (item.executionSeconds > 0) return item.executionSeconds;
    return item.reps * item.secondsPerRep;
  }

  void _beep() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remaining <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        _beep();
        if (_phase == _RunPhase.rest) {
          _finishRest();
        }
      }
    });
  }

  void _startExecution() {
    final item = _current;
    if (item == null) return;
    setState(() {
      _phase = _RunPhase.execution;
      _remaining = _executionSeconds(item);
    });
    _startTimer();
  }

  void _startRest() {
    final item = _current;
    if (item == null) return;
    setState(() {
      _phase = _RunPhase.rest;
      _remaining = item.restSeconds;
    });
    if (_remaining <= 0) {
      _finishRest();
    } else {
      _startTimer();
    }
  }

  void _finishRest() {
    _advanceUnit();
    if (_phase == _RunPhase.finished) return;

    if (_autoStart) {
      _startExecution();
    } else {
      final item = _current;
      setState(() {
        _phase = _RunPhase.ready;
        _remaining = item == null ? 0 : _executionSeconds(item);
      });
    }
  }

  void _advanceUnit() {
    final item = _current;
    if (item == null) return;

    if (_setNumber < item.sets) {
      setState(() {
        _setNumber++;
        _failure = false;
        _rpe = 8;
        _setNotes.clear();
      });
      return;
    }

    if (_exerciseIndex < _items.length - 1) {
      setState(() {
        _exerciseIndex++;
        _setNumber = 1;
        _failure = false;
        _rpe = 8;
        _setNotes.clear();
      });
      return;
    }

    _finishWorkout();
  }

  Future<void> _completeSet() async {
    final item = _current;
    final workoutId = widget.workout.id;
    if (item == null || workoutId == null) return;

    _timer?.cancel();
    final now = DateTime.now();
    final notes = _setNotes.text.trim();

    _history.add(
      ExerciseHistory(
        sessionId: '',
        workoutId: workoutId,
        workoutName: widget.workout.name,
        workoutExerciseId: item.id ?? '',
        exerciseId: item.exerciseId,
        exerciseName: item.exerciseName,
        date: now,
        setNumber: _setNumber,
        reps: item.reps,
        loadKg: item.loadKg,
        executionSeconds: _executionSeconds(item),
        restSeconds: item.restSeconds,
        rpe: _rpe,
        failure: _failure,
        notes: notes.isEmpty ? null : notes,
      ),
    );

    _beep();
    _setNotes.clear();

    final isLastSet = _setNumber >= item.sets;
    final isLastExercise = _exerciseIndex >= _items.length - 1;
    if (isLastSet && isLastExercise) {
      await _finishWorkout();
      return;
    }

    _startRest();
  }

  Future<void> _finishWorkout() async {
    if (_phase == _RunPhase.finished) return;

    _timer?.cancel();
    final completedAt = DateTime.now();
    final workoutId = widget.workout.id ?? '';
    final duration = completedAt.difference(_startedAt).inSeconds;
    final totalVolume = _history.fold<double>(
      0,
      (sum, item) => sum + item.volume,
    );
    final exerciseIds = _history.map((item) => item.exerciseId).toSet();

    final session = WorkoutSession(
      workoutId: workoutId,
      workoutName: widget.workout.name,
      startedAt: _startedAt,
      completedAt: completedAt,
      durationSeconds: duration,
      exercisesDone: exerciseIds.length,
      setsDone: _history.length,
      totalVolume: totalVolume,
    );

    if (_history.isNotEmpty) {
      await _service.saveCompletedSession(session: session, history: _history);
    }

    if (!mounted) return;
    setState(() {
      _phase = _RunPhase.finished;
      _remaining = 0;
    });
  }

  String _phaseLabel() {
    return switch (_phase) {
      _RunPhase.ready => 'Pronto',
      _RunPhase.execution => 'Execução',
      _RunPhase.rest => 'Descanso',
      _RunPhase.finished => 'Concluído',
    };
  }

  double _timerProgress(WorkoutExercise item) {
    final total = _phase == _RunPhase.rest
        ? item.restSeconds
        : _executionSeconds(item);
    if (total <= 0) return 0;
    return (1 - (_remaining / total)).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _current;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          Switch(
            value: _autoStart,
            onChanged: (value) => setState(() => _autoStart = value),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : item == null
          ? const Center(child: Text('Este treino não tem exercícios.'))
          : _phase == _RunPhase.finished
          ? _FinishedView(
              history: _history,
              startedAt: _startedAt,
              onClose: () => Navigator.of(context).pop(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value:
                            (_exerciseIndex + (_setNumber / item.sets)) /
                            _items.length,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${_exerciseIndex + 1}/${_items.length}'),
                  ],
                ),
                const SizedBox(height: 14),
                _MediaCard(item: item),
                const SizedBox(height: 14),
                SoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.exerciseName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Chip(label: Text(_phaseLabel())),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.muscleGroup,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 176,
                              height: 176,
                              child: CircularProgressIndicator(
                                value: _timerProgress(item),
                                strokeWidth: 12,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  formatDuration(_remaining),
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  _phase == _RunPhase.rest
                                      ? 'Próxima série'
                                      : 'Série atual',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _RunStat(
                              label: 'Série',
                              value: '$_setNumber/${item.sets}',
                            ),
                          ),
                          Expanded(
                            child: _RunStat(
                              label: 'Reps',
                              value: item.reps.toString(),
                            ),
                          ),
                          Expanded(
                            child: _RunStat(
                              label: 'Carga',
                              value: '${formatKg(item.loadKg)}kg',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'RPE $_rpe',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Checkbox(
                            value: _failure,
                            onChanged: (value) =>
                                setState(() => _failure = value ?? false),
                          ),
                          const Text('Falha'),
                        ],
                      ),
                      Slider(
                        value: _rpe.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _rpe.toString(),
                        onChanged: (value) =>
                            setState(() => _rpe = value.round()),
                      ),
                      TextField(
                        controller: _setNotes,
                        decoration: const InputDecoration(
                          labelText: 'Notas da série',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: item == null || _phase == _RunPhase.finished
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (_phase == _RunPhase.rest)
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _finishRest,
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Pular descanso'),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _phase == _RunPhase.execution
                              ? null
                              : _startExecution,
                          icon: const Icon(Icons.timer_rounded),
                          label: const Text('Iniciar série'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _completeSet,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Concluir série'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final WorkoutExercise item;

  const _MediaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = item.imageUrl;
    final youtube = item.youtubeUrl;

    return SoftCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(imageUrl, fit: BoxFit.cover)
              else
                Container(
                  color: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.fitness_center,
                    size: 54,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (youtube != null && youtube.isNotEmpty)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.54),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 5),
                        Text('Vídeo', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunStat extends StatelessWidget {
  final String label;
  final String value;

  const _RunStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FinishedView extends StatelessWidget {
  final List<ExerciseHistory> history;
  final DateTime startedAt;
  final VoidCallback onClose;

  const _FinishedView({
    required this.history,
    required this.startedAt,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = DateTime.now().difference(startedAt).inSeconds;
    final volume = history.fold<double>(0, (sum, item) => sum + item.volume);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SoftCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 54,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Treino concluído',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text('${history.length} séries • ${formatKg(volume)}kg'),
              Text('Tempo total: ${formatDuration(duration)}'),
              const SizedBox(height: 18),
              FilledButton(onPressed: onClose, child: const Text('Fechar')),
            ],
          ),
        ),
      ),
    );
  }
}
