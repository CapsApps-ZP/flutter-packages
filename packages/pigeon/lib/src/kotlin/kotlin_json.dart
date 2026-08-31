// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Fork-specific extension (not part of upstream Pigeon): emits `toJson`/
// `fromJson` (and their string variants) for generated Kotlin data classes,
// gated by `KotlinOptions.generateJson`. Kept in a separate file so the touch
// on `kotlin_generator.dart` stays minimal and easy to rebase.
//
// JSON shape matches the shared contract:
//  * map keys are the Dart field names verbatim;
//  * enums are encoded by their Dart constant name (Kotlin uppercases them, so
//    an explicit mapping is generated);
//  * `Map` keys are always stringified; nullable keys are always present (null);
//  * `Uint8List` is base64; sealed hierarchies carry a `"type"` discriminator
//    equal to the Pigeon class name.

import '../ast.dart';
import '../generator_tools.dart';

/// The base64 flags used for `Uint8List` fields (no line wrapping).
const String _base64 = 'android.util.Base64';

/// Writes the JSON (de)serialization section for [root] to [indent].
///
/// Emits, in order: shared encode/decode helpers, per-enum name mappings, and
/// per-class `toJson`/`toJsonString` extensions plus `<Class>Json` objects with
/// `fromJson`/`fromJsonString`.
void writeKotlinJson(Root root, Indent indent) {
  _writeHelpers(indent);
  for (final Enum anEnum in root.enums) {
    _writeEnumJson(indent, anEnum);
  }
  for (final Class classDefinition in root.classes) {
    if (classDefinition.isSealed) {
      _writeSealedBaseJson(root, indent, classDefinition);
    } else {
      _writeClassJson(indent, classDefinition);
    }
  }
}

void _writeHelpers(Indent indent) {
  indent.newln();
  indent.writeln('@Suppress("UNCHECKED_CAST")');
  indent.writeScoped(
    'private fun pigeonJsonEncode(value: Any?): Any = when (value) {',
    '}',
    () {
      indent.writeln('null -> JSONObject.NULL');
      indent.writeln(
        'is Map<*, *> -> JSONObject().apply { value.forEach { (k, v) -> put(k as String, pigeonJsonEncode(v)) } }',
      );
      indent.writeln(
        'is List<*> -> JSONArray().apply { value.forEach { put(pigeonJsonEncode(it)) } }',
      );
      indent.writeln('else -> value');
    },
  );
  indent.newln();
  indent.writeScoped(
    'private fun pigeonJsonDecode(value: Any?): Any? = when {',
    '}',
    () {
      indent.writeln('value == null || value == JSONObject.NULL -> null');
      indent.writeln(
        'value is JSONObject -> buildMap { value.keys().forEach { put(it, pigeonJsonDecode(value.get(it))) } }',
      );
      indent.writeln(
        'value is JSONArray -> (0 until value.length()).map { pigeonJsonDecode(value.get(it)) }',
      );
      indent.writeln('else -> value');
    },
  );
}

void _writeEnumJson(Indent indent, Enum anEnum) {
  final String name = anEnum.name;
  indent.newln();
  indent.writeScoped('fun $name.toJsonValue(): String = when (this) {', '}', () {
    for (final EnumMember member in anEnum.members) {
      indent.writeln(
        '$name.${toScreamingSnakeCase(member.name)} -> "${member.name}"',
      );
    }
  });
  indent.writeScoped(
    'fun ${_lowerFirst(name)}FromJsonValue(value: String): $name = when (value) {',
    '}',
    () {
      for (final EnumMember member in anEnum.members) {
        indent.writeln(
          '"${member.name}" -> $name.${toScreamingSnakeCase(member.name)}',
        );
      }
      indent.writeln(
        r'else -> throw IllegalArgumentException("Unknown '
        '$name'
        r': $value")',
      );
    },
  );
}

void _writeClassJson(Indent indent, Class classDefinition) {
  final String name = classDefinition.name;
  final bool isSubclass = classDefinition.superClassName != null;
  final List<NamedType> fields = getFieldsInSerializationOrder(
    classDefinition,
  ).toList();

  indent.newln();
  indent.writeScoped('fun $name.toJson(): Map<String, Any?> = mapOf(', ')', () {
    if (isSubclass) {
      indent.writeln('"type" to "$name",');
    }
    for (final NamedType field in fields) {
      indent.writeln(
        '"${field.name}" to ${_toJson(field.name, field.type, 0)},',
      );
    }
  });
  indent.writeln(
    'fun $name.toJsonString(): String = pigeonJsonEncode(toJson()).toString()',
  );

  indent.newln();
  indent.writeScoped('object ${name}Json {', '}', () {
    indent.writeScoped(
      'fun fromJson(pigeonMap: Map<String, Any?>): $name = $name(',
      ')',
      () {
        for (final NamedType field in fields) {
          indent.writeln(
            '${field.name} = ${_fromJson('pigeonMap["${field.name}"]', field.type, 0)},',
          );
        }
      },
    );
    indent.writeln(
      'fun fromJsonString(json: String): $name = '
      'fromJson(pigeonJsonDecode(JSONObject(json)) as Map<String, Any?>)',
    );
  });
}

