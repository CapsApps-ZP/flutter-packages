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

| Element | Representation |
|---|---|
| Map keys | Dart field name, verbatim |
| `int`/`double` | JSON number |
| enum | the **Dart constant name** string (Kotlin uppercases its enum consts, so its emitter maps explicitly; Dart `.name`, Swift `case` name) |
| `List<T>` | array (elements recursed) |
| `Map<K,V>` | object; **keys always stringified**; values recursed |
| `T?` nullable | key **always present**, `null` when absent |
| `Uint8List` | base64 string |
| `Int32List`/`Int64List`/`Float64List` | JSON array of numbers |
| nested class | nested object (its `toJson`) |
| sealed hierarchy | `"type"` discriminator = the Pigeon class name; base dispatches on it |

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
