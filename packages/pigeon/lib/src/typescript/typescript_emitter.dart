// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Fork-specific: emits the TypeScript source for the models-only generator.
// Output is JSON-native (runtime == wire): `fromJson` validates and throws
// `PigeonJsonError` on bad input but tolerates unknown keys; `toJson` rebuilds
// the wire object in Dart field-declaration order for byte-identical output.

import '../ast.dart';
import '../generator_tools.dart';
import 'typescript_generator.dart';

/// Writes the whole TypeScript file for [root] to [indent].
void writeTypeScript(
  InternalTypeScriptOptions options,
  Root root,
  Indent indent,
) {
  _writeProlog(options, indent);
  for (final Enum anEnum in root.enums) {
    _writeEnum(indent, anEnum);
  }
  for (final Class c in root.classes) {
    if (c.isSealed) {
      _writeSealedBase(indent, root, c);
    } else {
      _writeClass(indent, root, c);
    }
  }
}

String _lowerFirst(String v) =>
    v.isEmpty ? v : '${v[0].toLowerCase()}${v.substring(1)}';

void _writeEnum(Indent indent, Enum anEnum) {
  final String name = anEnum.name;
  final String union = anEnum.members
      .map((EnumMember m) => "'${m.name}'")
      .join(' | ');
  final String members = anEnum.members
      .map((EnumMember m) => "'${m.name}'")
      .join(', ');
  indent.writeln('export type $name = $union;');
  indent.writeln(
    'const _${_lowerFirst(name)}Members: readonly $name[] = [$members];',
  );
  indent.writeln(
    'export function ${_lowerFirst(name)}FromJson(v: unknown): $name {',
  );
  indent.writeln(
    "  if (typeof v === 'string' && "
    '(_${_lowerFirst(name)}Members as readonly string[]).includes(v)) '
    'return v as $name;',
  );
  indent.writeln(
    '  throw new PigeonJsonError(`invalid $name: \${String(v)}`);',
  );
  indent.writeln('}');
  indent.writeln(
    'export function ${_lowerFirst(name)}ToJson(x: $name): string { return x; }',
  );
  indent.newln();
}

/// The TS runtime type for [type] (JSON-native representation).
String _tsType(TypeDeclaration type) {
  final String q = type.isNullable ? ' | null' : '';
  if (type.isEnum || type.isClass) {
    return '${type.baseName}$q';
  }
  switch (type.baseName) {
    case 'int':
    case 'double':
      return 'number$q';
    case 'String':
      return 'string$q';
    case 'bool':
      return 'boolean$q';
    case 'Uint8List':
      return 'string$q';
    case 'Int32List':
    case 'Int64List':
    case 'Float64List':
      return 'number[]$q';
    case 'List':
      return '${_tsListElem(type.typeArguments.first)}[]$q';
    case 'Map':
      return 'Record<string, ${_tsType(type.typeArguments[1])}>$q';
    default:
      return 'unknown$q';
  }
}

/// The TS type of a `List` element, parenthesized if nullable so e.g.
/// `(Inner | null)[]` parses as an array of nullable `Inner`.
String _tsListElem(TypeDeclaration element) {
  final String elem = _tsType(element);
  return element.isNullable ? '($elem)' : elem;
}

/// A TS expression parsing [rawExpr] into a value of [type].
String _fromJsonExpr(String rawExpr, TypeDeclaration type) {
  if (type.isNullable) {
    final TypeDeclaration nonNull = _asNonNull(type);
    return 'nullable($rawExpr, (v) => ${_fromJsonExpr('v', nonNull)})';
  }
  if (type.isEnum || type.isClass) {
    return '${_lowerFirst(type.baseName)}FromJson($rawExpr)';
  }
  switch (type.baseName) {
    case 'int':
      return 'asInt($rawExpr)';
    case 'double':
      return 'asNumber($rawExpr)';
    case 'String':
      return 'asString($rawExpr)';
    case 'bool':
      return 'asBool($rawExpr)';
    case 'Uint8List':
      return 'asString($rawExpr)';
    case 'Int32List':
    case 'Int64List':
      return 'asArray($rawExpr).map((v) => asInt(v))';
    case 'Float64List':
      return 'asArray($rawExpr).map((v) => asNumber(v))';
    case 'List':
      final TypeDeclaration el = type.typeArguments.first;
      return 'asArray($rawExpr).map((v) => ${_fromJsonExpr('v', el)})';
    case 'Map':
      final TypeDeclaration val = type.typeArguments[1];
      return 'mapValues(asRecord($rawExpr), (v) => ${_fromJsonExpr('v', val)})';
    default:
      return rawExpr; // Object/dynamic passthrough.
  }
}

