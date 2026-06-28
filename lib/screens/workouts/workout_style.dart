import 'package:flutter/material.dart';

const workoutColors = <int>[
  0xFFF47AA7,
  0xFF6C8DFF,
  0xFF15B8A6,
  0xFFFFA24C,
  0xFF9B6DFF,
  0xFF2BB673,
];

IconData workoutIcon(String name) {
  return switch (name) {
    'strength' => Icons.fitness_center,
    'cardio' => Icons.directions_run_rounded,
    'body' => Icons.accessibility_new_rounded,
    'bolt' => Icons.bolt_rounded,
    'favorite' => Icons.favorite_rounded,
    _ => Icons.fitness_center,
  };
}

const workoutIconNames = <String>[
  'fitness',
  'strength',
  'cardio',
  'body',
  'bolt',
  'favorite',
];

String formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = remaining.toString().padLeft(2, '0');
  return '$mm:$ss';
}

String formatKg(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
