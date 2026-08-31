// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Fork-specific extension (not part of upstream Pigeon): emits `toJson`/
// `fromJson` (and their string variants) for generated Swift data types,
// gated by `SwiftOptions.generateJson`. Kept in a separate file so the touch
// on `swift_generator.dart` stays minimal and easy to rebase.
//
// JSON shape matches the shared contract (identical to `kotlin_json.dart`):
//  * map keys are the Dart field names verbatim;
//  * enums are encoded by their Dart constant name (Swift lower-camel-cases the
//    cases, so an explicit mapping is generated);
//  * `Map` keys are always stringified; nullable keys are always present (null);
//  * `Uint8List` is base64; sealed hierarchies carry a `"type"` discriminator
//    equal to the Pigeon class name;
//  * numeric typed-data lists (`Int32List`/`Int64List`/`Float64List`) are plain
//    JSON number arrays (`Float32List` is not a valid Pigeon field type).

import '../ast.dart';
import '../generator_tools.dart';

/// Writes the JSON (de)serialization section for [root] to [indent].
///
/// Emits, in order: shared encode/decode helpers, per-enum name mappings, and
/// per-type `toJson`/`toJsonString`/`fromJson`/`fromJsonString` extensions.
///
/// [accessLevel] mirrors `SwiftOptions.accessLevel` and is applied to every
/// generated member and the `<Class>Json` namespaces, so that when the data
/// types are `public` their JSON (de)serialization is reachable across the
/// module boundary too (Swift extension members are `internal` by default).
/// The `pigeonJsonEncode`/`pigeonJsonDecode` helpers stay `private` — they are
/// only called from within the generated module.
void writeSwiftJson(Root root, Indent indent, {String? accessLevel}) {
  final String access = accessLevel != null ? '$accessLevel ' : '';
  _writeHelpers(indent);
  for (final Enum anEnum in root.enums) {
    _writeEnumJson(indent, anEnum, access);
  }
  for (final Class classDefinition in root.classes) {
    if (classDefinition.isSealed) {
      _writeSealedBaseJson(root, indent, classDefinition, access);
    } else {
      _writeClassJson(indent, classDefinition, access);
    }
  }
}

void _writeHelpers(Indent indent) {
  indent.newln();
  indent.writeScoped('private func pigeonJsonEncode(_ value: Any?) -> Any {', '}', () {
    indent.writeln('guard let value = value, !(value is NSNull) else { return NSNull() }');
    indent.writeScoped('if let map = value as? [String: Any?] {', '}', () {
      indent.writeln(r'return map.reduce(into: [String: Any]()) { $0[$1.key] = pigeonJsonEncode($1.value) }');
    });
    indent.writeScoped('if let list = value as? [Any?] {', '}', () {
      indent.writeln(r'return list.map { pigeonJsonEncode($0) }');
    });
    indent.writeln('return value');
  });

  indent.newln();
  indent.writeScoped('private func pigeonJsonDecode(_ value: Any?) -> Any? {', '}', () {
    indent.writeln('guard let value = value, !(value is NSNull) else { return nil }');
    indent.writeScoped('if let map = value as? [String: Any] {', '}', () {
      indent.writeln(r'return map.reduce(into: [String: Any?]()) { $0[$1.key] = pigeonJsonDecode($1.value) }');
    });
    indent.writeScoped('if let list = value as? [Any] {', '}', () {
      indent.writeln(r'return list.map { pigeonJsonDecode($0) }');
    });
    indent.writeln('return value');
  });
}

void _writeEnumJson(Indent indent, Enum anEnum, String access) {
  final String name = anEnum.name;
  indent.newln();
  indent.writeScoped('extension $name {', '}', () {
    indent.writeScoped('${access}func toJsonValue() -> String {', '}', () {
      indent.writeScoped('switch self {', '}', () {
        for (final EnumMember member in anEnum.members) {
          indent.writeln('case .${_camelCase(member.name)}: return "${member.name}"');
        }
      });
    });
    indent.writeScoped('${access}static func fromJsonValue(_ value: String) -> $name {', '}', () {
      indent.writeScoped('switch value {', '}', () {
        for (final EnumMember member in anEnum.members) {
          indent.writeln('case "${member.name}": return .${_camelCase(member.name)}');
        }
        indent.writeln('default: fatalError("Unknown $name: \\(value)")');
      });
    });
  });
}

