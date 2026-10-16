import '../database/database.dart';

extension ErrorTagX on ErrorTag {
  String get label {
    switch (this) {
      case ErrorTag.falseStart:
        return 'False start';
      case ErrorTag.penalty:
        return 'Penalty';
      case ErrorTag.collision:
        return 'Collision';
      case ErrorTag.missedLayline:
        return 'Missed layline';
      case ErrorTag.other:
        return 'Other';
    }
  }
}

/// "falseStart,penalty" -> "False start, Penalty"
String errorTagsLabel(String csv) {
  if (csv.isEmpty) return '';
  final names = csv.split(',');
  return ErrorTag.values
      .where((t) => names.contains(t.name))
      .map((t) => t.label)
      .join(', ');
}