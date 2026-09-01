// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Fork-specific extension (not part of upstream Pigeon): emits a `copyWith`
// method on the generated Dart data classes, gated by `DartOptions.copyWith`.
// Kept in a separate file so the touch on `dart_generator.dart` stays minimal
// and easy to rebase.
//
// Pigeon's generated Dart fields are mutable, so `copyWith` is ergonomic sugar
// rather than a necessity. A non-nullable field takes a nullable parameter and
// falls back to the current value (`field ?? this.field`). A nullable field
// uses a file-level sentinel default (`_pigeonCopyWithSentinel`) so all three
// cases are expressible: omit the argument to keep the current value, pass
// `null` to clear it, or pass a value to set it.

import '../ast.dart';
import '../generator_tools.dart';
import 'dart_generator.dart' show addGenericTypesNullable;

/// The name of the file-level sentinel that distinguishes "argument omitted"
/// from "explicitly passed `null`" for a nullable field in `copyWith`.
const String _sentinel = '_pigeonCopyWithSentinel';

/// Whether any class in [root] would generate a `copyWith` that references the
/// file-level sentinel — i.e. a concrete class with at least one nullable
/// field.
///
/// Used so the sentinel declaration is emitted only when something references
/// it, keeping the output free of an unused top-level element.
bool rootNeedsCopyWithSentinel(Root root) => root.classes.any(
  (Class c) => !c.isSealed && c.fields.any((NamedType f) => f.type.isNullable),
);

/// Writes the file-level sentinel declaration used by nullable `copyWith`
/// parameters.
void writeCopyWithSentinel(Indent indent) {
  indent.writeln('const Object $_sentinel = Object();');
}

/// Writes a `copyWith` method for [classDefinition] into the currently open
/// class body.
///
/// Only meaningful for a concrete class with fields; sealed bases and empty
/// classes are filtered out by the caller.
void writeDartClassCopyWith(Indent indent, Class classDefinition) {
  final String name = classDefinition.name;
  final List<NamedType> fields = getFieldsInSerializationOrder(
    classDefinition,
  ).toList();

  indent.newln();
  indent.write('$name copyWith(');
  indent.addScoped('{', '}) {', () {
    for (final NamedType field in fields) {
      if (field.type.isNullable) {
        // `Object?` (rather than the field's own nullable type) so the sentinel
        // default is assignable and stays distinguishable from a real `null`.
        indent.writeln('Object? ${field.name} = $_sentinel,');
      } else {
        indent.writeln(
          '${addGenericTypesNullable(field.type)}? ${field.name},',
        );
      }
    }
  });
  indent.nest(1, () {
    indent.write('return $name(');
    indent.addScoped('', ');', () {
      for (final NamedType field in fields) {
        indent.writeln('${field.name}: ${_copyValue(field)},');
      }
    });
  });
  indent.writeln('}');
}

/// The value expression for [field] inside the reconstructing constructor call.
String _copyValue(NamedType field) {
  final String name = field.name;
  if (field.type.isNullable) {
    final String type = addGenericTypesNullable(field.type);
    return 'identical($name, $_sentinel) ? this.$name : $name as $type';
  }
  return '$name ?? this.$name';
}
