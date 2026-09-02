# Pigeon fork — scope & rebase playbook

This is a **fork** of `flutter/packages` `pigeon`, maintained by CapsApps-ZP and
consumed by the `capsapps-zappka-flutter-module` plugin via a git ref
(`pigeon: git: … ref: pigeon/json_serialization`).

The whole fork is a set of **additive patches on top of upstream**. The
overriding constraint for every change is: **keep future rebases onto upstream
cheap** — new logic lives in new files; existing files get only small, additive,
off-by-default touches. Document fork changes **here**, not in `CHANGELOG.md`
(see "Deliberately not changed" below).

The fork's changes, foundational → newest (all authored on this repo; `git log
--author=toma -- packages/pigeon`):

## 1. Public generated types (the original reason for the fork)

The consuming app is a Flutter module embedded in a client's native app, so the
client must be able to **construct and read the generated model types across the
module boundary** — i.e. they must be `public`.

- **Swift** — the fork added a **`accessLevel`** option (`SwiftOptions.accessLevel`,
  values `'public'`/`'private'`/null). It prefixes generated `struct`/`class`
  declarations with the access modifier and emits **explicit `public`
  initializers** for structs. The module sets `SwiftOptions(accessLevel: 'public')`
  in its `@ConfigurePigeon`. (Commit: `[pigeon] Add accessLevel option for Swift
  generator`.) NOTE: upstream pigeon may also carry an `accessLevel` option now —
  on rebase, if it does, the option merges; only the fork's application details
  (e.g. the public struct initializers) may need re-checking.
- **Kotlin** — generated classes are **`public` by Kotlin's default** (no
  modifier), so no fork change was needed there.

## 2. Analyzer / SDK version management (production compatibility)

The fork periodically pins/adjusts the `analyzer` (and related meta/SDK/Flutter)
constraints for production compatibility — see the `analyzer`/`meta`/SDK commits.
**These are currently REVERTED on the `pigeon/json_serialization` branch** (this
branch tracks upstream's analyzer constraint so the JSON work builds against a
stock toolchain). Treat analyzer pinning as a **separate, branch-dependent fork
concern**: verify with the maintainer whether a given branch should carry the pin
before (re)applying it on rebase. Do NOT silently re-pin.

## 3. `generateJson` — JSON serialization on data classes

Opt-in `toJson`/`fromJson` (plus `toJsonString`/`fromJsonString`) on generated
**data classes** for Kotlin, Swift, and Dart, gated by a `generateJson` option
(default `false`, so with it off the output is byte-identical to upstream). The
models are the single source of truth for a contract that also lives as
superstruct TS models on a backend, so the emitted JSON must match that shape.

### JSON contract (identical across Kotlin/Swift/Dart)

| Element                               | Representation                                                                                                                         |
|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Map keys                              | Dart field name, verbatim                                                                                                              |
| `int`/`double`                        | JSON number                                                                                                                            |
| enum                                  | the **Dart constant name** string (Kotlin uppercases its enum consts, so its emitter maps explicitly; Dart `.name`, Swift `case` name) |
| `List<T>`                             | array (elements recursed)                                                                                                              |
| `Map<K,V>`                            | object; **keys always stringified**; values recursed                                                                                   |
| `T?` nullable                         | key **always present**, `null` when absent                                                                                             |
| `Uint8List`                           | base64 string                                                                                                                          |
| `Int32List`/`Int64List`/`Float64List` | JSON array of numbers                                                                                                                  |
| nested class                          | nested object (its `toJson`)                                                                                                           |
| sealed hierarchy                      | `"type"` discriminator = the Pigeon class name; base dispatches on it                                                                  |

### New files — replay as-is on rebase, never conflict
- `lib/src/kotlin/kotlin_json.dart`, `lib/src/swift/swift_json.dart`,
  `lib/src/dart/dart_json.dart` — the three emitters (self-contained).
- `pigeons/json_kitchen.dart` — exhaustive "kitchen-sink" contract (test-only).
- Round-trip tests:
  `platform_tests/test_plugin/android/src/test/kotlin/com/example/test_plugin/JsonKitchenRoundtripTest.kt`,
  `platform_tests/test_plugin/example/ios/RunnerTests/JsonKitchenRoundtripTests.swift`,
  `platform_tests/shared_test_plugin_code/test/json_kitchen_roundtrip_test.dart`,
  plus the committed Dart golden
  `platform_tests/shared_test_plugin_code/lib/src/generated/json_kitchen.gen.dart`
  (the Kotlin/Swift `JsonKitchen.gen.*` are gitignored and regenerated).

### Additive edits to existing files — the ONLY conflict-prone spots (all small)
- **`generateJson` option** on `KotlinOptions`/`SwiftOptions`/`DartOptions` and
  their `Internal*` variants (constructor param, field, `fromMap`/`fromList`,
  `toMap`, `fromXxxOptions`), default `false`.
- **Generator hooks** (each gated on `generateJson`):
  - `kotlin_generator.dart`: `import 'kotlin_json.dart';`, two conditional
    `org.json` imports, a `writeDataClasses` override calling `writeKotlinJson`.
  - `swift_generator.dart`: import + a `writeDataClasses` override calling `writeSwiftJson`.
  - `dart_generator.dart`: `import 'dart_json.dart';`, a conditional `dart:convert`
    import, a conditional second `// ignore_for_file:` line, and two
    `writeDartClassJson` calls in `writeDataClass` (one before the empty-class
    early-return for sealed bases, one after equality for concrete classes).
