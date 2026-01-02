import 'package:flutter/material.dart';

class RadioOption<T> {
  final String label;
  final T value;
  const RadioOption(this.label, this.value);
}

class AppRadioGroup<T> extends StatelessWidget {
  final List<RadioOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const AppRadioGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((option) {
        return RadioListTile<T>(
          title: Text(option.label),
          value: option.value,
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        );
      }).toList(),
    );
  }
}
