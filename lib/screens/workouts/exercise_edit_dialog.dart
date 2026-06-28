import 'package:flutter/material.dart';

import '../../models/fitness_exercise.dart';

class ExerciseEditDialog extends StatefulWidget {
  final FitnessExercise? exercise;

  const ExerciseEditDialog({super.key, this.exercise});

  @override
  State<ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<ExerciseEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _imageUrl;
  late final TextEditingController _videoUrl;
  late final TextEditingController _youtubeUrl;

  late String _muscleGroup;
  late bool _favorite;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _name = TextEditingController(text: exercise?.name ?? '');
    _notes = TextEditingController(text: exercise?.notes ?? '');
    _imageUrl = TextEditingController(text: exercise?.imageUrl ?? '');
    _videoUrl = TextEditingController(text: exercise?.videoUrl ?? '');
    _youtubeUrl = TextEditingController(text: exercise?.youtubeUrl ?? '');
    _muscleGroup = MuscleGroups.all.contains(exercise?.muscleGroup)
        ? exercise!.muscleGroup
        : MuscleGroups.all.first;
    _favorite = exercise?.favorite ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _imageUrl.dispose();
    _videoUrl.dispose();
    _youtubeUrl.dispose();
    super.dispose();
  }

  String? _trimOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final existing = widget.exercise;
    Navigator.of(context).pop(
      FitnessExercise(
        id: existing?.id,
        name: name,
        muscleGroup: _muscleGroup,
        notes: _trimOrNull(_notes),
        imageUrl: _trimOrNull(_imageUrl),
        videoUrl: _trimOrNull(_videoUrl),
        youtubeUrl: _trimOrNull(_youtubeUrl),
        favorite: _favorite,
        useCount: existing?.useCount ?? 0,
        lastUsedAt: existing?.lastUsedAt,
        createdAt: existing?.createdAt,
        updatedAt: existing?.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.exercise == null ? 'Novo exercício' : 'Editar exercício',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _muscleGroup,
                decoration: const InputDecoration(labelText: 'Grupo muscular'),
                items: MuscleGroups.all
                    .map(
                      (group) =>
                          DropdownMenuItem(value: group, child: Text(group)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _muscleGroup = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Observações'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrl,
                decoration: const InputDecoration(labelText: 'URL da imagem'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _videoUrl,
                decoration: const InputDecoration(labelText: 'URL do vídeo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _youtubeUrl,
                decoration: const InputDecoration(labelText: 'Link do YouTube'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Favorito'),
                subtitle: Text(
                  'Aparece primeiro na biblioteca',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value),
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
}
