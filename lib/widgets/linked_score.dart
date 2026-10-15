import 'package:flutter/material.dart';

/// Encapsulates the race-score / boat-feel-score linking rule:
///  - Setting [raceScore] also sets [boatFeelScore] while [linked] is true.
///  - Editing boat feel directly sets [linked] to false; from then on the
///    two scores are independent until the caller explicitly re-links.
class LinkedScore extends StatelessWidget {
  const LinkedScore({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.labelSmall,
              children: [
                TextSpan(text: label, style: TextStyle(color: muted)),
                TextSpan(text: '  $hint', style: TextStyle(color: muted)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final filled = value != null && i < value!;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? accent : muted,
                  size: 24,
                ),
                onPressed: () => onChanged(i + 1),
              );
            }),
          ),
        ],
      ),
    );
  }
}