- `tool/shared/generation.dart`: `kotlinGenerateJson`/`swiftGenerateJson`/
  `dartGenerateJson` params on `runPigeon`, and three `json_kitchen` arms at the
  end of `generateTestPigeons`.
- `platform_tests/test_plugin/android/build.gradle`:
  `testImplementation("org.json:json:…")` for the Kotlin kitchen test.
- Unit tests: a `generateJson` group (plus a type-matrix group for Kotlin) in
  `test/{kotlin,swift,dart}_generator_test.dart`.

## 4. `copyWith` — ergonomic copies on data classes

Opt-in `copyWith` on generated **Dart** data classes, gated by a `copyWith`
option (default `false`, so with it off the output is byte-identical to
upstream). Dart-only: Kotlin data classes already have a native `copy()`, and
Swift is handled separately. Pigeon's Dart fields are mutable, so this is
ergonomic sugar, not a necessity.

Each concrete class with fields gets `ClassName copyWith({...})` returning a new
instance. A **non-nullable** field takes a nullable parameter and falls back to
the current value (`field ?? this.field`). A **nullable** field uses a
file-level sentinel default so all three cases are expressible: omit the
argument to keep the current value, pass `null` to clear it, pass a value to set
it. Sealed bases and empty classes are skipped (concrete subclasses get their
own `copyWith`).

### New file — replay as-is on rebase, never conflict
- `lib/src/dart/dart_copywith.dart` — the emitter (self-contained). Emits the
  per-class `copyWith`, plus `rootNeedsCopyWithSentinel`/`writeCopyWithSentinel`
  for the single file-level `const Object _pigeonCopyWithSentinel = Object();`
  (emitted only when some class has a nullable field, so no unused element). No
  extra `ignore_for_file` line needed — `avoid_as` is already covered.

### Additive edits to existing files — the ONLY conflict-prone spots (all small)
- **`copyWith` option** on `DartOptions`/`InternalDartOptions` (constructor
  param, field, `fromMap`/`toMap`, `fromDartOptions`), default `false`.
- **`dart_generator.dart`**: `import 'dart_copywith.dart';`, a gated sentinel
  emit in `writeGeneralUtilities`, and a gated `writeDartClassCopyWith` call in
  `writeDataClass` (after equality, `copyWith && !classDefinition.isSealed`).
- `tool/shared/generation.dart`: a `dartCopyWith` param on `runPigeon` (→
  `DartOptions.copyWith`), and `dartCopyWith: true` on the Dart `json_kitchen`
  arm (so the committed Dart golden also exercises `copyWith`).
- Unit tests: a `copyWith` group in `test/dart_generator_test.dart`; a
  `copyWith` group in the Dart kitchen round-trip test.

## 5. TypeScript generator — models-only, zero-dependency

A **new first-class language** for this fork (upstream Pigeon has no TypeScript
generator). Unlike §1–§4, which patch existing generators, this adds a whole
generator — but still additive and models-only. It emits **plain-TS interfaces
plus hand-written, validating `toJson`/`fromJson`** (and `*String` variants)
from the same contract as the other languages, with **no third-party runtime
dependency** in the output. It generates the TS side of the shared JSON contract
that §3's `generateJson` targets (previously hand-maintained as superstruct
models on the backend).

Configured like any other language:
`PigeonOptions(typescriptOut: 'gen/foo.ts', typescriptOptions: TypeScriptOptions())`.
The generator extends `Generator<InternalTypeScriptOptions>` **directly** (not
`StructuredGenerator`), since it emits only enums + data classes (no host/flutter
APIs, codecs, or proxies).

### JSON representation (JSON-native: wire == runtime)

Same shared contract as §3, mapped to TypeScript where **the runtime object IS
the wire shape** (no rich `Uint8Array`/`Map` types — deferred as future work):

