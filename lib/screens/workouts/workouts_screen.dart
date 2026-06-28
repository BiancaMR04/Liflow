import 'package:flutter/material.dart';

import '../../models/fitness_exercise.dart';
import '../../models/workout.dart';
import '../../models/workout_session.dart';
import '../../services/fitness_service.dart';
import '../../ui/components/soft_card.dart';
import 'exercise_edit_dialog.dart';
import 'workout_edit_screen.dart';
import 'workout_run_screen.dart';
import 'workout_style.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  final FitnessService _service = FitnessService();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openWorkout([Workout? workout]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WorkoutEditScreen(workout: workout),
      ),
    );
  }

  Future<void> _createWorkout() async {
    await _openWorkout();
  }

  Future<void> _startWorkout(Workout workout) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutRunScreen(workout: workout)),
    );
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final id = workout.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: Text('Isso remove "${workout.name}" e seus exercícios.'),
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

    if (confirmed == true) await _service.deleteWorkout(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treinos'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Treinos'),
            Tab(text: 'Biblioteca'),
            Tab(text: 'Progresso'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _WorkoutListTab(
            service: _service,
            onCreate: _createWorkout,
            onEdit: _openWorkout,
            onStart: _startWorkout,
            onDelete: _deleteWorkout,
          ),
          _ExerciseLibraryTab(service: _service),
          _ProgressTab(service: _service),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          if (_tabs.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () async {
                final exercise = await showDialog<FitnessExercise>(
                  context: context,
                  builder: (_) => const ExerciseEditDialog(),
                );
                if (exercise != null) {
                  await _service.upsertLibraryExercise(exercise);
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Exercício'),
            );
          }

          if (_tabs.index == 0) {
            return FloatingActionButton.extended(
              onPressed: _createWorkout,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Treino'),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _WorkoutListTab extends StatelessWidget {
  final FitnessService service;
  final VoidCallback onCreate;
  final void Function(Workout workout) onEdit;
  final void Function(Workout workout) onStart;
  final void Function(Workout workout) onDelete;

  const _WorkoutListTab({
    required this.service,
    required this.onCreate,
    required this.onEdit,
    required this.onStart,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Workout>>(
      stream: service.watchWorkouts(),
      builder: (context, snap) {
        final workouts = snap.data ?? const <Workout>[];
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (workouts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 42,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Monte seu primeiro treino',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie templates como Treino A, B e C e execute com cronômetros automáticos.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Novo treino'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            final color = Color(
              workout.colorValue == 0
                  ? workoutColors.first
                  : workout.colorValue,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                onTap: () => onEdit(workout),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            workoutIcon(workout.iconName),
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workout.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if ((workout.description ?? '').isNotEmpty)
                                Text(
                                  workout.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Duplicar',
                          onPressed: workout.id == null
                              ? null
                              : () => service.duplicateWorkout(workout.id!),
                          icon: const Icon(Icons.copy),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') onEdit(workout);
                            if (value == 'delete') onDelete(workout);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder(
                            stream: service.watchWorkoutExercises(
                              workout.id ?? '',
                            ),
                            builder: (context, snap) {
                              final count = (snap.data as List?)?.length ?? 0;
                              return Text(
                                '$count exercícios',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => onStart(workout),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Iniciar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExerciseLibraryTab extends StatefulWidget {
  final FitnessService service;

  const _ExerciseLibraryTab({required this.service});

  @override
  State<_ExerciseLibraryTab> createState() => _ExerciseLibraryTabState();
}

class _ExerciseLibraryTabState extends State<_ExerciseLibraryTab> {
  final TextEditingController _search = TextEditingController();
  String _group = 'Todos';
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _editExercise(FitnessExercise? exercise) async {
    final result = await showDialog<FitnessExercise>(
      context: context,
      builder: (_) => ExerciseEditDialog(exercise: exercise),
    );
    if (result == null) return;
    await widget.service.upsertLibraryExercise(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar exercício',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Favoritos'),
                      selected: _favoritesOnly,
                      onSelected: (value) =>
                          setState(() => _favoritesOnly = value),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _group == 'Todos',
                      onSelected: (_) => setState(() => _group = 'Todos'),
                    ),
                    const SizedBox(width: 8),
                    ...MuscleGroups.all.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(group),
                          selected: _group == group,
                          onSelected: (_) => setState(() => _group = group),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FitnessExercise>>(
            stream: widget.service.watchLibraryExercises(),
            builder: (context, snap) {
              final query = _search.text.trim().toLowerCase();
              final exercises = (snap.data ?? const <FitnessExercise>[]).where((
                exercise,
              ) {
                if (_favoritesOnly && !exercise.favorite) return false;
                if (_group != 'Todos' && exercise.muscleGroup != _group) {
                  return false;
                }
                if (query.isEmpty) return true;
                return exercise.name.toLowerCase().contains(query);
              }).toList();

              if (exercises.isEmpty) {
                return const Center(
                  child: Text('Nenhum exercício encontrado.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      onTap: () => _editExercise(exercise),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Favorito',
                            onPressed: exercise.id == null
                                ? null
                                : () => widget.service.toggleFavoriteExercise(
                                    exerciseId: exercise.id!,
                                    favorite: !exercise.favorite,
                                  ),
                            icon: Icon(
                              exercise.favorite
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: exercise.favorite
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${exercise.muscleGroup} • usado ${exercise.useCount}x',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Excluir',
                            onPressed: exercise.id == null
                                ? null
                                : () => widget.service.deleteLibraryExercise(
                                    exercise.id!,
                                  ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProgressTab extends StatelessWidget {
  final FitnessService service;

  const _ProgressTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutSession>>(
      stream: service.watchRecentSessions(limit: 60),
      builder: (context, sessionSnap) {
        return StreamBuilder<List<ExerciseHistory>>(
          stream: service.watchHistory(limit: 400),
          builder: (context, historySnap) {
            final sessions = sessionSnap.data ?? const <WorkoutSession>[];
            final history = historySnap.data ?? const <ExerciseHistory>[];
            final totalSeconds = sessions.fold<int>(
              0,
              (sum, session) => sum + session.durationSeconds,
            );
            final totalVolume = sessions.fold<double>(
              0,
              (sum, session) => sum + session.totalVolume,
            );
            final streak = _trainingStreak(sessions);
            final mostDone = _mostDoneExercise(history);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Treinos',
                        value: sessions.length.toString(),
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Tempo',
                        value: '${(totalSeconds / 3600).toStringAsFixed(1)}h',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Sequência',
                        value: '$streak dias',
                        icon: Icons.local_fire_department_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Volume',
                        value: '${formatKg(totalVolume)}kg',
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Exercício mais realizado'),
                      const SizedBox(height: 8),
                      Text(mostDone),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Evolução de carga'),
                      const SizedBox(height: 10),
                      _LoadChart(history: history),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Treinos recentes'),
                      const SizedBox(height: 8),
                      if (sessions.isEmpty)
                        const Text('Nenhum treino concluído ainda.')
                      else
                        ...sessions
                            .take(8)
                            .map(
                              (session) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(session.workoutName),
                                subtitle: Text(
                                  '${session.setsDone} séries • ${formatKg(session.totalVolume)}kg',
                                ),
                                trailing: Text(
                                  '${session.completedAt.day.toString().padLeft(2, '0')}/${session.completedAt.month.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _trainingStreak(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) return 0;

    final days = sessions
        .map(
          (session) => DateTime(
            session.completedAt.year,
            session.completedAt.month,
            session.completedAt.day,
          ),
        )
        .toSet();

    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _mostDoneExercise(List<ExerciseHistory> history) {
    if (history.isEmpty) return 'Nenhum registro ainda';
    final counts = <String, int>{};
    for (final item in history) {
      counts[item.exerciseName] = (counts[item.exerciseName] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} • ${sorted.first.value} séries';
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
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
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _LoadChart extends StatelessWidget {
  final List<ExerciseHistory> history;

  const _LoadChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = history.take(8).toList().reversed.toList();
    if (recent.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Sem dados.')),
      );
    }

    final maxLoad = recent
        .map((item) => item.loadKg)
        .fold<double>(0, (max, value) => value > max ? value : max);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((item) {
          final height = maxLoad == 0 ? 10.0 : 110 * (item.loadKg / maxLoad);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formatKg(item.loadKg),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    height: height.clamp(8, 110),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
