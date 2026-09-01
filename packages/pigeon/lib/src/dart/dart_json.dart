// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Fork-specific extension (not part of upstream Pigeon): emits idiomatic
// `toJson`/`fromJson` (and their string variants) directly on the generated
// Dart data classes, gated by `DartOptions.generateJson`. Kept in a separate
// file so the touch on `dart_generator.dart` stays minimal and easy to rebase.
//
// JSON shape matches the shared contract used by the Kotlin/Swift generators:
//  * map keys are the Dart field names verbatim;
//  * enums are encoded by their Dart constant name (`.name` / `.values.byName`);
//  * `Map` keys are always stringified; nullable keys are always present (null);
//  * `Uint8List` is base64; the numeric typed lists (`Int32List`/`Int64List`/
//    `Float64List`) are JSON number arrays; sealed hierarchies carry a `"type"`
//    discriminator equal to the Pigeon class name.

import '../ast.dart';
import '../generator_tools.dart';

/// Writes the JSON (de)serialization members for [classDefinition] into the
/// currently open class body.
///
/// For a concrete class: `toJson`, `toJsonString` (unless it is a subclass, in
/// which case `toJsonString` is inherited from the sealed base), and factory
/// `fromJson`/`fromJsonString`. For a sealed base: an abstract `toJson`, a
/// concrete `toJsonString`, and factory `fromJson`/`fromJsonString` that
/// dispatch on the `"type"` discriminator.
void writeDartClassJson(Root root, Indent indent, Class classDefinition) {
  if (classDefinition.isSealed) {
    _writeSealedBaseJson(root, indent, classDefinition);
  } else {
    _writeConcreteClassJson(
      indent,
      classDefinition,
      isSubclass: classDefinition.superClassName != null,
    );
  }
}

void _writeConcreteClassJson(
  Indent indent,
  Class classDefinition, {
  required bool isSubclass,
}) {
  final String name = classDefinition.name;
  final List<NamedType> fields = getFieldsInSerializationOrder(
    classDefinition,
  ).toList();

  indent.newln();
  if (isSubclass) {
    indent.writeln('@override');
  }
  indent.write('Map<String, Object?> toJson() => ');
  indent.addScoped('<String, Object?>{', '};', () {
    if (isSubclass) {
      indent.writeln("'type': '$name',");
    }
    for (final NamedType field in fields) {
      indent.writeln("'${field.name}': ${_toJson(field.name, field.type, 0)},");
    }
  });

  // Subclasses inherit `toJsonString` from the sealed base.
  if (!isSubclass) {
    indent.newln();
    indent.writeln('String toJsonString() => jsonEncode(toJson());');
  }

  indent.newln();
  indent.write('factory $name.fromJson(Map<String, Object?> json) => ');
  indent.addScoped('$name(', ');', () {
    for (final NamedType field in fields) {
      indent.writeln(
        "${field.name}: ${_fromJson("json['${field.name}']", field.type, 0)},",
      );
    }
  });

  indent.newln();
  indent.writeln(
    'factory $name.fromJsonString(String json) => '
    '$name.fromJson(jsonDecode(json) as Map<String, Object?>);',
  );
}

void _writeSealedBaseJson(Root root, Indent indent, Class base) {
  final String name = base.name;
  final List<Class> subclasses = root.classes
      .where((Class c) => c.superClassName == name)
      .toList();

  indent.newln();
  // Abstract; each concrete subtype overrides it, so `base.toJson()` dispatches
  // dynamically without an explicit switch.
  indent.writeln('Map<String, Object?> toJson();');
  indent.newln();
  indent.writeln('String toJsonString() => jsonEncode(toJson());');

  // A `static` method (not a `factory`) so the sealed base keeps its implicit
  // generative constructor — subclasses' `extends` rely on it. The call site
  // (`Base.fromJson(...)`) is identical either way.
  indent.newln();
  indent.write('static $name fromJson(Map<String, Object?> json) => ');
  indent.addScoped("switch (json['type']) {", '};', () {
    for (final Class sub in subclasses) {
      indent.writeln("'${sub.name}' => ${sub.name}.fromJson(json),");
    }
    indent.writeln(
      r"_ => throw ArgumentError('Unknown "
      '$name'
      r" type: ${json['type']}'),",
    );
  });

  indent.newln();
  indent.writeln(
    'static $name fromJsonString(String json) => '
    '$name.fromJson(jsonDecode(json) as Map<String, Object?>);',
  );
}

