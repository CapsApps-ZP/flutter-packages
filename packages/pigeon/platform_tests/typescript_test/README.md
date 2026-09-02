# TypeScript kitchen round-trip test (local, not CI)

Round-trip + validator harness for the generated TypeScript "kitchen sink"
models (`ksAll*`, `ksShape*`, …), mirroring the Kotlin/Swift/Dart kitchen
round-trip tests documented in `../../CLAUDE.md`. Like those, this is a
**local package-integration check, not a CI gate**.

## Zero dependencies

No `npm install`, no `vitest`, no `tsconfig.json`. The test file is plain
ESM (`.mjs`) that imports directly from the generated `.ts` file; Node
(v22.6+, and specifically verified here on **v24.1.0**) strips TypeScript
types on import natively, and the tests run on Node's built-in test runner
(`node:test` + `node:assert/strict`).

## Prerequisites

The generated file must exist. It's produced by the controller (not this
harness) and is gitignored:

```bash
cd ../.. && dart run tool/generate.dart --files=test
```

This writes `gen/json_kitchen.gen.ts` (ignore the format-step's non-zero
exit, if any — see `.gitignore` in this directory).

## Run

From this directory:

```bash
node --test
```

or, to run the file explicitly:

```bash
node --test json_kitchen.roundtrip.test.mjs
```

You'll see an `ExperimentalWarning: Type Stripping is an experimental
feature` note — harmless, expected on Node 24.

## What's covered

- `ksAllToJsonString` → `ksAllFromJsonString` round-trips to a
  fully-populated `KsAll` fixture (deep-equal).
- Nullable keys are present with `null` in `ksAllToJson` output (never
  omitted).
- `ksAllFromJson` tolerates an unknown extra key.
- `ksAllFromJson` throws `PigeonJsonError` on a type-mismatched field.
- `ksShapeFromJson` dispatches sealed types on the `type` discriminator and
  throws `PigeonJsonError` on an unrecognized `type`.

## Deferred: cross-language byte-identity golden

Not implemented here. The original plan (see the task brief) was to also
compare canonicalized `ksAllToJsonString` output against a committed golden
captured from the Dart/Kotlin/Swift kitchen round-trip tests for the same
fixture values, to prove wire-format identity across all four generators.
That requires capturing reference JSON from those native harnesses, which
wasn't done in this pass — follow-up work if byte-identity assurance across
languages is needed beyond the shared "JSON contract" table already in
`../../CLAUDE.md`.
