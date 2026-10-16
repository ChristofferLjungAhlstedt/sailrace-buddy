import 'package:flutter/material.dart';

/// A compact +/- stepper for trim values. Tap the number to type an
/// exact value instead of stepping.
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onCleared,
    this.step = 1,
    this.decimals = 0,
    this.suffix = '',
    this.trimZeros = false,
  });

  final String label;
  final double? value;
  final ValueChanged<double> onChanged;

  /// If provided, the type-in dialog gets a Clear button that calls this.
  final VoidCallback? onCleared;

  final double step;
  final int decimals;
  final String suffix;

  /// Show 2.5 instead of 2.50, and 3 instead of 3.00.
  final bool trimZeros;

  static const _clearToken = '__clear__';

  String get _display {
    if (value == null) return '--';
    var text = value!.toStringAsFixed(decimals);
    if (trimZeros && text.contains('.')) {
      text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return '$text$suffix';
  }

  String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _editValue(BuildContext context) async {
    final controller =
        TextEditingController(text: value == null ? '' : _plain(value!));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (onCleared != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _clearToken),
              child: const Text('Clear'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result == _clearToken) {
      onCleared?.call();
      return;
    }
    final parsed = double.tryParse(result.trim().replaceAll(',', '.'));
    if (parsed != null) onChanged(parsed);
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _editValue(context),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(_display,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ),
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