/// A TS expression converting [expr] (of [type]) into a JSON-safe value.
/// Identity for everything except types that contain a class (need recursion).
String _toJsonExpr(String expr, TypeDeclaration type) {
  if (type.isNullable) {
    final TypeDeclaration nonNull = _asNonNull(type);
    if (!_needsToJson(nonNull)) {
      return expr; // nullable scalar/enum → identity
    }
    return '$expr === null ? null : ${_toJsonExpr(expr, nonNull)}';
  }
  if (type.isClass) {
    return '${_lowerFirst(type.baseName)}ToJson($expr)';
  }
  // Enums and scalars are already JSON-safe in the JSON-native representation.
  switch (type.baseName) {
    case 'List':
      final TypeDeclaration el = type.typeArguments.first;
      if (_needsToJson(el)) {
        return '$expr.map((v) => ${_toJsonExpr('v', el)})';
      }
      return expr;
    case 'Map':
      final TypeDeclaration val = type.typeArguments[1];
      if (_needsToJson(val)) {
        return 'mapValues($expr as Record<string, unknown>, (v) => ${_toJsonExpr('v', val)})';
      }
      return expr;
    default:
      return expr;
  }
}

/// Whether [type] needs any toJson transform (i.e. contains a class).
bool _needsToJson(TypeDeclaration type) {
  if (type.isClass) {
    return true;
  }
  if (type.baseName == 'List') {
    return _needsToJson(type.typeArguments.first);
  }
  if (type.baseName == 'Map') {
    return _needsToJson(type.typeArguments[1]);
  }
  return false;
}

/// Strips nullability from [type] (keeps typeArguments/associations).
TypeDeclaration _asNonNull(TypeDeclaration type) => TypeDeclaration(
  baseName: type.baseName,
  isNullable: false,
  typeArguments: type.typeArguments,
  associatedEnum: type.associatedEnum,
  associatedClass: type.associatedClass,
);

void _writeClass(Indent indent, Root root, Class classDefinition) {
  final String name = classDefinition.name;
  final String lower = _lowerFirst(name);
  final List<NamedType> fields =
      getFieldsInSerializationOrder(classDefinition).toList();
  // A sealed subclass carries a `type` discriminator (the Pigeon class name)
  // as its FIRST key, matching Kotlin/Swift/Dart for byte-identical JSON.
  final bool isSubclass = classDefinition.superClassName != null;

  // interface
  indent.writeln('export interface $name {');
  if (isSubclass) {
    indent.writeln("  type: '$name';");
  }
  for (final NamedType f in fields) {
    indent.writeln('  ${f.name}: ${_tsType(f.type)};');
  }
  indent.writeln('}');

  // fromJson
  indent.writeln('export function ${lower}FromJson(raw: unknown): $name {');
  indent.writeln('  const o = asObject(raw);');
  indent.writeln('  return {');
  if (isSubclass) {
    indent.writeln("    type: '$name',");
  }
  for (final NamedType f in fields) {
    indent.writeln(
      "    ${f.name}: ${_fromJsonExpr("o['${f.name}']", f.type)},",
    );
  }
  indent.writeln('  };');
  indent.writeln('}');

  // toJson (rebuilds in field order → byte-identical)
  indent.writeln('export function ${lower}ToJson(x: $name): unknown {');
  indent.writeln('  return {');
  if (isSubclass) {
    indent.writeln("    type: '$name',");
  }
  for (final NamedType f in fields) {
    indent.writeln('    ${f.name}: ${_toJsonExpr('x.${f.name}', f.type)},');
  }
  indent.writeln('  };');
  indent.writeln('}');

  // string variants
  indent.writeln(
    'export const ${lower}FromJsonString = (s: string): $name => ${lower}FromJson(JSON.parse(s));',
  );
  indent.writeln(
    'export const ${lower}ToJsonString = (x: $name): string => JSON.stringify(${lower}ToJson(x));',
  );
  indent.newln();
}

