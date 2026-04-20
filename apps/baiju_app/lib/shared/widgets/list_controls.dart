import 'package:flutter/material.dart';

class ModuleSearchField extends StatelessWidget {
  const ModuleSearchField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class SelectionChipBar<T> extends StatelessWidget {
  const SelectionChipBar({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return ChoiceChip(
          label: Text(labelBuilder(value)),
          selected: value == selected,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }
}