void _writeSealedBaseJson(Root root, Indent indent, Class base) {
  final String name = base.name;
  final List<Class> subclasses = root.classes
      .where((Class c) => c.superClassName == name)
      .toList();
  if (subclasses.isEmpty) {
    return;
  }

  indent.newln();
  indent.writeScoped('fun $name.toJson(): Map<String, Any?> = when (this) {', '}', () {
    for (final Class sub in subclasses) {
      indent.writeln('is ${sub.name} -> this.toJson()');
    }
  });

  indent.newln();
  indent.writeScoped('object ${name}Json {', '}', () {
    indent.writeScoped(
      'fun fromJson(pigeonMap: Map<String, Any?>): $name = when (pigeonMap["type"]) {',
      '}',
      () {
        for (final Class sub in subclasses) {
          indent.writeln('"${sub.name}" -> ${sub.name}Json.fromJson(pigeonMap)');
        }
        indent.writeln(
          r'else -> throw IllegalArgumentException("Unknown '
          '$name'
          r' type: ${pigeonMap["type"]}")',
        );
      },
    );
    indent.writeln(
      'fun fromJsonString(json: String): $name = '
      'fromJson(pigeonJsonDecode(JSONObject(json)) as Map<String, Any?>)',
    );
  });
}

/// The lambda parameter name to use at nesting [depth]. The outermost lambda
/// keeps the idiomatic `it`; nested ones get explicit names to avoid Kotlin's
/// "name shadowed: it" warnings.
String _param(int depth) => depth == 0 ? 'it' : 'p$depth';
String _keyName(int depth) => depth == 0 ? 'k' : 'k$depth';
String _valName(int depth) => depth == 0 ? 'v' : 'v$depth';

/// A Kotlin expression that converts [expr] (of [type]) into a JSON-safe value.
///
/// [depth] is the number of enclosing generated lambdas, used to name nested
/// lambda parameters without shadowing.
String _toJson(String expr, TypeDeclaration type, int depth) {
  if (type.isEnum) {
    return type.isNullable ? '$expr?.toJsonValue()' : '$expr.toJsonValue()';
  }
  if (type.isClass) {
    return type.isNullable ? '$expr?.toJson()' : '$expr.toJson()';
  }
  switch (type.baseName) {
    case 'Uint8List':
      if (!type.isNullable) {
        return '$_base64.encodeToString($expr, $_base64.NO_WRAP)';
      }
      final String p = _param(depth);
      final String arrow = depth == 0 ? '' : '$p -> ';
      return '$expr?.let { $arrow$_base64.encodeToString($p, $_base64.NO_WRAP) }';
    case 'List':
      final TypeDeclaration element = type.typeArguments.first;
      if (_isPassthrough(element)) {
        return expr;
      }
      final String q = type.isNullable ? '?' : '';
      final String p = _param(depth);
      final String arrow = depth == 0 ? '' : '$p -> ';
      return '$expr$q.map { $arrow${_toJson(p, element, depth + 1)} }';
    case 'Map':
      final TypeDeclaration key = type.typeArguments[0];
      final TypeDeclaration value = type.typeArguments[1];
      final String q = type.isNullable ? '?' : '';
      final String k = _keyName(depth);
      final String v = _valName(depth);
      return '$expr$q.entries$q.associate { ($k, $v) -> '
          '${_toJsonKey(k, key)} to ${_toJson(v, value, depth + 1)} }';
    default:
      // int/double/String/bool/Object are already JSON-safe.
      return expr;
  }
}

/// A Kotlin expression that stringifies a map key [expr] of type [key].
String _toJsonKey(String expr, TypeDeclaration key) {
  if (key.isEnum) {
    return '$expr.toJsonValue()';
  }
  if (key.baseName == 'String') {
    return expr;
  }
  return '$expr.toString()';
}

/// A Kotlin expression that parses [raw] (an `Any?` read from the map) into
/// a value of [type]. [depth] tracks enclosing lambdas (see [_param]).
String _fromJson(String raw, TypeDeclaration type, int depth) {
  if (type.isNullable) {
    final String p = _param(depth);
    final String arrow = depth == 0 ? '' : '$p -> ';
    return '($raw)?.let { $arrow${_fromJsonNonNull(p, type, depth + 1)} }';
  }
  return _fromJsonNonNull(raw, type, depth);
}

/// A Kotlin expression that parses the non-null [value] into [type].
String _fromJsonNonNull(String value, TypeDeclaration type, int depth) {
  if (type.isEnum) {
    return '${_lowerFirst(type.baseName)}FromJsonValue($value as String)';
  }
  if (type.isClass) {
    return '${type.baseName}Json.fromJson($value as Map<String, Any?>)';
  }
  switch (type.baseName) {
    case 'String':
      return '$value as String';
    case 'int':
      return '($value as Number).toLong()';
    case 'double':
      return '($value as Number).toDouble()';
    case 'bool':
      return '$value as Boolean';
    case 'Uint8List':
      return '$_base64.decode($value as String, $_base64.NO_WRAP)';
    case 'List':
      final TypeDeclaration element = type.typeArguments.first;
      final String p = _param(depth);
      final String arrow = depth == 0 ? '' : '$p -> ';
      return '($value as List<*>).map { $arrow${_fromJson(p, element, depth + 1)} }';
    case 'Map':
      final TypeDeclaration key = type.typeArguments[0];
      final TypeDeclaration valueType = type.typeArguments[1];
      final String k = _keyName(depth);
      final String v = _valName(depth);
      return '($value as Map<*, *>).entries.associate { ($k, $v) -> '
          '${_fromJsonKey(k, key)} to ${_fromJson(v, valueType, depth + 1)} }';
    default:
      // Object / dynamic: pass through untouched.
      return value;
  }
}

/// A Kotlin expression that parses a stringified map key [expr] into [key].
String _fromJsonKey(String expr, TypeDeclaration key) {
  if (key.isEnum) {
    return '${_lowerFirst(key.baseName)}FromJsonValue($expr as String)';
  }
  switch (key.baseName) {
    case 'String':
      return '$expr as String';
    case 'int':
      return '($expr as String).toLong()';
    case 'double':
      return '($expr as String).toDouble()';
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

String _lowerFirst(String value) =>
    value.isEmpty ? value : '${value[0].toLowerCase()}${value.substring(1)}';