void _writeClassJson(Indent indent, Class classDefinition, String access) {
  final String name = classDefinition.name;
  final bool isSubclass = classDefinition.superClassName != null;
  final List<NamedType> fields =
      getFieldsInSerializationOrder(classDefinition).toList();

  indent.newln();
  indent.writeScoped('extension $name {', '}', () {
    _writeToJson(indent, fields, access, typeName: isSubclass ? name : null);
    _writeToJsonString(indent, access);

    indent.writeScoped(
      '${access}static func fromJson(_ pigeonMap: [String: Any?]) -> $name {',
      '}',
      () {
        indent.writeScoped('return $name(', ')', () {
          for (int i = 0; i < fields.length; i++) {
            final NamedType field = fields[i];
            final String comma = i == fields.length - 1 ? '' : ',';
            indent.writeln(
              '${field.name}: '
              '${_fromJson('(pigeonMap["${field.name}"] ?? nil)', field.type, 0)}'
              '$comma',
            );
          }
        });
      },
    );
    _writeFromJsonString(indent, name, access);
  });
}

void _writeSealedBaseJson(Root root, Indent indent, Class base, String access) {
  final String name = base.name;
  final List<Class> subclasses = root.classes
      .where((Class c) => c.superClassName == name)
      .toList();
  if (subclasses.isEmpty) {
    return;
  }

  indent.newln();
  // Instance methods live on the protocol extension (legal on `any $name`).
  indent.writeScoped('extension $name {', '}', () {
    indent.writeScoped('${access}func toJson() -> [String: Any?] {', '}', () {
      indent.writeScoped('switch self {', '}', () {
        for (final Class sub in subclasses) {
          indent.writeln('case let value as ${sub.name}: return value.toJson()');
        }
        indent.writeln('default: return [:]');
      });
    });
    _writeToJsonString(indent, access);
  });

  // Static decoders go in an enum namespace, not a protocol extension: Swift
  // forbids calling a static member on a protocol metatype (`$name.fromJson`
  // is an error), so mirror Kotlin's `object ${name}Json`. The enum itself is
  // access-prefixed because a type's members are `internal` by default even
  // inside a `public` enum, unlike extension members.
  indent.newln();
  indent.writeScoped('${access}enum ${name}Json {', '}', () {
    indent.writeScoped(
      '${access}static func fromJson(_ pigeonMap: [String: Any?]) -> $name? {',
      '}',
      () {
        indent.writeScoped('switch (pigeonMap["type"] ?? nil) as? String {', '}', () {
          for (final Class sub in subclasses) {
            indent.writeln('case "${sub.name}": return ${sub.name}.fromJson(pigeonMap)');
          }
          indent.writeln('default: return nil');
        });
      },
    );
    // The base's `fromJson` already returns an optional, so `fromJsonString`
    // forwards it directly rather than wrapping a non-optional result.
    indent.writeScoped(
      '${access}static func fromJsonString(_ json: String) -> $name? {',
      '}',
      () {
        _writeDecodeGuard(indent);
        indent.writeln('return ${name}Json.fromJson(pigeonMap)');
      },
    );
  });
}

/// Writes `func toJson() -> [String: Any?]` for a concrete data class.
///
/// When [typeName] is non-null the class is a sealed subclass and a `"type"`
/// discriminator with that value is emitted first.
void _writeToJson(
  Indent indent,
  List<NamedType> fields,
  String access, {
  String? typeName,
}) {
  indent.writeScoped('${access}func toJson() -> [String: Any?] {', '}', () {
    if (fields.isEmpty && typeName == null) {
      indent.writeln('return [:]');
      return;
    }
    indent.writeScoped('return [', ']', () {
      if (typeName != null) {
        indent.writeln('"type": "$typeName",');
      }
      for (final NamedType field in fields) {
        indent.writeln(
          '"${field.name}": ${_toJson('self.${field.name}', field.type, 0)},',
        );
      }
    });
  });
}

void _writeToJsonString(Indent indent, String access) {
  indent.writeScoped('${access}func toJsonString() -> String? {', '}', () {
    indent.writeln(
      'guard let data = try? JSONSerialization.data(withJSONObject: '
      'pigeonJsonEncode(self.toJson())) else { return nil }',
    );
    indent.writeln('return String(data: data, encoding: .utf8)');
  });
}