/// A Dart expression that converts [expr] (of [type]) into a JSON-safe value.
///
/// [depth] names nested closure parameters (`e0`/`k0`/`v0`, `e1`/…) so nested
/// collections never shadow an outer parameter.
String _toJson(String expr, TypeDeclaration type, int depth) {
  if (type.isEnum) {
    return type.isNullable ? '$expr?.name' : '$expr.name';
  }
  if (type.isClass) {
    return type.isNullable ? '$expr?.toJson()' : '$expr.toJson()';
  }
  switch (type.baseName) {
    case 'Uint8List':
      // Pigeon fields are mutable (non-promotable), so force non-null with `!`
      // rather than relying on flow promotion inside the conditional.
      return type.isNullable
          ? '($expr == null ? null : base64Encode($expr!))'
          : 'base64Encode($expr)';
    case 'Int32List':
    case 'Int64List':
    case 'Float64List':
      // These implement `List<num>`, so they are already JSON-safe.
      return expr;
    case 'List':
      final TypeDeclaration element = type.typeArguments.first;
      if (_isPassthrough(element)) {
        return expr;
      }
      final String e = 'e$depth';
      final String q = type.isNullable ? '?' : '';
      return '$expr$q.map(($e) => ${_toJson(e, element, depth + 1)}).toList()';
    case 'Map':
      final TypeDeclaration key = type.typeArguments[0];
      final TypeDeclaration value = type.typeArguments[1];
      final String k = 'k$depth';
      final String v = 'v$depth';
      final String q = type.isNullable ? '?' : '';
      return '$expr$q.map(($k, $v) => '
          'MapEntry(${_toJsonKey(k, key)}, ${_toJson(v, value, depth + 1)}))';
    default:
      // int/double/String/bool/Object are already JSON-safe.
      return expr;
  }
}

/// A Dart expression that stringifies a map key [expr] of type [key].
String _toJsonKey(String expr, TypeDeclaration key) {
  if (key.isEnum) {
    return '$expr.name';
  }
  if (key.baseName == 'String') {
    return expr;
  }
  return '$expr.toString()';
}

/// A Dart expression that parses [access] (an `Object?` read from the map) into
/// a value of [type].
String _fromJson(String access, TypeDeclaration type, int depth) {
  if (type.isEnum) {
    final String call = '${type.baseName}.values.byName($access as String)';
    return type.isNullable ? '($access == null ? null : $call)' : call;
  }
  if (type.isClass) {
    final String call =
        '${type.baseName}.fromJson($access as Map<String, Object?>)';
    return type.isNullable ? '($access == null ? null : $call)' : call;
  }
  switch (type.baseName) {
    case 'String':
      return type.isNullable ? '$access as String?' : '$access as String';
    case 'int':
      return type.isNullable ? '$access as int?' : '$access as int';
    case 'double':
      return type.isNullable ? '$access as double?' : '$access as double';
    case 'bool':
      return type.isNullable ? '$access as bool?' : '$access as bool';
    case 'Uint8List':
      return type.isNullable
          ? '($access == null ? null : base64Decode($access as String))'
          : 'base64Decode($access as String)';
    case 'Int32List':
      return _typedListFromJson(access, 'Int32List', 'int', type.isNullable);
    case 'Int64List':
      return _typedListFromJson(access, 'Int64List', 'int', type.isNullable);
    case 'Float64List':
      return _typedListFromJson(access, 'Float64List', 'double', type.isNullable);
    case 'List':
      final TypeDeclaration element = type.typeArguments.first;
      final String e = 'e$depth';
      final String body = '($e) => ${_fromJson(e, element, depth + 1)}';
      return type.isNullable
          ? '($access as List<Object?>?)?.map($body).toList()'
          : '($access as List<Object?>).map($body).toList()';
    case 'Map':
      final TypeDeclaration key = type.typeArguments[0];
      final TypeDeclaration value = type.typeArguments[1];
      final String k = 'k$depth';
      final String v = 'v$depth';
      final String body = '($k, $v) => MapEntry('
          '${_fromJsonKey(k, key)}, ${_fromJson(v, value, depth + 1)})';
      return type.isNullable
          ? '($access as Map<Object?, Object?>?)?.map($body)'
          : '($access as Map<Object?, Object?>).map($body)';
    default:
      // Object / dynamic: pass through untouched.
      return access;
  }
}

/// Reconstructs a numeric typed list ([listType], e.g. `Int32List`) whose
/// elements are [elementType] (`int`/`double`) from a JSON array [access].
String _typedListFromJson(
  String access,
  String listType,
  String elementType,
  bool isNullable,
) {
  final String call =
      '$listType.fromList(($access as List<Object?>).cast<$elementType>())';
  return isNullable ? '($access == null ? null : $call)' : call;
}

/// A Dart expression that parses a stringified map key [expr] into [key].
String _fromJsonKey(String expr, TypeDeclaration key) {
  if (key.isEnum) {
    return '${key.baseName}.values.byName($expr as String)';
  }
  switch (key.baseName) {
    case 'String':
      return '$expr as String';
    case 'int':
      return 'int.parse($expr as String)';
    case 'double':
      return 'double.parse($expr as String)';
    default:
      return '$expr as String';
  }
}

/// Whether [type] needs no conversion inside a `List` (already JSON-safe).
bool _isPassthrough(TypeDeclaration type) =>
    !type.isEnum &&
    !type.isClass &&
    const <String>{
      'int',
      'double',
      'String',
      'bool',
      'Object',
    }.contains(type.baseName);
