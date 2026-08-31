// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pigeon/src/ast.dart';
import 'package:pigeon/src/swift/swift_generator.dart';
import 'package:test/test.dart';

import 'dart_generator_test.dart';

final Class emptyClass = Class(
  name: 'className',
  fields: <NamedType>[
    NamedType(
      name: 'namedTypeName',
      type: const TypeDeclaration(baseName: 'baseName', isNullable: false),
    ),
  ],
);

final Enum emptyEnum = Enum(
  name: 'enumName',
  members: <EnumMember>[EnumMember(name: 'enumMemberName')],
);

void main() {
  test('gen one class', () {
    final Class classDefinition = Class(
      name: 'Foobar',
      fields: <NamedType>[
        NamedType(
          type: const TypeDeclaration(baseName: 'int', isNullable: true),
          name: 'field1',
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[classDefinition],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('struct Foobar'));
    expect(code, contains('var field1: Int64? = nil'));
    expect(
      code,
      contains('static func fromList(_ pigeonVar_list: [Any?]) -> Foobar?'),
    );
    expect(code, contains('func toList() -> [Any?]'));
    expect(code, isNot(contains('if (')));
  });

  test('gen one enum', () {
    final Enum anEnum = Enum(
      name: 'Foobar',
      members: <EnumMember>[EnumMember(name: 'one'), EnumMember(name: 'two')],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[],
      enums: <Enum>[anEnum],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('enum Foobar: Int'));
    expect(code, contains('  case one = 0'));
    expect(code, contains('  case two = 1'));
    expect(code, isNot(contains('if (')));
  });

  test('primitive enum host', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Bar',
          methods: <Method>[
            Method(
              name: 'bar',
              location: ApiLocation.host,
              returnType: const TypeDeclaration.voidDeclaration(),
              parameters: <Parameter>[
                Parameter(
                  name: 'foo',
                  type: TypeDeclaration(
                    baseName: 'Foo',
                    associatedEnum: emptyEnum,
                    isNullable: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[
        Enum(
          name: 'Foo',
          members: <EnumMember>[
            EnumMember(name: 'one'),
            EnumMember(name: 'two'),
          ],
        ),
      ],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('enum Foo: Int'));
    expect(
      code,
      contains(
        'let enumResultAsInt: Int? = nilOrValue(self.readValue() as! Int?)',
      ),
    );
    expect(code, contains('return Foo(rawValue: enumResultAsInt)'));
    expect(code, contains('let fooArg = args[0] as! Foo'));
    expect(code, isNot(contains('if (')));
  });

  test('gen one host api', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: '',
                ),
              ],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('protocol Api'));
    expect(code, matches('func doSomething.*Input.*Output'));
    expect(code, contains('doSomethingChannel.setMessageHandler'));
    expect(code, isNot(contains('if (')));
  });

  test('all the simple datatypes header', () {
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[
        Class(
          name: 'Foobar',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'bool', isNullable: true),
              name: 'aBool',
            ),
            NamedType(
              type: const TypeDeclaration(baseName: 'int', isNullable: true),
              name: 'aInt',
            ),
            NamedType(
              type: const TypeDeclaration(baseName: 'double', isNullable: true),
              name: 'aDouble',
            ),
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'aString',
            ),
            NamedType(
              type: const TypeDeclaration(
                baseName: 'Uint8List',
                isNullable: true,
              ),
              name: 'aUint8List',
            ),
            NamedType(
              type: const TypeDeclaration(
                baseName: 'Int32List',
                isNullable: true,
              ),
              name: 'aInt32List',
            ),
            NamedType(
              type: const TypeDeclaration(
                baseName: 'Int64List',
                isNullable: true,
              ),
              name: 'aInt64List',
            ),
            NamedType(
              type: const TypeDeclaration(
                baseName: 'Float64List',
                isNullable: true,
              ),
              name: 'aFloat64List',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );

    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('var aBool: Bool? = nil'));
    expect(code, contains('var aInt: Int64? = nil'));
    expect(code, contains('var aDouble: Double? = nil'));
    expect(code, contains('var aString: String? = nil'));
    expect(code, contains('var aUint8List: FlutterStandardTypedData? = nil'));
    expect(code, contains('var aInt32List: FlutterStandardTypedData? = nil'));
    expect(code, contains('var aInt64List: FlutterStandardTypedData? = nil'));
    expect(code, contains('var aFloat64List: FlutterStandardTypedData? = nil'));
  });

  test('gen pigeon error type', () {
    final Root root = Root(apis: <Api>[], classes: <Class>[], enums: <Enum>[]);
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();

    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('class PigeonError: Error'));
    expect(code, contains('let code: String'));
    expect(code, contains('let message: String?'));
    expect(code, contains('let details: Sendable?'));
    expect(
      code,
      contains('init(code: String, message: String?, details: Sendable?)'),
    );
  });

  test('gen one flutter api', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.flutter,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: '',
                ),
              ],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('class Api'));
    expect(
      code,
      contains(
        'init(binaryMessenger: FlutterBinaryMessenger, messageChannelSuffix: String = "")',
      ),
    );
    expect(code, matches('func doSomething.*Input.*Output'));
    expect(code, isNot(contains('if (')));
    expect(code, isNot(matches(RegExp(r';$', multiLine: true))));
  });

  test('gen host void api', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: '',
                ),
              ],
              returnType: const TypeDeclaration.voidDeclaration(),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, isNot(matches('.*doSomething(.*) ->')));
    expect(code, matches('doSomething(.*)'));
    expect(code, isNot(contains('if (')));
  });

  test('gen flutter void return api', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.flutter,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: '',
                ),
              ],
              returnType: const TypeDeclaration.voidDeclaration(),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(
      code,
      contains('completion: @escaping (Result<Void, PigeonError>) -> Void'),
    );
    expect(code, contains('completion(.success(()))'));
    expect(code, isNot(contains('if (')));
  });

  test('gen host void argument api', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.host,
              parameters: <Parameter>[],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func doSomething() throws -> Output'));
    expect(code, contains('let result = try api.doSomething()'));
    expect(code, contains('reply(wrapResult(result))'));
    expect(code, isNot(contains('if (')));
  });

  test('gen flutter void argument api', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.flutter,
              parameters: <Parameter>[],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(
      code,
      contains(
        'func doSomething(completion: @escaping (Result<Output, PigeonError>) -> Void)',
      ),
    );
    expect(code, contains('channel.sendMessage(nil'));
    expect(code, isNot(contains('if (')));
  });

  test('gen list', () {
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[
        Class(
          name: 'Foobar',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'List', isNullable: true),
              name: 'field1',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('struct Foobar'));
    expect(code, contains('var field1: [Any?]? = nil'));
    expect(code, isNot(contains('if (')));
  });

  test('gen map', () {
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[
        Class(
          name: 'Foobar',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'Map', isNullable: true),
              name: 'field1',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('struct Foobar'));
    expect(code, contains('var field1: [AnyHashable?: Any?]? = nil'));
    expect(code, isNot(contains('if (')));
  });

  test('gen nested', () {
    final Class classDefinition = Class(
      name: 'Outer',
      fields: <NamedType>[
        NamedType(
          type: TypeDeclaration(
            baseName: 'Nested',
            associatedClass: emptyClass,
            isNullable: true,
          ),
          name: 'nested',
        ),
      ],
    );
    final Class nestedClass = Class(
      name: 'Nested',
      fields: <NamedType>[
        NamedType(
          type: const TypeDeclaration(baseName: 'int', isNullable: true),
          name: 'data',
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[classDefinition, nestedClass],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('struct Outer'));
    expect(code, contains('struct Nested'));
    expect(code, contains('var nested: Nested? = nil'));
    expect(
      code,
      contains('static func fromList(_ pigeonVar_list: [Any?]) -> Outer?'),
    );
    expect(
      code,
      contains('let nested: Nested? = nilOrValue(pigeonVar_list[0])'),
    );
    expect(code, contains('func toList() -> [Any?]'));
    expect(code, isNot(contains('if (')));
    // Single-element list serializations should not have a trailing comma.
    expect(code, matches(RegExp(r'return \[\s*data\s*]')));
  });

  test('gen one async Host Api', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: 'arg',
                ),
              ],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
              isAsynchronous: true,
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('protocol Api'));
    expect(code, contains('api.doSomething(arg: argArg) { result in'));
    expect(code, contains('reply(wrapResult(res))'));
    expect(code, isNot(contains('if (')));
  });

  test('gen one async Flutter Api', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.flutter,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: '',
                ),
              ],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
              isAsynchronous: true,
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('class Api'));
    expect(code, matches('func doSomething.*Input.*completion.*Output.*Void'));
    expect(code, isNot(contains('if (')));
  });

  test('gen one enum class', () {
    final Enum anEnum = Enum(
      name: 'Enum1',
      members: <EnumMember>[EnumMember(name: 'one'), EnumMember(name: 'two')],
    );
    final Class classDefinition = Class(
      name: 'EnumClass',
      fields: <NamedType>[
        NamedType(
          type: TypeDeclaration(
            baseName: 'Enum1',
            associatedEnum: emptyEnum,
            isNullable: true,
          ),
          name: 'enum1',
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[classDefinition],
      enums: <Enum>[anEnum],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('enum Enum1: Int'));
    expect(code, contains('case one = 0'));
    expect(code, contains('case two = 1'));
    expect(code, isNot(contains('if (')));
  });

  test('header', () {
    final Root root = Root(apis: <Api>[], classes: <Class>[], enums: <Enum>[]);
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
      copyrightHeader: <String>['hello world', ''],
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, startsWith('// hello world'));
    // There should be no trailing whitespace on generated comments.
    expect(code, isNot(matches(RegExp(r'^//.* $', multiLine: true))));
  });

  test('generics - list', () {
    final Class classDefinition = Class(
      name: 'Foobar',
      fields: <NamedType>[
        NamedType(
          type: const TypeDeclaration(
            baseName: 'List',
            isNullable: true,
            typeArguments: <TypeDeclaration>[
              TypeDeclaration(baseName: 'int', isNullable: true),
            ],
          ),
          name: 'field1',
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[classDefinition],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('struct Foobar'));
    expect(code, contains('var field1: [Int64?]'));
  });

  test('generics - maps', () {
    final Class classDefinition = Class(
      name: 'Foobar',
      fields: <NamedType>[
        NamedType(
          type: const TypeDeclaration(
            baseName: 'Map',
            isNullable: true,
            typeArguments: <TypeDeclaration>[
              TypeDeclaration(baseName: 'String', isNullable: true),
              TypeDeclaration(baseName: 'String', isNullable: true),
            ],
          ),
          name: 'field1',
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[classDefinition],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('struct Foobar'));
    expect(code, contains('var field1: [String?: String?]'));
  });

  test('host generics argument', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.host,
              returnType: const TypeDeclaration.voidDeclaration(),
              parameters: <Parameter>[
                Parameter(
                  type: const TypeDeclaration(
                    baseName: 'List',
                    isNullable: false,
                    typeArguments: <TypeDeclaration>[
                      TypeDeclaration(baseName: 'int', isNullable: true),
                    ],
                  ),
                  name: 'arg',
                ),
              ],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func doit(arg: [Int64?]'));
  });

  test('flutter generics argument', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.flutter,
              returnType: const TypeDeclaration.voidDeclaration(),
              parameters: <Parameter>[
                Parameter(
                  type: const TypeDeclaration(
                    baseName: 'List',
                    isNullable: false,
                    typeArguments: <TypeDeclaration>[
                      TypeDeclaration(baseName: 'int', isNullable: true),
                    ],
                  ),
                  name: 'arg',
                ),
              ],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func doit(arg argArg: [Int64?]'));
  });

  test('host generics return', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.host,
              returnType: const TypeDeclaration(
                baseName: 'List',
                isNullable: false,
                typeArguments: <TypeDeclaration>[
                  TypeDeclaration(baseName: 'int', isNullable: true),
                ],
              ),
              parameters: <Parameter>[],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func doit() throws -> [Int64?]'));
    expect(code, contains('let result = try api.doit()'));
    expect(code, contains('reply(wrapResult(result))'));
  });

  test('flutter generics return', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.flutter,
              returnType: const TypeDeclaration(
                baseName: 'List',
                isNullable: false,
                typeArguments: <TypeDeclaration>[
                  TypeDeclaration(baseName: 'int', isNullable: true),
                ],
              ),
              parameters: <Parameter>[],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(
      code,
      contains(
        'func doit(completion: @escaping (Result<[Int64?], PigeonError>) -> Void)',
      ),
    );
    expect(code, contains('let result = listResponse[0] as! [Int64?]'));
    expect(code, contains('completion(.success(result))'));
  });

  test('host multiple args', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'add',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  name: 'x',
                  type: const TypeDeclaration(
                    isNullable: false,
                    baseName: 'int',
                  ),
                ),
                Parameter(
                  name: 'y',
                  type: const TypeDeclaration(
                    isNullable: false,
                    baseName: 'int',
                  ),
                ),
              ],
              returnType: const TypeDeclaration(
                baseName: 'int',
                isNullable: false,
              ),
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func add(x: Int64, y: Int64) throws -> Int64'));
    expect(code, contains('let args = message as! [Any?]'));
    expect(code, contains('let xArg = args[0] as! Int64'));
    expect(code, contains('let yArg = args[1] as! Int64'));
    expect(code, contains('let result = try api.add(x: xArg, y: yArg)'));
    expect(code, contains('reply(wrapResult(result))'));
  });

  test('flutter multiple args', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'add',
              location: ApiLocation.flutter,
              parameters: <Parameter>[
                Parameter(
                  name: 'x',
                  type: const TypeDeclaration(
                    baseName: 'int',
                    isNullable: false,
                  ),
                ),
                Parameter(
                  name: 'y',
                  type: const TypeDeclaration(
                    baseName: 'int',
                    isNullable: false,
                  ),
                ),
              ],
              returnType: const TypeDeclaration(
                baseName: 'int',
                isNullable: false,
              ),
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('let channel = FlutterBasicMessageChannel'));
    expect(code, contains('let result = listResponse[0] as! Int64'));
    expect(code, contains('completion(.success(result))'));
    expect(
      code,
      contains(
        'func add(x xArg: Int64, y yArg: Int64, completion: @escaping (Result<Int64, PigeonError>) -> Void)',
      ),
    );
    expect(
      code,
      contains('channel.sendMessage([xArg, yArg] as [Any?]) { response in'),
    );
  });

  test('return nullable host', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.host,
              returnType: const TypeDeclaration(
                baseName: 'int',
                isNullable: true,
              ),
              parameters: <Parameter>[],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func doit() throws -> Int64?'));
  });

  test('return nullable host async', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.host,
              returnType: const TypeDeclaration(
                baseName: 'int',
                isNullable: true,
              ),
              isAsynchronous: true,
              parameters: <Parameter>[],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(
      code,
      contains(
        'func doit(completion: @escaping (Result<Int64?, Error>) -> Void',
      ),
    );
  });

  test('nullable argument host', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.host,
              returnType: const TypeDeclaration.voidDeclaration(),
              parameters: <Parameter>[
                Parameter(
                  name: 'foo',
                  type: const TypeDeclaration(
                    baseName: 'int',
                    isNullable: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('let fooArg: Int64? = nilOrValue(args[0])'));
  });

  test('nullable argument flutter', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doit',
              location: ApiLocation.flutter,
              returnType: const TypeDeclaration.voidDeclaration(),
              parameters: <Parameter>[
                Parameter(
                  name: 'foo',
                  type: const TypeDeclaration(
                    baseName: 'int',
                    isNullable: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(
      code,
      contains(
        'func doit(foo fooArg: Int64?, completion: @escaping (Result<Void, PigeonError>) -> Void)',
      ),
    );
  });

  test('nonnull fields', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: '',
                ),
              ],
              returnType: const TypeDeclaration.voidDeclaration(),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(
                baseName: 'String',
                isNullable: false,
              ),
              name: 'input',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('var input: String\n'));
  });

  test('transfers documentation comments', () {
    final List<String> comments = <String>[
      ' api comment',
      ' api method comment',
      ' class comment',
      ' class field comment',
      ' enum comment',
      ' enum member comment',
    ];
    int count = 0;

    final List<String> unspacedComments = <String>['////////'];
    int unspacedCount = 0;

    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'api',
          documentationComments: <String>[comments[count++]],
          methods: <Method>[
            Method(
              name: 'method',
              location: ApiLocation.flutter,
              returnType: const TypeDeclaration.voidDeclaration(),
              documentationComments: <String>[comments[count++]],
              parameters: <Parameter>[
                Parameter(
                  name: 'field',
                  type: const TypeDeclaration(
                    baseName: 'int',
                    isNullable: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'class',
          documentationComments: <String>[comments[count++]],
          fields: <NamedType>[
            NamedType(
              documentationComments: <String>[comments[count++]],
              type: const TypeDeclaration(
                baseName: 'Map',
                isNullable: true,
                typeArguments: <TypeDeclaration>[
                  TypeDeclaration(baseName: 'String', isNullable: true),
                  TypeDeclaration(baseName: 'int', isNullable: true),
                ],
              ),
              name: 'field1',
            ),
          ],
        ),
      ],
      enums: <Enum>[
        Enum(
          name: 'enum',
          documentationComments: <String>[
            comments[count++],
            unspacedComments[unspacedCount++],
          ],
          members: <EnumMember>[
            EnumMember(
              name: 'one',
              documentationComments: <String>[comments[count++]],
            ),
            EnumMember(name: 'two'),
          ],
        ),
      ],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    for (final String comment in comments) {
      expect(code, contains('///$comment'));
    }
    expect(code, contains('/// ///'));
  });

  test('creates custom codecs', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.flutter,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: '',
                ),
              ],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
              isAsynchronous: true,
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains(': FlutterStandardReader '));
  });

  test('swift function signature', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'set',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  type: const TypeDeclaration(
                    baseName: 'int',
                    isNullable: false,
                  ),
                  name: 'value',
                ),
                Parameter(
                  type: const TypeDeclaration(
                    baseName: 'String',
                    isNullable: false,
                  ),
                  name: 'key',
                ),
              ],
              swiftFunction: 'setValue(_:for:)',
              returnType: const TypeDeclaration.voidDeclaration(),
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func setValue(_ value: Int64, for key: String)'));
  });

  test('swift function signature with same name argument', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'set',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  type: const TypeDeclaration(
                    baseName: 'String',
                    isNullable: false,
                  ),
                  name: 'key',
                ),
              ],
              swiftFunction: 'removeValue(key:)',
              returnType: const TypeDeclaration.voidDeclaration(),
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func removeValue(key: String)'));
  });

  test('swift function signature with no arguments', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'clear',
              location: ApiLocation.host,
              parameters: <Parameter>[],
              swiftFunction: 'removeAll()',
              returnType: const TypeDeclaration.voidDeclaration(),
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions swiftOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      swiftOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(code, contains('func removeAll()'));
  });

  test('connection error contains channel name', () {
    final Root root = Root(
      apis: <Api>[
        AstFlutterApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'method',
              location: ApiLocation.flutter,
              returnType: const TypeDeclaration.voidDeclaration(),
              parameters: <Parameter>[
                Parameter(
                  name: 'field',
                  type: const TypeDeclaration(
                    baseName: 'int',
                    isNullable: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      classes: <Class>[],
      enums: <Enum>[],
      containsFlutterApi: true,
    );
    final StringBuffer sink = StringBuffer();
    const InternalSwiftOptions kotlinOptions = InternalSwiftOptions(
      swiftOut: '',
    );
    const SwiftGenerator generator = SwiftGenerator();
    generator.generate(
      kotlinOptions,
      root,
      sink,
      dartPackageName: DEFAULT_PACKAGE_NAME,
    );
    final String code = sink.toString();
    expect(
      code,
      contains(
        'completion(.failure(createConnectionError(withChannelName: channelName)))',
      ),
    );
    expect(
      code,
      contains(
        'return PigeonError(code: "channel-error", message: "Unable to establish connection on channel: \'\\(channelName)\'.", details: "")',
      ),
    );
  });

  group('generateJson', () {
    TypeDeclaration td(
      String name, {
      bool nullable = false,
      List<TypeDeclaration> args = const <TypeDeclaration>[],
      Enum? associatedEnum,
      Class? associatedClass,
    }) => TypeDeclaration(
      baseName: name,
      isNullable: nullable,
      typeArguments: args,
      associatedEnum: associatedEnum,
      associatedClass: associatedClass,
    );

    final Enum season = Enum(
      name: 'Season',
      members: <EnumMember>[
        EnumMember(name: 'spring'),
        EnumMember(name: 'readyToPlay'),
      ],
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
        NamedType(
          name: 'tags',
          type: td('List', args: <TypeDeclaration>[td('String')]),
        ),
        NamedType(
          name: 'scores',
          type: td('Map', args: <TypeDeclaration>[td('int'), td('double')]),
        ),
        NamedType(name: 'avatar', type: td('Uint8List')),
      ],
    );
    final Class gameScore = Class(
      name: 'GameScore',
      fields: <NamedType>[],
      isSealed: true,
    );
    final Class shakeGameScore = Class(
      name: 'ShakeGameScore',
      superClassName: 'GameScore',
      superClass: gameScore,
      fields: <NamedType>[NamedType(name: 'shakes', type: td('int'))],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[person, address, gameScore, shakeGameScore],
      enums: <Enum>[season],
    );

    String generate({bool generateJson = true}) {
      final StringBuffer sink = StringBuffer();
      const SwiftGenerator().generate(
        InternalSwiftOptions(swiftOut: 'Api.swift', generateJson: generateJson),
        root,
        sink,
        dartPackageName: DEFAULT_PACKAGE_NAME,
      );
      return sink.toString();
    }

    test('emits shared helpers when enabled', () {
      final String code = generate();
      expect(
        code,
        contains('private func pigeonJsonEncode(_ value: Any?) -> Any {'),
      );
      expect(
        code,
        contains('private func pigeonJsonDecode(_ value: Any?) -> Any? {'),
      );
    });

    test('emits nothing JSON-related when disabled', () {
      final String code = generate(generateJson: false);
      expect(code, isNot(contains('pigeonJsonEncode')));
      expect(code, isNot(contains('func toJsonValue()')));
      expect(code, isNot(contains('func toJson() -> [String: Any?]')));
    });

    test('encodes enums by their Dart constant name', () {
      final String code = generate();
      expect(code, contains('extension Season {'));
      expect(code, contains('func toJsonValue() -> String {'));
      expect(code, contains('case .readyToPlay: return "readyToPlay"'));
      expect(code, contains('case "readyToPlay": return .readyToPlay'));
      expect(
        code,
        contains('static func fromJsonValue(_ value: String) -> Season {'),
      );
    });

    test('concrete class toJson maps each field', () {
      final String code = generate();
      expect(code, contains('extension Person {'));
      expect(code, contains('func toJson() -> [String: Any?] {'));
      expect(code, contains('"name": self.name,'));
      expect(code, contains('"season": self.season.toJsonValue(),'));
      expect(code, contains('"address": self.address.toJson(),'));
      expect(code, contains('func toJsonString() -> String? {'));
      expect(
        code,
        contains(
          'guard let data = try? JSONSerialization.data(withJSONObject: '
          'pigeonJsonEncode(self.toJson())) else { return nil }',
        ),
      );
      expect(code, contains('return String(data: data, encoding: .utf8)'));
    });

    test('fromJson coerces number types and recurses', () {
      final String code = generate();
      expect(
        code,
        contains('static func fromJson(_ pigeonMap: [String: Any?]) -> Person {'),
      );
      expect(
        code,
        contains('age: ((pigeonMap["age"] ?? nil) as! NSNumber).int64Value'),
      );
      expect(
        code,
        contains(
          'season: Season.fromJsonValue((pigeonMap["season"] ?? nil) as! String)',
        ),
      );
      expect(
        code,
        contains(
          'address: Address.fromJson((pigeonMap["address"] ?? nil) as! [String: Any?])',
        ),
      );
      expect(
        code,
        contains('static func fromJsonString(_ json: String) -> Person? {'),
      );
      expect(
        code,
        contains('let pigeonMap = pigeonJsonDecode(object) as? [String: Any?]'),
      );
    });

    test('nullable field always writes the key and null-guards decode', () {
      final String code = generate();
      expect(code, contains('"height": self.height,'));
      expect(
        code,
        contains(
          'height: (pigeonMap["height"] ?? nil).map { p0 in (p0 as! NSNumber).doubleValue }',
        ),
      );
    });

    test('Map keys are stringified', () {
      final String code = generate();
      expect(
        code,
        contains(
          '"scores": Dictionary(uniqueKeysWithValues: self.scores.map '
          '{ p0 in (String(describing: p0.key), p0.value as Any?) }),',
        ),
      );
      expect(
        code,
        contains(
          'scores: Dictionary(uniqueKeysWithValues: '
          '((pigeonMap["scores"] ?? nil) as! [String: Any?]).map '
          '{ p0 in (Int64(p0.key)!, (p0.value as! NSNumber).doubleValue) })',
        ),
      );
    });

    test('List of primitives passes through', () {
      final String code = generate();
      expect(code, contains('"tags": self.tags,'));
      expect(
        code,
        contains(
          'tags: ((pigeonMap["tags"] ?? nil) as! [Any?]).map { p0 in p0 as! String }',
        ),
      );
    });

    test('Uint8List encoded as base64', () {
      final String code = generate();
      expect(
        code,
        contains('"avatar": self.avatar.data.base64EncodedString(),'),
      );
      expect(
        code,
        contains(
          'avatar: FlutterStandardTypedData(bytes: '
          'Data(base64Encoded: (pigeonMap["avatar"] ?? nil) as! String)!)',
        ),
      );
    });

    test('sealed hierarchy uses a type discriminator and dispatches', () {
      final String code = generate();
      expect(code, contains('extension GameScore {'));
      expect(
        code,
        contains('case let value as ShakeGameScore: return value.toJson()'),
      );
      expect(code, contains('"type": "ShakeGameScore",'));
      expect(
        code,
        contains(
          'static func fromJson(_ pigeonMap: [String: Any?]) -> GameScore? {',
        ),
      );
      expect(
        code,
        contains('switch (pigeonMap["type"] ?? nil) as? String {'),
      );
      expect(
        code,
        contains('case "ShakeGameScore": return ShakeGameScore.fromJson(pigeonMap)'),
      );
    });
  });

  group('generateJson type matrix', () {
    TypeDeclaration td(
      String name, {
      bool nullable = false,
      List<TypeDeclaration> args = const <TypeDeclaration>[],
      Enum? associatedEnum,
      Class? associatedClass,
    }) => TypeDeclaration(
      baseName: name,
      isNullable: nullable,
      typeArguments: args,
      associatedEnum: associatedEnum,
      associatedClass: associatedClass,
    );

    final Enum e = Enum(
      name: 'E',
      members: <EnumMember>[EnumMember(name: 'a'), EnumMember(name: 'bTwo')],
    );
    final Class inner = Class(
      name: 'Inner',
      fields: <NamedType>[NamedType(name: 'x', type: td('int'))],
    );
    final Class base = Class(
      name: 'Base',
      fields: <NamedType>[],
      isSealed: true,
    );
    final Class subA = Class(
      name: 'SubA',
      superClassName: 'Base',
      superClass: base,
      fields: <NamedType>[NamedType(name: 'a', type: td('int'))],
    );
    final Class subB = Class(
      name: 'SubB',
      superClassName: 'Base',
      superClass: base,
      fields: <NamedType>[NamedType(name: 'b', type: td('String'))],
    );

    TypeDeclaration listOf(TypeDeclaration x) =>
        td('List', args: <TypeDeclaration>[x]);
    TypeDeclaration mapOf(TypeDeclaration k, TypeDeclaration v) =>
        td('Map', args: <TypeDeclaration>[k, v]);

    final Class kitchen = Class(
      name: 'Kitchen',
      fields: <NamedType>[
        NamedType(name: 'flag', type: td('bool')),
        NamedType(name: 'anything', type: td('Object')),
        NamedType(
          name: 'nEnum',
          type: td('E', nullable: true, associatedEnum: e),
        ),
        NamedType(
          name: 'nInner',
          type: td('Inner', nullable: true, associatedClass: inner),
        ),
        NamedType(name: 'nBytes', type: td('Uint8List', nullable: true)),
        NamedType(name: 'enumList', type: listOf(td('E', associatedEnum: e))),
        NamedType(
          name: 'classList',
          type: listOf(td('Inner', associatedClass: inner)),
        ),
        NamedType(name: 'nElemList', type: listOf(td('String', nullable: true))),
        NamedType(
          name: 'nClassElemList',
          type: listOf(td('Inner', nullable: true, associatedClass: inner)),
        ),
        NamedType(
          name: 'enumKeyMap',
          type: mapOf(td('E', associatedEnum: e), td('int')),
        ),
        NamedType(
          name: 'classValMap',
          type: mapOf(td('String'), td('Inner', associatedClass: inner)),
        ),
        NamedType(
          name: 'nValMap',
          type: mapOf(td('String'), td('int', nullable: true)),
        ),
        NamedType(name: 'nestedList', type: listOf(listOf(td('int')))),
        NamedType(
          name: 'mapOfList',
          type: mapOf(td('String'), listOf(td('int'))),
        ),
        NamedType(name: 'single', type: td('Base', associatedClass: base)),
        NamedType(
          name: 'polyList',
          type: listOf(td('Base', nullable: true, associatedClass: base)),
        ),
        NamedType(name: 'i32', type: td('Int32List')),
        NamedType(name: 'i64', type: td('Int64List')),
        NamedType(name: 'f64', type: td('Float64List')),
        NamedType(name: 'nI32', type: td('Int32List', nullable: true)),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[kitchen, inner, base, subA, subB],
      enums: <Enum>[e],
    );

    late final String code;
    setUpAll(() {
      final StringBuffer sink = StringBuffer();
      const SwiftGenerator().generate(
        const InternalSwiftOptions(swiftOut: 'Api.swift', generateJson: true),
        root,
        sink,
        dartPackageName: DEFAULT_PACKAGE_NAME,
      );
      code = sink.toString();
    });

    test('bool and Object pass through', () {
      expect(code, contains('"flag": self.flag,'));
      expect(code, contains('flag: (pigeonMap["flag"] ?? nil) as! Bool'));
      expect(code, contains('"anything": self.anything,'));
      expect(code, contains('anything: (pigeonMap["anything"] ?? nil)!'));
    });

    test('nullable enum/class/bytes null-guard', () {
      expect(code, contains('"nEnum": self.nEnum?.toJsonValue(),'));
      expect(
        code,
        contains(
          'nEnum: (pigeonMap["nEnum"] ?? nil).map { p0 in E.fromJsonValue(p0 as! String) }',
        ),
      );
      expect(
        code,
        contains(
          'nInner: (pigeonMap["nInner"] ?? nil).map '
          '{ p0 in Inner.fromJson(p0 as! [String: Any?]) }',
        ),
      );
      expect(code, contains('"nBytes": self.nBytes?.data.base64EncodedString(),'));
      expect(
        code,
        contains(
          'nBytes: (pigeonMap["nBytes"] ?? nil).map '
          '{ p0 in FlutterStandardTypedData(bytes: Data(base64Encoded: p0 as! String)!) }',
        ),
      );
    });

    test('List of enums and classes recurses per element', () {
      expect(code, contains('"enumList": self.enumList.map { p0 in p0.toJsonValue() },'));
      expect(
        code,
        contains(
          'enumList: ((pigeonMap["enumList"] ?? nil) as! [Any?]).map '
          '{ p0 in E.fromJsonValue(p0 as! String) }',
        ),
      );
      expect(code, contains('"classList": self.classList.map { p0 in p0.toJson() },'));
      expect(
        code,
        contains(
          'classList: ((pigeonMap["classList"] ?? nil) as! [Any?]).map '
          '{ p0 in Inner.fromJson(p0 as! [String: Any?]) }',
        ),
      );
    });

    test('enum map key and class map value', () {
      expect(
        code,
        contains(
          '"enumKeyMap": Dictionary(uniqueKeysWithValues: self.enumKeyMap.map '
          '{ p0 in (p0.key.toJsonValue(), p0.value as Any?) }),',
        ),
      );
      expect(
        code,
        contains(
          'enumKeyMap: Dictionary(uniqueKeysWithValues: '
          '((pigeonMap["enumKeyMap"] ?? nil) as! [String: Any?]).map '
          '{ p0 in (E.fromJsonValue(p0.key), (p0.value as! NSNumber).int64Value) })',
        ),
      );
      expect(
        code,
        contains(
          'classValMap: Dictionary(uniqueKeysWithValues: '
          '((pigeonMap["classValMap"] ?? nil) as! [String: Any?]).map '
          '{ p0 in (p0.key, Inner.fromJson(p0.value as! [String: Any?])) })',
        ),
      );
    });

    test('polymorphic single field dispatches through the sealed base', () {
      expect(code, contains('"single": self.single.toJson(),'));
      expect(
        code,
        contains(
          'single: Base.fromJson((pigeonMap["single"] ?? nil) as! [String: Any?])!',
        ),
      );
    });

    test('sealed base with multiple subclasses is exhaustive', () {
      expect(code, contains('case let value as SubA: return value.toJson()'));
      expect(code, contains('case let value as SubB: return value.toJson()'));
      expect(code, contains('case "SubA": return SubA.fromJson(pigeonMap)'));
      expect(code, contains('case "SubB": return SubB.fromJson(pigeonMap)'));
    });

    test('nested closures use non-shadowing parameter names', () {
      // Nullable element in a list.
      expect(
        code,
        contains(
          'nElemList: ((pigeonMap["nElemList"] ?? nil) as! [Any?]).map '
          '{ p0 in p0.map { p1 in p1 as! String } }',
        ),
      );
      expect(
        code,
        contains(
          'nClassElemList: ((pigeonMap["nClassElemList"] ?? nil) as! [Any?]).map '
          '{ p0 in p0.map { p1 in Inner.fromJson(p1 as! [String: Any?]) } }',
        ),
      );
      // Nullable map value.
      expect(
        code,
        contains(
          'nValMap: Dictionary(uniqueKeysWithValues: '
          '((pigeonMap["nValMap"] ?? nil) as! [String: Any?]).map '
          '{ p0 in (p0.key, p0.value.map { p1 in (p1 as! NSNumber).int64Value }) })',
        ),
      );
      // Nested list.
      expect(
        code,
        contains(
          'nestedList: ((pigeonMap["nestedList"] ?? nil) as! [Any?]).map '
          '{ p0 in (p0 as! [Any?]).map { p1 in (p1 as! NSNumber).int64Value } }',
        ),
      );
      // Map of list.
      expect(
        code,
        contains(
          'mapOfList: Dictionary(uniqueKeysWithValues: '
          '((pigeonMap["mapOfList"] ?? nil) as! [String: Any?]).map '
          '{ p0 in (p0.key, (p0.value as! [Any?]).map { p1 in (p1 as! NSNumber).int64Value }) })',
        ),
      );
      // List of nullable polymorphic base.
      expect(
        code,
        contains(
          'polyList: ((pigeonMap["polyList"] ?? nil) as! [Any?]).map '
          '{ p0 in p0.map { p1 in Base.fromJson(p1 as! [String: Any?])! } }',
        ),
      );
    });

    test('numeric typed-data lists serialize as JSON number arrays', () {
      expect(
        code,
        contains(
          '"i32": self.i32.data.withUnsafeBytes '
          '{ rawBuffer in Array(rawBuffer.bindMemory(to: Int32.self)) },',
        ),
      );
      expect(
        code,
        contains(
          '"i64": self.i64.data.withUnsafeBytes '
          '{ rawBuffer in Array(rawBuffer.bindMemory(to: Int64.self)) },',
        ),
      );
      expect(
        code,
        contains(
          '"f64": self.f64.data.withUnsafeBytes '
          '{ rawBuffer in Array(rawBuffer.bindMemory(to: Double.self)) },',
        ),
      );
      expect(
        code,
        contains(
          '"nI32": self.nI32?.data.withUnsafeBytes '
          '{ rawBuffer in Array(rawBuffer.bindMemory(to: Int32.self)) },',
        ),
      );
      expect(
        code,
        contains(
          'i32: FlutterStandardTypedData(int32: ((pigeonMap["i32"] ?? nil) as! [Any?]).map '
          '{ p0 in (p0 as! NSNumber).int32Value }.withUnsafeBufferPointer '
          '{ buffer in Data(buffer: buffer) })',
        ),
      );
      expect(
        code,
        contains(
          'i64: FlutterStandardTypedData(int64: ((pigeonMap["i64"] ?? nil) as! [Any?]).map '
          '{ p0 in (p0 as! NSNumber).int64Value }.withUnsafeBufferPointer '
          '{ buffer in Data(buffer: buffer) })',
        ),
      );
      expect(
        code,
        contains(
          'f64: FlutterStandardTypedData(float64: ((pigeonMap["f64"] ?? nil) as! [Any?]).map '
          '{ p0 in (p0 as! NSNumber).doubleValue }.withUnsafeBufferPointer '
          '{ buffer in Data(buffer: buffer) })',
        ),
      );
      // Nullable typed-data: null-guarded, inner map non-shadowing (p0 -> p1).
      expect(
        code,
        contains(
          'nI32: (pigeonMap["nI32"] ?? nil).map { p0 in FlutterStandardTypedData(int32: '
          '(p0 as! [Any?]).map { p1 in (p1 as! NSNumber).int32Value }.withUnsafeBufferPointer '
          '{ buffer in Data(buffer: buffer) }) }',
        ),
      );
    });

    test('no closure parameter is shadowed by an inner closure', () {
      // The shadow shapes that Swift's `$0` (or a reused `pN`) would create.
      expect(code, isNot(contains('.map { p0 in p0.map { p0 ')));
      expect(code, isNot(contains('.map { p0 in (p0 as! [Any?]).map { p0 ')));
    });
  });
}
