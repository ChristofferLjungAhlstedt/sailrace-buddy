import 'package:flutter/material.dart';

/// Quick single-value entry by default (wind_speed_kt), with an expandable
/// min/max range.
///
/// Rules:
///  - Simple +/- changes the single value. If a range exists, the whole
///    range shifts with it, so nothing is lost.
///  - Editing min or max unlinks the range from the single value, and the
///    single value becomes the midpoint of min and max.
///  - Min can never exceed max (moving one pushes the other along).
///  - The widget opens expanded if the race already has a real range.
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
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    final min = widget.minKt;
    final max = widget.maxKt;
    _expanded = min != null && max != null && min != max;
  }

  double get _step => widget.useMs ? WindSpeedField.msToKt(0.5) : 1.0;

  bool get _hasRange => widget.minKt != null && widget.maxKt != null;

  double _nonNegative(double v) => v < 0 ? 0 : v;

  String _fmt(double? kt) {
    if (kt == null) return '--';
    final v = widget.useMs ? WindSpeedField.ktToMs(kt) : kt;
    final unit = widget.useMs ? 'm/s' : 'kt';
    return '${v.toStringAsFixed(1)} $unit';
  }

  /// Simple +/- on the single value. Shifts the range too if there is one.
  void _nudge(double delta) {
    final base = widget.windSpeedKt ?? 0;
    final next = _nonNegative(base + delta);
    final applied = next - base;
    widget.onChanged(
      windSpeedKt: next,
      minKt: _hasRange ? _nonNegative(widget.minKt! + applied) : null,
      maxKt: _hasRange ? _nonNegative(widget.maxKt! + applied) : null,
      linked: widget.linked,
    );
  }

  /// Edit min and/or max. Always unlinks and keeps the single value as
  /// the midpoint.
  void _setRange({double? min, double? max}) {
    final fallback = widget.windSpeedKt ?? 0;
    var newMin = _nonNegative(min ?? widget.minKt ?? fallback);
    var newMax = _nonNegative(max ?? widget.maxKt ?? fallback);

    if (min != null && newMin > newMax) newMax = newMin;
    if (max != null && newMax < newMin) newMin = newMax;

    widget.onChanged(
      windSpeedKt: (newMin + newMax) / 2,
      minKt: newMin,
      maxKt: newMax,
      linked: false,
    );
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded && !_hasRange) {
      // Prefill min/max from the quick-entry value, still linked.
      widget.onChanged(
        windSpeedKt: widget.windSpeedKt,
        minKt: widget.windSpeedKt,
        maxKt: widget.windSpeedKt,
        linked: true,
      );
    }
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
                            onPressed: () => _nudge(-_step),
                          ),
                          const SizedBox(width: 8),
                          Text(_fmt(widget.windSpeedKt),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _nudge(_step),
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
                onPressed: _toggleExpanded,
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
                    onMinus: () => _setRange(
                        min: (widget.minKt ?? widget.windSpeedKt ?? 0) - _step),
                    onPlus: () => _setRange(
                        min: (widget.minKt ?? widget.windSpeedKt ?? 0) + _step),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStepper(
                    label: 'Max',
                    display: _fmt(widget.maxKt),
                    onMinus: () => _setRange(
                        max: (widget.maxKt ?? widget.windSpeedKt ?? 0) - _step),
                    onPlus: () => _setRange(
                        max: (widget.maxKt ?? widget.windSpeedKt ?? 0) + _step),
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
      mainAxisSize: MainAxisSize.min,
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
            const SizedBox(width: 6),
            Text(display, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 6),
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