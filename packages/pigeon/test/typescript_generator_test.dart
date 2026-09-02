// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pigeon/src/ast.dart';
import 'package:pigeon/src/pigeon_lib.dart';
import 'package:pigeon/src/typescript/typescript_generator.dart';
import 'package:test/test.dart';

const String DEFAULT_PACKAGE_NAME = 'test_package';

String generate(Root root) {
  final StringBuffer sink = StringBuffer();
  const TypeScriptGenerator().generate(
    const InternalTypeScriptOptions(typescriptOut: 'models.ts'),
    root,
    sink,
    dartPackageName: DEFAULT_PACKAGE_NAME,
  );
  return sink.toString();
}

void main() {
  group('prologue', () {
    final Root root = Root(apis: <Api>[], classes: <Class>[], enums: <Enum>[]);

    test('emits PigeonJsonError and validation helpers', () {
      final String code = generate(root);
      expect(code, contains('export class PigeonJsonError extends Error {}'));
      expect(
        code,
        contains('function asObject(v: unknown): Record<string, unknown>'),
      );
      expect(code, contains('function asInt(v: unknown): number'));
      expect(code, contains('function asString(v: unknown): string'));
      expect(code, contains('function nullable<T>('));
    });
  });

  group('enums', () {
    final Enum season = Enum(
      name: 'Season',
      members: <EnumMember>[
        EnumMember(name: 'spring'),
        EnumMember(name: 'readyToPlay'),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[],
      enums: <Enum>[season],
    );

    test('emits a string-union type by Dart constant name', () {
      final String code = generate(root);
      expect(code, contains("export type Season = 'spring' | 'readyToPlay';"));
    });

    test('fromJson validates membership and throws otherwise', () {
      final String code = generate(root);
      expect(
        code,
        contains('export function seasonFromJson(v: unknown): Season {'),
      );
      expect(
        code,
        contains(r'throw new PigeonJsonError(`invalid Season: ${String(v)}`);'),
      );
    });

    test('toJson is identity', () {
      final String code = generate(root);
      expect(
        code,
        contains(
          'export function seasonToJson(x: Season): string { return x; }',
        ),
      );
    });
  });

  group('concrete class', () {
    TypeDeclaration td(
      String name, {
      bool nullable = false,
      Enum? associatedEnum,
      Class? associatedClass,
    }) => TypeDeclaration(
      baseName: name,
      isNullable: nullable,
      associatedEnum: associatedEnum,
      associatedClass: associatedClass,
    );

    final Enum season = Enum(
      name: 'Season',
      members: <EnumMember>[EnumMember(name: 'spring')],
    );
    final Class address = Class(
      name: 'Address',
      fields: <NamedType>[NamedType(name: 'city', type: td('String'))],
    );
    final Class person = Class(
      name: 'Person',
      fields: <NamedType>[
        NamedType(name: 'name', type: td('String')),
        NamedType(name: 'age', type: td('int')),
        NamedType(name: 'height', type: td('double', nullable: true)),
        NamedType(name: 'season', type: td('Season', associatedEnum: season)),
        NamedType(
          name: 'address',
          type: td('Address', associatedClass: address),
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[person, address],
      enums: <Enum>[season],
    );

    test('emits interface with mapped field types', () {
      final String code = generate(root);
      expect(code, contains('export interface Person {'));
      expect(code, contains('  name: string;'));
      expect(code, contains('  age: number;'));
      expect(code, contains('  height: number | null;'));
      expect(code, contains('  season: Season;'));
      expect(code, contains('  address: Address;'));
    });

    test('fromJson validates each field, tolerating unknown keys', () {
      final String code = generate(root);
      expect(
        code,
        contains('export function personFromJson(raw: unknown): Person {'),
      );
      expect(code, contains('const o = asObject(raw);'));
      expect(code, contains("name: asString(o['name']),"));
      expect(code, contains("age: asInt(o['age']),"));
      expect(
        code,
        contains("height: nullable(o['height'], (v) => asNumber(v)),"),
      );
      expect(code, contains("season: seasonFromJson(o['season']),"));
      expect(code, contains("address: addressFromJson(o['address']),"));
    });

    test('toJson rebuilds in field order; nested class recurses', () {
      final String code = generate(root);
      expect(
        code,
        contains('export function personToJson(x: Person): unknown {'),
      );
      expect(code, contains('return {'));
      expect(code, contains('    name: x.name,'));
      expect(code, contains('    address: addressToJson(x.address),'));
    });

    test('emits string variants', () {
      final String code = generate(root);
      expect(
        code,
        contains(
          'export const personFromJsonString = (s: string): Person => personFromJson(JSON.parse(s));',
        ),
      );
      expect(
        code,
        contains(
          'export const personToJsonString = (x: Person): string => JSON.stringify(personToJson(x));',
        ),
      );
    });
  });

  group('collections', () {
    TypeDeclaration td(
      String name, {
      bool nullable = false,
      List<TypeDeclaration> args = const <TypeDeclaration>[],
      Class? associatedClass,
    }) => TypeDeclaration(
      baseName: name,
      isNullable: nullable,
      typeArguments: args,
      associatedClass: associatedClass,
    );

    final Class inner = Class(
      name: 'Inner',
      fields: <NamedType>[NamedType(name: 'v', type: td('int'))],
    );
    final Class holder = Class(
      name: 'Holder',
      fields: <NamedType>[
        NamedType(
          name: 'tags',
          type: td('List', args: <TypeDeclaration>[td('String')]),
        ),
        NamedType(
          name: 'scores',
          type: td('Map', args: <TypeDeclaration>[td('int'), td('double')]),
        ),
        NamedType(name: 'avatar', type: td('Uint8List')),
        NamedType(name: 'i32', type: td('Int32List')),
        NamedType(name: 'f64', type: td('Float64List')),
        NamedType(
          name: 'nested',
          type: td(
            'List',
            args: <TypeDeclaration>[
              td('List', args: <TypeDeclaration>[td('int')]),
            ],
          ),
        ),
        NamedType(
          name: 'inners',
          type: td(
            'List',
            args: <TypeDeclaration>[td('Inner', associatedClass: inner)],
          ),
        ),
        NamedType(
          name: 'nInners',
          type: td(
            'List',
            args: <TypeDeclaration>[
              td('Inner', nullable: true, associatedClass: inner),
            ],
          ),
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[holder, inner],
      enums: <Enum>[],
    );

    test('maps runtime types', () {
      final String code = generate(root);
      expect(code, contains('  tags: string[];'));
      expect(code, contains('  scores: Record<string, number>;'));
      expect(code, contains('  avatar: string;'));
      expect(code, contains('  i32: number[];'));
      expect(code, contains('  nested: number[][];'));
      expect(code, contains('  inners: Inner[];'));
      expect(code, contains('  nInners: (Inner | null)[];'));
    });

    test('fromJson recurses', () {
      final String code = generate(root);
      expect(
        code,
        contains("tags: asArray(o['tags']).map((v) => asString(v)),"),
      );
      expect(
        code,
        contains(
          "scores: mapValues(asRecord(o['scores']), (v) => asNumber(v)),",
        ),
      );
      expect(code, contains("avatar: asString(o['avatar']),"));
      expect(code, contains("i32: asArray(o['i32']).map((v) => asInt(v)),"));
      expect(code, contains("f64: asArray(o['f64']).map((v) => asNumber(v)),"));
      expect(
        code,
        contains(
          "nested: asArray(o['nested']).map((v) => asArray(v).map((v) => asInt(v))),",
        ),
      );
      expect(
        code,
        contains("inners: asArray(o['inners']).map((v) => innerFromJson(v)),"),
      );
      expect(
        code,
        contains(
          "nInners: asArray(o['nInners']).map((v) => nullable(v, (v) => innerFromJson(v))),",
        ),
      );
    });

    test('toJson recurses only for class-containing collections', () {
      final String code = generate(root);
      expect(code, contains('    tags: x.tags,'));
      expect(
        code,
        contains('    inners: x.inners.map((v) => innerToJson(v)),'),
      );
    });
  });

  group('sealed', () {
    TypeDeclaration td(
      String name, {
      bool nullable = false,
      Class? associatedClass,
    }) => TypeDeclaration(
      baseName: name,
      isNullable: nullable,
      associatedClass: associatedClass,
    );

    final Class base = Class(
      name: 'GameScore',
      fields: <NamedType>[],
      isSealed: true,
    );
    final Class shake = Class(
      name: 'ShakeGameScore',
      superClassName: 'GameScore',
      superClass: base,
      fields: <NamedType>[NamedType(name: 'shakes', type: td('int'))],
    );
    final Class endless = Class(
      name: 'EndlessGameScore',
      superClassName: 'GameScore',
      superClass: base,
      fields: <NamedType>[NamedType(name: 'points', type: td('int'))],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[base, shake, endless],
      enums: <Enum>[],
    );

    test('base emits a union type and dispatch on type', () {
      final String code = generate(root);
      expect(
        code,
        contains('export type GameScore = ShakeGameScore | EndlessGameScore;'),
      );
      expect(
        code,
        contains(
          'export function gameScoreFromJson(raw: unknown): GameScore {',
        ),
      );
      expect(code, contains("switch (o['type']) {"));
      expect(
        code,
        contains("case 'ShakeGameScore': return shakeGameScoreFromJson(o);"),
      );
      expect(
        code,
        contains(
          r"throw new PigeonJsonError(`unknown GameScore type: ${String(o['type'])}`);",
        ),
      );
      expect(
        code,
        contains('export function gameScoreToJson(x: GameScore): unknown {'),
      );
      expect(code, contains('switch (x.type) {'));
      expect(
        code,
        contains("case 'ShakeGameScore': return shakeGameScoreToJson(x);"),
      );
    });

    test('subclass carries the type discriminator first', () {
      final String code = generate(root);
      expect(code, contains('export interface ShakeGameScore {'));
      expect(code, contains("  type: 'ShakeGameScore';"));
      // toJson: `type` is prepended before the first real field, whose value
      // is the identity passthrough `x.shakes`. This substring only matches
      // the toJson body (fromJson's `shakes` line differs, see below), so it
      // proves `type` comes first specifically in toJson.
      expect(
        code,
        contains(
          "    type: 'ShakeGameScore',\n"
          '    shakes: x.shakes,',
        ),
      );
      // fromJson: `type` is prepended before the first real field, whose
      // value is parsed via `asInt(o['shakes'])`. This substring only
      // matches the fromJson body, so it proves `type` comes first
      // specifically in fromJson.
      expect(
        code,
        contains(
          "    type: 'ShakeGameScore',\n"
          "    shakes: asInt(o['shakes']),",
        ),
      );
    });
  });

  group('PigeonOptions wiring', () {
    test('typescriptOut round-trips through toMap/fromMap', () {
      const List<String> copyrightHeader = <String>[
        'Copyright 2024',
        'All rights reserved',
      ];
      const PigeonOptions options = PigeonOptions(
        typescriptOut: 'gen/models.ts',
        typescriptOptions: TypeScriptOptions(copyrightHeader: copyrightHeader),
      );
      final PigeonOptions restored = PigeonOptions.fromMap(options.toMap());
      expect(restored.typescriptOut, 'gen/models.ts');
      expect(restored.typescriptOptions, isNotNull);
      // A silent field-drop in TypeScriptOptions.fromMap/toMap would fail
      // this: copyrightHeader must survive the round-trip intact.
      expect(
        restored.typescriptOptions!.copyrightHeader?.toList(),
        copyrightHeader,
      );
    });
  });
}
