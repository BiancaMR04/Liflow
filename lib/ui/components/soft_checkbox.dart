import 'package:flutter/material.dart';

class SoftCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SoftCheckbox({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
    );
  }
}
