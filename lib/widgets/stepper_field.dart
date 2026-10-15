import 'package:flutter/material.dart';

/// A compact +/- stepper for trim values. Used instead of raw text entry
/// everywhere on the race entry screen, since tapping is faster than
/// typing when you're standing in a cockpit between races.
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.decimals = 0,
    this.suffix = '',
  });

  final String label;
  final double? value;
  final ValueChanged<double> onChanged;
  final double step;
  final int decimals;
  final String suffix;

  String get _display {
    if (value == null) return '--';
    final v = value!;
    final text = decimals == 0
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(decimals);
    return suffix.isEmpty ? text : '$text$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onChanged((value ?? 0) - step),
              ),
              Text(_display, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onChanged((value ?? 0) + step),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