/// Writes a sealed base class as a discriminated union: a `type` alias over
/// its subclasses, plus `fromJson`/`toJson` that dispatch on the `type`
/// discriminator to each subclass's own `fromJson`/`toJson`.
void _writeSealedBase(Indent indent, Root root, Class base) {
  final String name = base.name;
  final String lower = _lowerFirst(name);
  final List<Class> subs =
      root.classes.where((Class c) => c.superClassName == name).toList();
  if (subs.isEmpty) {
    return;
  }
  indent.writeln(
    'export type $name = ${subs.map((Class c) => c.name).join(' | ')};',
  );
  indent.writeln('export function ${lower}FromJson(raw: unknown): $name {');
  indent.writeln('  const o = asObject(raw);');
  indent.writeln("  switch (o['type']) {");
  for (final Class sub in subs) {
    indent.writeln(
      "    case '${sub.name}': return ${_lowerFirst(sub.name)}FromJson(o);",
    );
  }
  indent.writeln(
    '    default: throw new PigeonJsonError(`unknown $name type: '
    r"${String(o['type'])}`);",
  );
  indent.writeln('  }');
  indent.writeln('}');
  indent.writeln('export function ${lower}ToJson(x: $name): unknown {');
  indent.writeln('  switch (x.type) {');
  for (final Class sub in subs) {
    indent.writeln(
      "    case '${sub.name}': return ${_lowerFirst(sub.name)}ToJson(x);",
    );
  }
  indent.writeln('  }');
  indent.writeln('}');
  indent.writeln(
    'export const ${lower}FromJsonString = (s: string): $name => ${lower}FromJson(JSON.parse(s));',
  );
  indent.writeln(
    'export const ${lower}ToJsonString = (x: $name): string => JSON.stringify(${lower}ToJson(x));',
  );
  indent.newln();
}

void _writeProlog(InternalTypeScriptOptions options, Indent indent) {
  if (options.copyrightHeader != null) {
    for (final String line in options.copyrightHeader!) {
      if (line.isEmpty) {
        indent.writeln('//');
      } else {
        indent.writeln('// $line');
      }
    }
  }
  indent.writeln('// Generated by Pigeon. Do not edit by hand.');
  indent.newln();
  indent.writeln('export class PigeonJsonError extends Error {}');
  indent.newln();
  indent.writeln('function asObject(v: unknown): Record<string, unknown> {');
  indent.writeln(
    "  if (v === null || typeof v !== 'object' || Array.isArray(v)) "
    "throw new PigeonJsonError('expected object');",
  );
  indent.writeln('  return v as Record<string, unknown>;');
  indent.writeln('}');
  indent.writeln('function asString(v: unknown): string {');
  indent.writeln(
    "  if (typeof v !== 'string') throw new PigeonJsonError('expected string');",
  );
  indent.writeln('  return v;');
  indent.writeln('}');
  indent.writeln('function asNumber(v: unknown): number {');
  indent.writeln(
    "  if (typeof v !== 'number') throw new PigeonJsonError('expected number');",
  );
  indent.writeln('  return v;');
  indent.writeln('}');
  indent.writeln('function asInt(v: unknown): number {');
  indent.writeln(
    "  if (typeof v !== 'number' || !Number.isInteger(v)) "
    "throw new PigeonJsonError('expected integer');",
  );
  indent.writeln('  return v;');
  indent.writeln('}');
  indent.writeln('function asBool(v: unknown): boolean {');
  indent.writeln(
    "  if (typeof v !== 'boolean') throw new PigeonJsonError('expected boolean');",
  );
  indent.writeln('  return v;');
  indent.writeln('}');
  indent.writeln('function asArray(v: unknown): unknown[] {');
  indent.writeln(
    "  if (!Array.isArray(v)) throw new PigeonJsonError('expected array');",
  );
  indent.writeln('  return v;');
  indent.writeln('}');
  indent.writeln(
    'function asRecord(v: unknown): Record<string, unknown> { return asObject(v); }',
  );
  indent.writeln(
    'function mapValues<V>(o: Record<string, unknown>, f: (x: unknown) => V): Record<string, V> {',
  );
  indent.writeln('  const out: Record<string, V> = {};');
  indent.writeln('  for (const k of Object.keys(o)) out[k] = f(o[k]);');
  indent.writeln('  return out;');
  indent.writeln('}');
  indent.writeln(
    'function nullable<T>(v: unknown, f: (x: unknown) => T): T | null {',
  );
  indent.writeln('  return v === null || v === undefined ? null : f(v);');
  indent.writeln('}');
  indent.newln();
}