void _writeFromJsonString(Indent indent, String name, String access) {
  indent.writeScoped(
    '${access}static func fromJsonString(_ json: String) -> $name? {',
    '}',
    () {
      _writeDecodeGuard(indent);
      indent.writeln('return $name.fromJson(pigeonMap)');
    },
  );
}

/// Writes the shared `guard` that turns a JSON string into a decoded
/// `[String: Any?]` bound to `pigeonMap`, returning nil on any failure.
void _writeDecodeGuard(Indent indent) {
  indent.writeln('guard let data = json.data(using: .utf8),');
  indent.writeln('  let object = try? JSONSerialization.jsonObject(with: data),');
  indent.writeln('  let pigeonMap = pigeonJsonDecode(object) as? [String: Any?]');
  indent.writeln('else { return nil }');
}

/// The closure parameter name to use at nesting [depth]. Every generated
/// closure uses an explicit, depth-unique name so nested closures never shadow
/// one another (Swift's `$0` would).
String _param(int depth) => 'p$depth';

/// Numeric typed-data lists, keyed by Dart base name. Each entry is
/// `[swiftElement, nsNumberAccessor, flutterInitLabel]`:
///  * `swiftElement` — the element type the bytes reinterpret to;
///  * `nsNumberAccessor` — the `NSNumber` getter used on decode;
///  * `flutterInitLabel` — the `FlutterStandardTypedData(<label>:)` init label.
///
/// All three encode as a plain JSON number array (matching the Kotlin side).
/// `Uint8List` is deliberately absent — it stays a base64 string. `Float32List`
/// is not a valid Pigeon field type, so it never appears here.
const Map<String, List<String>> _numericTypedData = <String, List<String>>{
  'Int32List': <String>['Int32', 'int32Value', 'int32'],
  'Int64List': <String>['Int64', 'int64Value', 'int64'],
  'Float64List': <String>['Double', 'doubleValue', 'float64'],
};

/// A Swift expression that converts [expr] (of [type]) into a JSON-safe value.
///
/// [expr] is always a non-optional Swift value (a stored property or a closure
/// parameter); optionality is handled here via optional chaining.
String _toJson(String expr, TypeDeclaration type, int depth) {
  if (type.isEnum) {
    return type.isNullable ? '$expr?.toJsonValue()' : '$expr.toJsonValue()';
  }
  if (type.isClass) {
    return type.isNullable ? '$expr?.toJson()' : '$expr.toJson()';
  }
  switch (type.baseName) {
    case 'Uint8List':
      return type.isNullable
          ? '$expr?.data.base64EncodedString()'
          : '$expr.data.base64EncodedString()';
    case 'Int32List':
    case 'Int64List':
    case 'Float64List':
      final String element = _numericTypedData[type.baseName]![0];
      final String q = type.isNullable ? '?' : '';
      return '$expr$q.data.withUnsafeBytes '
          '{ rawBuffer in Array(rawBuffer.bindMemory(to: $element.self)) }';
    case 'List':
      final TypeDeclaration element = type.typeArguments.first;
      if (_isPassthrough(element)) {
        return expr;
      }
      final String q = type.isNullable ? '?' : '';
      final String p = _param(depth);
      return '$expr$q.map { $p in ${_toJson(p, element, depth + 1)} }';
    case 'Map':
      final TypeDeclaration key = type.typeArguments[0];
      final TypeDeclaration value = type.typeArguments[1];
      String core(String source, int atDepth) {
        final String p = _param(atDepth);
        return 'Dictionary(uniqueKeysWithValues: $source.map { $p in '
            '(${_toJsonKey('$p.key', key)}, ${_toJson('$p.value', value, atDepth + 1)} as Any?) })';
      }

      if (type.isNullable) {
        final String p = _param(depth);
        return '$expr.map { $p in ${core(p, depth + 1)} }';
      }
      return core(expr, depth);
    default:
      // int/double/String/bool/Object are already JSON-safe (nullable ones too:
      // a nil becomes `NSNull` in `pigeonJsonEncode`).
      return expr;
  }
}

