import 'package:flutter/material.dart';
import '../data/boat_classes.dart';
import 'class_logo.dart';

const _otherValue = '__other__';

/// Class dropdown with an "Other..." option that reveals a free-text field.
/// Reports the resolved class name (empty string if nothing chosen yet).
class BoatClassPicker extends StatefulWidget {
  const BoatClassPicker({super.key, this.initialClass, required this.onChanged});

  final String? initialClass;
  final ValueChanged<String> onChanged;

  @override
  State<BoatClassPicker> createState() => _BoatClassPickerState();
}

class _BoatClassPickerState extends State<BoatClassPicker> {
  String? _selected;
  final _other = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialClass;
    if (initial != null && initial.isNotEmpty) {
      final known = findBoatClass(initial);
      if (known != null) {
        _selected = known.name;
      } else {
        _selected = _otherValue;
        _other.text = initial;
      }
    }
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _emit() {
    final name =
        _selected == _otherValue ? _other.text.trim() : (_selected ?? '');
    widget.onChanged(name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selected,
          decoration: const InputDecoration(labelText: 'Boat class'),
          items: [
            for (final c in boatClasses)
              DropdownMenuItem(
                value: c.name,
                child: Row(
                  children: [
                    if (classHasLogo(c.name)) ...[
                      ClassLogo(
                          className: c.name, size: 24, showFallback: false),
                      const SizedBox(width: 8),
                    ],
                    Text(c.name),
                  ],
                ),
              ),
            const DropdownMenuItem(value: _otherValue, child: Text('Other...')),
          ],
          onChanged: (v) {
            setState(() => _selected = v);
            _emit();
          },
        ),
        if (_selected == _otherValue)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: _other,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Class name'),
              onChanged: (_) => _emit(),
            ),
          ),
      ],
    );
  }
}