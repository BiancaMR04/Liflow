import 'package:flutter/material.dart';

import '../../models/fitness_exercise.dart';
import '../../models/workout.dart';
import '../../models/workout_exercise.dart';
import '../../services/fitness_service.dart';
import '../../ui/components/soft_card.dart';
import 'exercise_edit_dialog.dart';
import 'workout_style.dart';

class WorkoutEditScreen extends StatefulWidget {
  final Workout? workout;

  const WorkoutEditScreen({super.key, this.workout});

  @override
  State<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends State<WorkoutEditScreen> {
  final FitnessService _service = FitnessService();

  late final TextEditingController _name;
  late final TextEditingController _description;

  String? _workoutId;
  int _colorValue = workoutColors.first;
  String _iconName = 'fitness';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final workout = widget.workout;
    _workoutId = workout?.id;
    _name = TextEditingController(text: workout?.name ?? '');
    _description = TextEditingController(text: workout?.description ?? '');
    _colorValue = workout?.colorValue == 0
        ? workoutColors.first
        : workout?.colorValue ?? workoutColors.first;
    _iconName = workout?.iconName ?? 'fitness';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _descriptionOrNull() {
    final value = _description.text.trim();
    return value.isEmpty ? null : value;
  }

  Workout _workoutPayload({String? id}) {
    final now = DateTime.now();
    return Workout(
      id: id ?? _workoutId,
      name: _name.text.trim().isEmpty ? 'Treino sem nome' : _name.text.trim(),
      description: _descriptionOrNull(),
      colorValue: _colorValue,
      iconName: _iconName,
      order: widget.workout?.order ?? now.millisecondsSinceEpoch,
      createdAt: widget.workout?.createdAt,
      updatedAt: now,
    );
  }

  Future<String> _ensureWorkoutExists() async {
    final id = _workoutId;
    if (id != null) {
      await _service.updateWorkout(_workoutPayload(id: id));
      return id;
    }

    final createdId = await _service.createWorkout(_workoutPayload());
    setState(() => _workoutId = createdId);
    return createdId;
  }

  Future<void> _saveAndClose() async {
    setState(() => _saving = true);
    try {
      final id = await _ensureWorkoutExists();
      await _service.updateWorkout(_workoutPayload(id: id));
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addExercise() async {
    final workoutId = await _ensureWorkoutExists();
    if (!mounted) return;

    final exercise = await _pickExercise();
    if (exercise == null || !mounted) return;

    final item = await showDialog<WorkoutExercise>(
      context: context,
      builder: (_) => WorkoutExerciseEditDialog(exercise: exercise),
    );
    if (item == null) return;

    await _service.upsertWorkoutExercise(workoutId: workoutId, item: item);
  }

  Future<FitnessExercise?> _pickExercise() async {
    return showModalBottomSheet<FitnessExercise>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _ExercisePickerSheet(service: _service);
      },
    );
  }

  Future<void> _editExerciseItem(WorkoutExercise item) async {
    final workoutId = _workoutId;
    if (workoutId == null) return;

    final edited = await showDialog<WorkoutExercise>(
      context: context,
      builder: (_) => WorkoutExerciseEditDialog(item: item),
    );
    if (edited == null) return;

    await _service.upsertWorkoutExercise(workoutId: workoutId, item: edited);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workoutId = _workoutId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout == null ? 'Novo treino' : 'Editar treino'),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            onPressed: _saving ? null : _saveAndClose,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            SoftCard(
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Descrição opcional',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cor',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: workoutColors.map((value) {
                      final selected = value == _colorValue;
                      return InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _colorValue = value),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ícone',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: workoutIconNames.map((name) {
                      final selected = name == _iconName;
                      return IconButton.filledTonal(
                        isSelected: selected,
                        onPressed: () => setState(() => _iconName = name),
                        icon: Icon(workoutIcon(name)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Exercícios',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            if (workoutId == null)
              const SoftCard(
                child: Text(
                  'Salve ou adicione um exercício para criar o treino.',
                ),
              )
            else
              StreamBuilder<List<WorkoutExercise>>(
                stream: _service.watchWorkoutExercises(workoutId),
                builder: (context, snap) {
                  final items = snap.data ?? const <WorkoutExercise>[];
                  if (items.isEmpty) {
                    return const SoftCard(
                      child: Text('Nenhum exercício neste treino ainda.'),
                    );
                  }

                  return ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) async {
                      final updated = List<WorkoutExercise>.from(items);
                      if (newIndex > oldIndex) newIndex -= 1;
                      final moved = updated.removeAt(oldIndex);
                      updated.insert(newIndex, moved);
                      await _service.reorderWorkoutExercises(
                        workoutId: workoutId,
                        items: updated,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        key: ValueKey(item.id ?? index),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SoftCard(
                          onTap: () => _editExerciseItem(item),
                          child: Row(
                            children: [
                              Icon(
                                Icons.drag_handle_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.exerciseName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.sets}x${item.reps} • ${formatKg(item.loadKg)}kg • descanso ${item.restSeconds}s',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Duplicar',
                                onPressed: () {
                                  _service.duplicateWorkoutExercise(
                                    workoutId: workoutId,
                                    item: item,
                                  );
                                },
                                icon: const Icon(Icons.copy),
                              ),
                              IconButton(
                                tooltip: 'Excluir',
                                onPressed: () {
                                  final id = item.id;
                                  if (id == null) return;
                                  _service.deleteWorkoutExercise(
                                    workoutId: workoutId,
                                    itemId: id,
                                  );
                                },
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAndClose,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Salvar'),
      ),
    );
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  final FitnessService service;

  const _ExercisePickerSheet({required this.service});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _group = 'Todos';
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createExercise() async {
    final exercise = await showDialog<FitnessExercise>(
      context: context,
      builder: (_) => const ExerciseEditDialog(),
    );
    if (exercise == null) return;
    final id = await widget.service.upsertLibraryExercise(exercise);
    if (!mounted) return;
    Navigator.of(context).pop(exercise.copyWith(id: id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Biblioteca',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _createExercise,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Novo'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<FitnessExercise>>(
                  stream: widget.service.watchLibraryExercises(),
                  builder: (context, snap) {
                    final query = _search.text.trim().toLowerCase();
                    final items = (snap.data ?? const <FitnessExercise>[])
                        .where((exercise) {
                          if (_favoritesOnly && !exercise.favorite) {
                            return false;
                          }
                          if (_group != 'Todos' &&
                              exercise.muscleGroup != _group) {
                            return false;
                          }
                          if (query.isEmpty) return true;
                          return exercise.name.toLowerCase().contains(query);
                        })
                        .toList();

                    if (items.isEmpty) {
                      return const Center(child: Text('Nenhum exercício.'));
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final exercise = items[index];
                        return ListTile(
                          leading: Icon(
                            exercise.favorite
                                ? Icons.star_rounded
                                : Icons.fitness_center,
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            '${exercise.muscleGroup} • usado ${exercise.useCount}x',
                          ),
                          onTap: () => Navigator.of(context).pop(exercise),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutExerciseEditDialog extends StatefulWidget {
  final FitnessExercise? exercise;
  final WorkoutExercise? item;

  const WorkoutExerciseEditDialog({super.key, this.exercise, this.item});

  @override
  State<WorkoutExerciseEditDialog> createState() =>
      _WorkoutExerciseEditDialogState();
}

class _WorkoutExerciseEditDialogState extends State<WorkoutExerciseEditDialog> {
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _load;
  late final TextEditingController _rest;
  late final TextEditingController _execution;
  late final TextEditingController _secondsPerRep;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _sets = TextEditingController(text: (item?.sets ?? 4).toString());
    _reps = TextEditingController(text: (item?.reps ?? 10).toString());
    _load = TextEditingController(text: formatKg(item?.loadKg ?? 0));
    _rest = TextEditingController(text: (item?.restSeconds ?? 90).toString());
    _execution = TextEditingController(
      text: (item?.executionSeconds ?? 40).toString(),
    );
    _secondsPerRep = TextEditingController(
      text: (item?.secondsPerRep ?? 4).toString(),
    );
    _notes = TextEditingController(
      text: item?.notes ?? widget.exercise?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _load.dispose();
    _rest.dispose();
    _execution.dispose();
    _secondsPerRep.dispose();
    _notes.dispose();
    super.dispose();
  }

  int _intValue(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  double _doubleValue(TextEditingController controller, double fallback) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ??
        fallback;
  }

  void _syncExecutionFromReps() {
    final reps = _intValue(_reps, 10);
    final seconds = _intValue(_secondsPerRep, 4);
    _execution.text = (reps * seconds).toString();
  }

  void _save() {
    final exercise = widget.exercise;
    final item = widget.item;
    final sourceName = item?.exerciseName ?? exercise?.name ?? '';
    if (sourceName.isEmpty) return;

    final notes = _notes.text.trim();
    Navigator.of(context).pop(
      WorkoutExercise(
        id: item?.id,
        exerciseId: item?.exerciseId ?? exercise?.id ?? '',
        exerciseName: sourceName,
        muscleGroup: item?.muscleGroup ?? exercise?.muscleGroup ?? 'Peito',
        notes: notes.isEmpty ? null : notes,
        imageUrl: item?.imageUrl ?? exercise?.imageUrl,
        videoUrl: item?.videoUrl ?? exercise?.videoUrl,
        youtubeUrl: item?.youtubeUrl ?? exercise?.youtubeUrl,
        sets: _intValue(_sets, 4).clamp(1, 99),
        reps: _intValue(_reps, 10).clamp(1, 999),
        loadKg: _doubleValue(_load, 0),
        restSeconds: _intValue(_rest, 90).clamp(0, 3600),
        executionSeconds: _intValue(_execution, 40).clamp(0, 3600),
        secondsPerRep: _intValue(_secondsPerRep, 4).clamp(0, 120),
        order: item?.order ?? DateTime.now().millisecondsSinceEpoch,
        createdAt: item?.createdAt,
        updatedAt: item?.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.item?.exerciseName ?? widget.exercise?.name ?? 'Exercício';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _numberField(_sets, 'Séries')),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_reps, 'Repetições')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numberField(_load, 'Carga kg')),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_rest, 'Descanso s')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numberField(_execution, 'Execução s')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _secondsPerRep,
                      decoration: InputDecoration(
                        labelText: 'Seg/rep',
                        suffixIcon: IconButton(
                          tooltip: 'Calcular execução',
                          onPressed: _syncExecutionFromReps,
                          icon: const Icon(Icons.calculate_outlined),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}
