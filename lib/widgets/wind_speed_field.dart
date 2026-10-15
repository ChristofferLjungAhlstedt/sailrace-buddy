import 'package:flutter/material.dart';

/// Quick single-value entry by default (wind_speed_kt), with an expandable
/// min/max range. The moment the user edits min or max away from the
/// prefilled single value, the fields unlink and wind_speed_kt becomes
/// derived (midpoint) rather than directly editable - mirrors the
/// race-score/boat-feel linking pattern used elsewhere in the form.
class WindSpeedField extends StatefulWidget {
  const WindSpeedField({
    super.key,
    required this.windSpeedKt,
    required this.minKt,
    required this.maxKt,
    required this.linked,
    required this.onChanged,
    this.useMs = false,
  });

  final double? windSpeedKt;
  final double? minKt;
  final double? maxKt;
  final bool linked;
  final bool useMs;
  final void Function({
    double? windSpeedKt,
    double? minKt,
    double? maxKt,
    required bool linked,
  }) onChanged;

  static double ktToMs(double kt) => kt * 0.514444;
  static double msToKt(double ms) => ms / 0.514444;

  @override
  State<WindSpeedField> createState() => _WindSpeedFieldState();
}

class _WindSpeedFieldState extends State<WindSpeedField> {
  bool _expanded = false;

  String _fmt(double? kt) {
    if (kt == null) return '--';
    final v = widget.useMs ? WindSpeedField.ktToMs(kt) : kt;
    final unit = widget.useMs ? 'm/s' : 'kt';
    return '${v.toStringAsFixed(1)} $unit';
  }

  double _step() => widget.useMs ? WindSpeedField.msToKt(0.5) : 1.0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wind speed',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    if (!_expanded)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final next = (widget.windSpeedKt ?? 0) - _step();
                              widget.onChanged(
                                  windSpeedKt: next, linked: true);
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(_fmt(widget.windSpeedKt),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final next = (widget.windSpeedKt ?? 0) + _step();
                              widget.onChanged(
                                  windSpeedKt: next, linked: true);
                            },
                          ),
                        ],
                      )
                    else
                      Text(
                        '${_fmt(widget.minKt)} - ${_fmt(widget.maxKt)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down),
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                  if (_expanded &&
                      widget.minKt == null &&
                      widget.maxKt == null) {
                    // Prefill min/max from the quick-entry value.
                    widget.onChanged(
                      windSpeedKt: widget.windSpeedKt,
                      minKt: widget.windSpeedKt,
                      maxKt: widget.windSpeedKt,
                      linked: true,
                    );
                  }
                },
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniStepper(
                    label: 'Min',
                    display: _fmt(widget.minKt),
                    onMinus: () => widget.onChanged(
                      minKt: (widget.minKt ?? 0) - _step(),
                      maxKt: widget.maxKt,
                      linked: false,
                    ),
                    onPlus: () => widget.onChanged(
                      minKt: (widget.minKt ?? 0) + _step(),
                      maxKt: widget.maxKt,
                      linked: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStepper(
                    label: 'Max',
                    display: _fmt(widget.maxKt),
                    onMinus: () => widget.onChanged(
                      minKt: widget.minKt,
                      maxKt: (widget.maxKt ?? 0) - _step(),
                      linked: false,
                    ),
                    onPlus: () => widget.onChanged(
                      minKt: widget.minKt,
                      maxKt: (widget.maxKt ?? 0) + _step(),
                      linked: false,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.label,
    required this.display,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String display;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onMinus,
            ),
            Text(display, style: Theme.of(context).textTheme.bodyMedium),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onPlus,
            ),
          ],
        ),
      ],
    );
  }
}
