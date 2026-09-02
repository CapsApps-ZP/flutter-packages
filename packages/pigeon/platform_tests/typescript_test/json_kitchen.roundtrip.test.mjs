// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// Local (not CI) round-trip + validator harness for the generated TypeScript
// "kitchen sink" models — see platform_tests/typescript_test/README.md.
//
// Zero third-party dependencies: runs on Node's built-in test runner
// (`node:test` + `node:assert/strict`), and Node strips the `.ts` file's
// types on import, so no TypeScript/vitest toolchain is installed.
//
// NOTE: the cross-language byte-identity golden (comparing canonicalized
// output against a golden captured from the Dart/Kotlin/Swift kitchen) is
// deliberately NOT implemented here — see README.md "Deferred".

import { describe, test } from 'node:test';
import assert from 'node:assert/strict';

import {
  ksAllFromJson,
  ksAllToJson,
  ksAllToJsonString,
  ksAllFromJsonString,
  ksShapeFromJson,
  PigeonJsonError,
} from './gen/json_kitchen.gen.ts';

// A fully-populated KsAll fixture in the WIRE (JSON-native) shape: base64
// string for bytes, plain arrays for typed-data lists, string-union enum
// values, Record objects for maps, and `{ type: ... }` for sealed shapes.
const ksAll = {
  i: 1, d: 2.5, s: 'x', b: true,
  bytes: 'AQID', // base64
  i32: [1, 2], i64: [3, 4], f64: [1.5, 2.5],
  e: 'betaTwo',
  inner: { value: 7 },
  intList: [1, 2], strList: ['a', 'b'],
  strIntMap: { a: 1 }, intDoubleMap: { '1': 2.5 },
  nestedInts: [[1, 2]], mapOfLists: { a: [1] },
  enumList: ['alpha'], innerList: [{ value: 1 }],
  enumKeyMap: { alpha: 1 }, innerValMap: { a: { value: 2 } },
  shape: { type: 'KsCircle', radius: 1 },
  shapes: [{ type: 'KsSquare', side: 2 }],
  nInt: null, nStr: null, nEnum: null, nInner: null, nBytes: null,
  nStrList: null, nMap: null, nInnerElemList: [null], nValMap: { a: null },
  nShape: null,
};

// The nullable top-level keys of KsAll, all set to null in the fixture above.
const nullableKeys = [
  'nInt', 'nStr', 'nEnum', 'nInner', 'nBytes', 'nStrList', 'nMap', 'nShape',
];

describe('KsAll round-trip', () => {
  test('toJsonString -> fromJsonString -> deep-equal', () => {
    const round = ksAllFromJsonString(ksAllToJsonString(ksAll));
    assert.deepStrictEqual(round, ksAll);
  });

  test('nullable keys are present with null (not omitted)', () => {
    const obj = ksAllToJson(ksAll);
    for (const key of nullableKeys) {
      assert.equal(key in obj, true, `expected key "${key}" to be present`);
      assert.equal(obj[key], null, `expected "${key}" to be null`);
    }
  });

  test('tolerates unknown extra keys', () => {
    const withExtra = { ...ksAllToJson(ksAll), unexpected: 123 };
    assert.doesNotThrow(() => ksAllFromJson(withExtra));
  });

  test('rejects malformed input with PigeonJsonError', () => {
    const badInt = { ...ksAllToJson(ksAll), i: 'nope' };
    assert.throws(() => ksAllFromJson(badInt), PigeonJsonError);
  });

  test('dispatches sealed types on the discriminator', () => {
    assert.deepStrictEqual(
      ksShapeFromJson({ type: 'KsCircle', radius: 3 }),
      { type: 'KsCircle', radius: 3 },
    );
    assert.deepStrictEqual(
      ksShapeFromJson({ type: 'KsSquare', side: 4 }),
      { type: 'KsSquare', side: 4 },
    );
    assert.throws(() => ksShapeFromJson({ type: 'Nope' }), PigeonJsonError);
  });
});