/// A Swift expression that stringifies a map key [expr] of type [key].
String _toJsonKey(String expr, TypeDeclaration key) {
  if (key.isEnum) {
    return '$expr.toJsonValue()';
  }
  if (key.baseName == 'String') {
    return expr;
  }
  return 'String(describing: $expr)';
}

/// A Swift expression that parses [raw] (an `Any?` read from the map) into a
/// value of [type]. [depth] tracks enclosing closures (see [_param]).
String _fromJson(String raw, TypeDeclaration type, int depth) {
  if (type.isNullable) {
    final String p = _param(depth);
    // `Optional.map` unwraps, so the closure parameter is non-optional.
    return '$raw.map { $p in ${_fromJsonNonNull(p, type, depth + 1, unwrapped: true)} }';
  }
  return _fromJsonNonNull(raw, type, depth);
}

/// A Swift expression that parses the non-null [value] into [type].
///
/// [unwrapped] is true when [value] is already a non-optional `Any` (it came
/// from an `Optional.map` closure); it only affects the pass-through `Object`
/// case, which must force-unwrap an `Any?` but leave an `Any` alone.
String _fromJsonNonNull(
  String value,
  TypeDeclaration type,
  int depth, {
  bool unwrapped = false,
}) {
  if (type.isEnum) {
    return '${type.baseName}.fromJsonValue($value as! String)';
  }
  if (type.isClass) {
    // A sealed base decodes via its `${name}Json` enum namespace (a protocol
    // metatype can't carry a static `fromJson`) and returns an optional, so a
    // non-null field of that type force-unwraps it. Concrete classes decode via
    // their own extension static and return non-optional already.
    if (type.associatedClass?.isSealed ?? false) {
      return '${type.baseName}Json.fromJson($value as! [String: Any?])!';
    }
    return '${type.baseName}.fromJson($value as! [String: Any?])';
  }
  switch (type.baseName) {
    case 'String':
      return '$value as! String';
    case 'int':
      return '($value as! NSNumber).int64Value';
    case 'double':
      return '($value as! NSNumber).doubleValue';
    case 'bool':
      return '$value as! Bool';
    case 'Uint8List':
      return 'FlutterStandardTypedData(bytes: Data(base64Encoded: $value as! String)!)';
    case 'Int32List':
    case 'Int64List':
    case 'Float64List':
      final List<String> meta = _numericTypedData[type.baseName]!;
      final String p = _param(depth);
      return 'FlutterStandardTypedData(${meta[2]}: ($value as! [Any?]).map '
          '{ $p in ($p as! NSNumber).${meta[1]} }.withUnsafeBufferPointer '
          '{ buffer in Data(buffer: buffer) })';
    case 'List':
      final TypeDeclaration element = type.typeArguments.first;
      final String p = _param(depth);
      return '($value as! [Any?]).map { $p in ${_fromJson(p, element, depth + 1)} }';
    case 'Map':
      final TypeDeclaration key = type.typeArguments[0];
      final TypeDeclaration valueType = type.typeArguments[1];
      final String p = _param(depth);
      return 'Dictionary(uniqueKeysWithValues: ($value as! [String: Any?]).map { $p in '
          '(${_fromJsonKey('$p.key', key)}, ${_fromJson('$p.value', valueType, depth + 1)}) })';
    default:
      // Object / dynamic: pass through untouched. Force-unwrap only when the
      // value is still optional (a non-null field read straight from the map).
      return unwrapped ? value : '$value!';
  }
}

/// A Swift expression that parses a stringified map key [expr] into [key].
/// [expr] is always a `String` (JSON object keys), so no cast is needed.
String _fromJsonKey(String expr, TypeDeclaration key) {
  if (key.isEnum) {
    return '${key.baseName}.fromJsonValue($expr)';
  }
  switch (key.baseName) {
    case 'int':
      return 'Int64($expr)!';
    case 'double':
      return 'Double($expr)!';
    default:
      return expr;
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

/// Lower-camel-cases [text] the same way `swift_generator.dart` names enum
/// cases, so the generated `toJsonValue`/`fromJsonValue` switches line up.
String _camelCase(String text) {
  final String pascal = text
      .split('_')
      .map((String part) =>
          part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
      .join();
  return pascal.isEmpty ? pascal : pascal[0].toLowerCase() + pascal.substring(1);
}
