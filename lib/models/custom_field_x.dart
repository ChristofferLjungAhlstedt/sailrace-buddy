import 'dart:convert';
import '../database/database.dart';

extension CustomFieldTypeX on CustomFieldType {
  String get label {
    switch (this) {
      case CustomFieldType.intType:
        return 'Whole number';
      case CustomFieldType.floatType:
        return 'Decimal number';
      case CustomFieldType.enumType:
        return 'Choice list';
      case CustomFieldType.textType:
        return 'Free text (note)';
    }
  }

  bool get isNumeric =>
      this == CustomFieldType.intType || this == CustomFieldType.floatType;
}

extension CustomFieldDefinitionX on CustomFieldDefinition {
  /// The choices for a choice-list field (stored as a JSON list).
  List<String> get options {
    final raw = enumOptions;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }
}