| Dart                                  | TS runtime                 | notes                                    |
|---------------------------------------|----------------------------|------------------------------------------|
| `int` / `double`                      | `number`                   | `asInt` (integer-checked) / `asNumber`   |
| `String` / `bool`                     | `string` / `boolean`       |                                          |
| `Uint8List`                           | `string`                   | base64                                   |
| `Int32List`/`Int64List`/`Float64List` | `number[]`                 |                                          |
| `List<T>`                             | `T[]`                      |                                          |
| `Map<K,V>`                            | `Record<string, V>`        | keys stringified                         |
| enum                                  | `'a' \| 'b'` string union  | Dart constant names                      |
| sealed hierarchy                      | discriminated union        | `type` = class name, emitted first key   |
| `T?`                                  | `T \| null`                | key always present                       |

- **`fromJson`** validates and throws **`PigeonJsonError`** (fail-fast) on bad
  input, but **tolerates unknown extra keys** — the contract evolves additively,
  so an older generated model must be able to read a newer payload. (This is why
  a strict schema library such as superstruct's `s.object`, which rejects unknown
  keys, would be wrong here.)
- **`toJson`** rebuilds the object in **Dart field-declaration order** (`type`
  first for sealed subclasses), guaranteeing **byte-identical** JSON with
  Kotlin/Swift/Dart.

### New files — replay as-is on rebase, never conflict
- `lib/src/typescript/typescript_generator.dart` — `TypeScriptGenerator` plus
  `TypeScriptOptions` / `InternalTypeScriptOptions`.
- `lib/src/typescript/typescript_emitter.dart` — the emitter (`writeTypeScript`:
  prologue validators → enums → classes → sealed unions).
- `test/typescript_generator_test.dart` — unit tests (**CI gate**).
- `platform_tests/typescript_test/` — local round-trip harness using Node's
  built-in `node:test` (**zero deps**; Node runs the generated `.ts` directly via
  built-in type-stripping — tested on Node 24). Its `gen/*.ts` input is a
  gitignored, regenerated artifact. A **local** integration check, not a CI gate.

### Additive edits to existing files — the ONLY conflict-prone spots (all small)
- **`PigeonOptions`** (`lib/src/pigeon_lib.dart`): `typescriptOut` +
  `typescriptOptions` (constructor, fields, `fromMap`/`toMap`); a
  `typescript/typescript_generator.dart` import; and `TypeScriptGeneratorAdapter()`
  in the default adapter list (right after `KotlinGeneratorAdapter()`).
- **`InternalPigeonOptions`** (`lib/src/pigeon_lib_internal.dart`): a
  `typescriptOptions` field + a merge block (mirrors the `kotlinOptions` block);
  the `TypeScriptGeneratorAdapter` class (mirrors `KotlinGeneratorAdapter`); import.
- `lib/pigeon.dart`: `export 'src/typescript/typescript_generator.dart' show TypeScriptOptions;`.
- `tool/shared/generation.dart`: a `typescriptOut` param on `runPigeon`, and a
  `json_kitchen` TypeScript arm emitting the gitignored
  `platform_tests/typescript_test/gen/json_kitchen.gen.ts`.

### Verify
- `dart analyze lib`
- `dart test test/typescript_generator_test.dart`
- local round-trip: `cd platform_tests/typescript_test && node --test` (regenerate
  its input via the `json_kitchen` TS arm; needs a recent Node for built-in `.ts`
  type-stripping).

## Deliberately NOT changed (avoids guaranteed recurring rebase conflicts)
`pubspec.yaml` `version`, `lib/src/generator_tools.dart` `pigeonVersion`, and
`CHANGELOG.md` are left at upstream values. The fork is consumed by git ref, so
the version number is irrelevant, and `version_test` stays green because both
values are untouched. Fork changes are documented in THIS file instead.

## Rebase playbook
1. Rebase the fork onto real `flutter/packages` upstream. (Note: the local
   `origin`/`upstream` remotes both point at the CapsApps fork — add the real
   `flutter/packages` remote to rebase against it.)
2. New files apply cleanly. Resolve conflicts only in the additive spots above —
   re-apply the additions, keep upstream's surrounding code. Do **not** re-add
   version/CHANGELOG bumps. For the analyzer pin, confirm intent first (§2).
3. Verify:
   - `dart analyze lib`
   - `dart test test/kotlin_generator_test.dart test/swift_generator_test.dart test/dart_generator_test.dart`
   - regenerate kitchen goldens: `dart run tool/generate.dart --files=test`
   - Dart kitchen round-trip (no native toolchain):
     `cd platform_tests/shared_test_plugin_code && flutter test test/json_kitchen_roundtrip_test.dart`
   - Kotlin/Swift kitchen round-trips via the native harness when the local
     toolchain matches (these are **local** package-integration checks, not CI gates).

## Notes
- The kitchen-sink is a stable, exhaustive contract that drifts only with the
  emitter's capabilities — the place to add a case when the emitter learns a new type.
- Kitchen tests are LOCAL package-integration tests, not CI gates.
