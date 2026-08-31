// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Exhaustive round-trip test for the fork-specific `generateJson` emitter,
// driven by the kitchen-sink contract (pigeons/json_kitchen.dart). It compiles
// the generated toJson/fromJson (json_kitchen.gen.dart) and asserts
// fromJson(toJson(x)) == x across every JSON-relevant type configuration —
// numeric typed-data lists, nested collections, enum/class map keys & values,
// deeply-nested nullables, and polymorphic sealed fields. Equality uses the
// generated value-based `==` (deep comparison of the encoded lists), so a
// swapped/dropped/mis-typed field fails the round-trip.
//
// This runs as a plain `flutter test` — no gradle/Xcode toolchain needed.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_test_plugin_code/src/generated/json_kitchen.gen.dart';

void main() {
  test('KsAll fully populated round-trips through the string form', () {
    final KsAll x = _makeKsAll();
    expect(KsAll.fromJsonString(x.toJsonString()), x);
  });

  test('KsAll with null nullables round-trips through the string form', () {
    final KsAll x = _makeKsAllNulls();
    expect(KsAll.fromJsonString(x.toJsonString()), x);
  });

  test('KsAll round-trips through the map form', () {
    expect(KsAll.fromJson(_makeKsAll().toJson()), _makeKsAll());
    expect(KsAll.fromJson(_makeKsAllNulls().toJson()), _makeKsAllNulls());
  });

  test('KsShape polymorphic round-trips through the sealed base decoder', () {
    final KsShape circle = KsCircle(radius: 3.25);
    final KsShape square = KsSquare(side: 8);
    expect(KsShape.fromJsonString(circle.toJsonString()), circle);
    expect(KsShape.fromJsonString(square.toJsonString()), square);
  });
}

KsAll _makeKsAll() => KsAll(
  i: 1,
  d: 2.5,
  s: 'three',
  b: true,
  bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
  i32: Int32List.fromList(<int>[10, 20, 30]),
  i64: Int64List.fromList(<int>[100, 200]),
  f64: Float64List.fromList(<double>[1.5, 2.5, 3.5]),
  e: KsEnum.betaTwo,
  inner: KsInner(value: 11),
  intList: <int>[1, 2, 3],
  strList: <String>['a', 'b'],
  strIntMap: <String, int>{'x': 1, 'y': 2},
  intDoubleMap: <int, double>{1: 1.1, 2: 2.2},
  nestedInts: <List<int>>[
    <int>[1, 2],
    <int>[3],
  ],
  mapOfLists: <String, List<int>>{
    'p': <int>[1, 2],
    'q': <int>[3],
  },
  enumList: <KsEnum>[KsEnum.alpha, KsEnum.betaTwo],
  innerList: <KsInner>[KsInner(value: 21), KsInner(value: 22)],
  enumKeyMap: <KsEnum, int>{KsEnum.alpha: 1, KsEnum.betaTwo: 2},
  innerValMap: <String, KsInner>{'m': KsInner(value: 31)},
  shape: KsCircle(radius: 9.9),
  shapes: <KsShape>[KsCircle(radius: 1.0), KsSquare(side: 5)],
  nInt: 42,
  nStr: 'notnull',
  nEnum: KsEnum.alpha,
  nInner: KsInner(value: 51),
  nBytes: Uint8List.fromList(<int>[9, 8, 7]),
  nStrList: <String>['s1', 's2'],
  nMap: <String, int>{'k': 9},
  nInnerElemList: <KsInner?>[KsInner(value: 61), null],
  nValMap: <String, int?>{'a': 1, 'b': null},
  nShape: KsSquare(side: 3),
);

KsAll _makeKsAllNulls() => KsAll(
  i: 1,
  d: 2.5,
  s: 'three',
  b: false,
  bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
  i32: Int32List.fromList(<int>[10, 20, 30]),
  i64: Int64List.fromList(<int>[100, 200]),
  f64: Float64List.fromList(<double>[1.5, 2.5, 3.5]),
  e: KsEnum.alpha,
  inner: KsInner(value: 11),
  intList: <int>[1, 2, 3],
  strList: <String>['a', 'b'],
  strIntMap: <String, int>{'x': 1, 'y': 2},
  intDoubleMap: <int, double>{1: 1.1, 2: 2.2},
  nestedInts: <List<int>>[
    <int>[1, 2],
    <int>[3],
  ],
  mapOfLists: <String, List<int>>{
    'p': <int>[1, 2],
    'q': <int>[3],
  },
  enumList: <KsEnum>[KsEnum.alpha, KsEnum.betaTwo],
  innerList: <KsInner>[KsInner(value: 21), KsInner(value: 22)],
  enumKeyMap: <KsEnum, int>{KsEnum.alpha: 1, KsEnum.betaTwo: 2},
  innerValMap: <String, KsInner>{'m': KsInner(value: 31)},
  shape: KsSquare(side: 7),
  shapes: <KsShape>[KsCircle(radius: 1.0), KsSquare(side: 5)],
  nInt: null,
  nStr: null,
  nEnum: null,
  nInner: null,
  nBytes: null,
  nStrList: null,
  nMap: null,
  nInnerElemList: <KsInner?>[null, null],
  nValMap: <String, int?>{'a': null},
  nShape: null,
);
