// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Kitchen-sink contract for the fork-specific `generateJson` emitter. It
// exercises every JSON-relevant type configuration — including shapes the
// real-world contracts do not use (numeric typed-data lists, deeply-nested
// collections, enum/class map keys & values, deeply-nested nullables,
// polymorphic sealed fields) — so the generated Kotlin `toJson`/`fromJson` is
// compiled and round-tripped end-to-end (see the test plugin's
// JsonKitchenRoundtripTest). Generation options (incl. `generateJson`) are set
// programmatically in tool/shared/generation.dart, not here.
//
// All names are prefixed `Ks` to avoid colliding with the other test contracts
// generated into the same `com.example.test_plugin` package.
import 'package:pigeon/pigeon.dart';

/// Enum with a multi-word member to prove Dart-name (not SCREAMING_SNAKE) JSON.
enum KsEnum { alpha, betaTwo }

/// Nested concrete class.
class KsInner {
  KsInner({required this.value});
  final int value;
}

/// Sealed hierarchy → JSON `"type"` discriminator + polymorphic dispatch.
sealed class KsShape {}

class KsCircle extends KsShape {
  KsCircle({required this.radius});
  final double radius;
}

class KsSquare extends KsShape {
  KsSquare({required this.side});
  final int side;
}

/// Every field kind in one class.
class KsAll {
  KsAll({
    required this.i,
    required this.d,
    required this.s,
    required this.b,
    required this.bytes,
    required this.i32,
    required this.i64,
    required this.f64,
    required this.e,
    required this.inner,
    required this.intList,
    required this.strList,
    required this.strIntMap,
    required this.intDoubleMap,
    required this.nestedInts,
    required this.mapOfLists,
    required this.enumList,
    required this.innerList,
    required this.enumKeyMap,
    required this.innerValMap,
    required this.shape,
    required this.shapes,
    this.nInt,
    this.nStr,
    this.nEnum,
    this.nInner,
    this.nBytes,
    this.nStrList,
    this.nMap,
    this.nInnerElemList,
    this.nValMap,
    this.nShape,
  });

  // Scalars.
  final int i;
  final double d;
  final String s;
  final bool b;

  // Typed data: Uint8List -> base64 string; numeric -> JSON number arrays.
  final Uint8List bytes;
  final Int32List i32;
  final Int64List i64;
  final Float64List f64;

  // Enum + nested class.
  final KsEnum e;
  final KsInner inner;

  // Collections.
  final List<int> intList;
  final List<String> strList;
  final Map<String, int> strIntMap;
  final Map<int, double> intDoubleMap;

  // Nested collections.
  final List<List<int>> nestedInts;
  final Map<String, List<int>> mapOfLists;

  // Collections of enums/classes.
  final List<KsEnum> enumList;
  final List<KsInner> innerList;
  final Map<KsEnum, int> enumKeyMap;
  final Map<String, KsInner> innerValMap;

  // Polymorphic (sealed) single + list.
  final KsShape shape;
  final List<KsShape> shapes;

  // Nullable variants.
  final int? nInt;
  final String? nStr;
  final KsEnum? nEnum;
  final KsInner? nInner;
  final Uint8List? nBytes;
  final List<String>? nStrList;
  final Map<String, int>? nMap;
  final List<KsInner?> nInnerElemList;
  final Map<String, int?> nValMap;
  final KsShape? nShape;
}
