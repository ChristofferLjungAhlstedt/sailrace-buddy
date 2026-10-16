import 'package:flutter/material.dart';

/// Quick single-value entry by default (wind_speed_kt), with an expandable
/// min/max range.
///
/// Rules:
///  - Simple +/- changes the single value. If a range exists, the whole
///    range shifts with it, so nothing is lost.
///  - Steps snap to round numbers in the user's unit (1 kt or 0.5 m/s).
///    A converted value like 1.7 m/s steps to 1.5 or 2.0, not 2.2.
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

  bool get _hasRange => widget.minKt != null && widget.maxKt != null;

  double _nonNegative(double v) => v < 0 ? 0 : v;

  String _fmt(double? kt) {
    if (kt == null) return '--';
    if (widget.useMs) {
      return '${WindSpeedField.ktToMs(kt).toStringAsFixed(1)} m/s';
    }
    // Whole knots when it is (nearly) whole, otherwise one decimal.
    final whole = (kt - kt.roundToDouble()).abs() < 0.05;
    return '${kt.toStringAsFixed(whole ? 0 : 1)} kt';
  }

  /// The next (direction = 1) or previous (direction = -1) value on the
  /// step grid, in the user's own unit (1 kt or 0.5 m/s). A value that
  /// sits between grid points, like 3.1 m/s from a race logged in knots,
  /// snaps to the nearest round number on the first tap.
  double _stepFrom(double? currentKt, int direction) {
    final current = currentKt ?? 0;
    final size = widget.useMs ? 0.5 : 1.0;
    final shown = widget.useMs ? WindSpeedField.ktToMs(current) : current;
    final q = shown / size;
    final nearest = q.roundToDouble();

    final double target;
    if ((q - nearest).abs() < 0.02) {
      target = nearest + direction; // already on the grid: one full step
    } else {
      target = direction > 0 ? q.ceilToDouble() : q.floorToDouble();
    }

    final next = _nonNegative(target * size);
    return widget.useMs ? WindSpeedField.msToKt(next) : next;
  }

  /// Simple +/- on the single value. Shifts the range too if there is one.
  void _nudge(int direction) {
    final base = widget.windSpeedKt ?? 0;
    final next = _stepFrom(widget.windSpeedKt, direction);
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
                            onPressed: () => _nudge(-1),
                          ),
                          const SizedBox(width: 8),
                          Text(_fmt(widget.windSpeedKt),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _nudge(1),
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
                        min: _stepFrom(widget.minKt ?? widget.windSpeedKt, -1)),
                    onPlus: () => _setRange(
                        min: _stepFrom(widget.minKt ?? widget.windSpeedKt, 1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStepper(
                    label: 'Max',
                    display: _fmt(widget.maxKt),
                    onMinus: () => _setRange(
                        max: _stepFrom(widget.maxKt ?? widget.windSpeedKt, -1)),
                    onPlus: () => _setRange(
                        max: _stepFrom(widget.maxKt ?? widget.windSpeedKt, 1)),
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