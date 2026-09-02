// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Fork-specific extension (not part of upstream Pigeon): a models-only
// TypeScript generator. Emits plain-TS interfaces + hand-written validating
// `toJson`/`fromJson` (zero runtime deps) matching the shared JSON contract.

import '../ast.dart';
import '../generator.dart';
import '../generator_tools.dart';
import 'typescript_emitter.dart';

/// Options that control how TypeScript code will be generated.
class TypeScriptOptions {
  /// Creates a [TypeScriptOptions] object.
  const TypeScriptOptions({this.copyrightHeader});

  /// A copyright header that will get prepended to generated code.
  final Iterable<String>? copyrightHeader;

  /// Creates a [TypeScriptOptions] from a Map representation where:
  /// `x = TypeScriptOptions.fromMap(x.toMap())`.
  static TypeScriptOptions fromMap(Map<String, Object> map) {
    return TypeScriptOptions(
      copyrightHeader: map['copyrightHeader'] as Iterable<String>?,
    );
  }

  /// Converts a [TypeScriptOptions] to a Map representation where:
  /// `x = TypeScriptOptions.fromMap(x.toMap())`.
  Map<String, Object> toMap() {
    return <String, Object>{
      if (copyrightHeader != null) 'copyrightHeader': copyrightHeader!,
    };
  }

  /// Overrides any non-null parameters from [options] into this to make a new
  /// [TypeScriptOptions].
  TypeScriptOptions merge(TypeScriptOptions options) {
    return TypeScriptOptions.fromMap(mergeMaps(toMap(), options.toMap()));
  }
}

/// The internal options used by the TypeScript generator.
class InternalTypeScriptOptions extends InternalOptions {
  /// Creates an [InternalTypeScriptOptions] object.
  const InternalTypeScriptOptions({
    required this.typescriptOut,
    this.copyrightHeader,
  });

  /// Creates [InternalTypeScriptOptions] from [TypeScriptOptions].
  InternalTypeScriptOptions.fromTypeScriptOptions(
    TypeScriptOptions options, {
    required this.typescriptOut,
    Iterable<String>? copyrightHeader,
  }) : copyrightHeader = options.copyrightHeader ?? copyrightHeader;

  /// Path to the TypeScript file that will be generated.
  final String typescriptOut;

  /// A copyright header that will get prepended to generated code.
  final Iterable<String>? copyrightHeader;
}

/// A [Generator] that emits models-only TypeScript.
class TypeScriptGenerator extends Generator<InternalTypeScriptOptions> {
  /// Constructor.
  const TypeScriptGenerator();

  @override
  void generate(
    InternalTypeScriptOptions generatorOptions,
    Root root,
    StringSink sink, {
    required String dartPackageName,
  }) {
    final Indent indent = Indent(sink);
    writeTypeScript(generatorOptions, root, indent);
  }
}
