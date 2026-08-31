// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import XCTest

@testable import test_plugin

// Exhaustive round-trip test for the fork-specific `generateJson` emitter,
// driven by the kitchen-sink contract (pigeons/json_kitchen.dart). It compiles
// the generated toJson/fromJson (JsonKitchen.gen.swift) and asserts
// fromJson(toJson(x)) == x across every JSON-relevant type configuration —
// numeric typed-data lists, nested collections, enum/class map keys & values,
// deeply-nested nullables, and polymorphic sealed fields. This mirrors the
// Kotlin JsonKitchenRoundtripTest so both languages are proven against
// byte-identical JSON.
//
// Equality uses Pigeon's generated `==` (deepEqualsJsonKitchen over toList()),
// which compares FlutterStandardTypedData and nested List/Map by content, so a
// swapped/dropped/mis-typed field fails. No Base64 stubbing is needed on Apple
// platforms: Data.base64EncodedString()/Data(base64Encoded:) are real.
final class JsonKitchenRoundtripTests: XCTestCase {
  /// Re-serializes a JSON string with sorted keys so two encodings can be
  /// compared order-independently (JSONSerialization does not preserve or sort
  /// object key order otherwise).
  private func canonicalJson(_ json: String?) -> Data? {
    guard let json = json,
      let data = json.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data),
      let canonical = try? JSONSerialization.data(
        withJSONObject: object, options: [.sortedKeys])
    else { return nil }
    return canonical
  }

  // KsAll holds sealed-protocol fields (shape/shapes/nShape). Pigeon's generated
  // Swift `==` (deepEquals over toList()) can't compare those: the sealed
  // subtypes KsCircle/KsSquare define `==`/`hash` but do not conform to
  // Hashable, so deepEquals bails to `false` on any KsShape element. So equality
  // is asserted at the JSON level — re-encode both sides with sorted keys and
  // compare bytes, which proves every field survived the round-trip. (The
  // KsShape-only polymorphic test below can still use direct `==`, since that
  // compares concrete KsCircle/KsSquare whose own `==` works.)
  private func assertRoundtrip(_ original: KsAll, _ restored: KsAll?) {
    guard let restored = restored else {
      return XCTFail("round-trip produced nil")
    }
    let expected = canonicalJson(original.toJsonString())
    XCTAssertNotNil(expected, "original produced no JSON")
    XCTAssertEqual(
      canonicalJson(restored.toJsonString()), expected,
      "KsAll JSON round-trip mismatch")
  }

  func testKsAllFullyPopulatedRoundtripsThroughString() throws {
    let x = makeKsAll()
    let json = try XCTUnwrap(x.toJsonString())
    assertRoundtrip(x, KsAll.fromJsonString(json))
  }

  func testKsAllNullablesRoundtripThroughString() throws {
    let x = makeKsAllNulls()
    let json = try XCTUnwrap(x.toJsonString())
    assertRoundtrip(x, KsAll.fromJsonString(json))
  }

  func testKsAllRoundtripsThroughMapForm() {
    // The [String: Any?] map form is the primary contract; the string form is a
    // thin wrapper. Exercise the map form directly too.
    let populated = makeKsAll()
    assertRoundtrip(populated, KsAll.fromJson(populated.toJson()))
    let nulls = makeKsAllNulls()
    assertRoundtrip(nulls, KsAll.fromJson(nulls.toJson()))
  }

  func testKsShapePolymorphicRoundtripsThroughBaseDecoder() throws {
    // Decode via the sealed base so both the "type" discriminator and the
    // per-subtype field mapping are exercised, and the restored runtime type is
    // asserted alongside value equality.
    let circle = KsCircle(radius: 3.25)
    let circleJson = try XCTUnwrap(circle.toJsonString())
    let circleBack = try XCTUnwrap(KsShapeJson.fromJsonString(circleJson) as? KsCircle)
    XCTAssertTrue(circleBack == circle)

    let square = KsSquare(side: 8)
    let squareJson = try XCTUnwrap(square.toJsonString())
    let squareBack = try XCTUnwrap(KsShapeJson.fromJsonString(squareJson) as? KsSquare)
    XCTAssertTrue(squareBack == square)
  }

  // MARK: - Typed-data helpers

  private func bytesTD(_ v: [UInt8]) -> FlutterStandardTypedData {
    FlutterStandardTypedData(bytes: Data(v))
  }

  private func i32TD(_ v: [Int32]) -> FlutterStandardTypedData {
    FlutterStandardTypedData(int32: v.withUnsafeBufferPointer { Data(buffer: $0) })
  }

  private func i64TD(_ v: [Int64]) -> FlutterStandardTypedData {
    FlutterStandardTypedData(int64: v.withUnsafeBufferPointer { Data(buffer: $0) })
  }

  private func f64TD(_ v: [Double]) -> FlutterStandardTypedData {
    FlutterStandardTypedData(float64: v.withUnsafeBufferPointer { Data(buffer: $0) })
  }

  // MARK: - Fixtures (values match the Kotlin JsonKitchenRoundtripTest exactly)

  // Every field gets a distinct, non-default value so a swapped/dropped key
  // fails the round-trip. Collection-of-nullable and map-of-nullable carry a
  // null entry to exercise those paths.
  private func makeKsAll() -> KsAll {
    KsAll(
      i: 1,
      d: 2.5,
      s: "three",
      b: true,
      bytes: bytesTD([1, 2, 3, 4]),
      i32: i32TD([10, 20, 30]),
      i64: i64TD([100, 200]),
      f64: f64TD([1.5, 2.5, 3.5]),
      e: .betaTwo,
      inner: KsInner(value: 11),
      intList: [1, 2, 3],
      strList: ["a", "b"],
      strIntMap: ["x": 1, "y": 2],
      intDoubleMap: [1: 1.1, 2: 2.2],
      nestedInts: [[1, 2], [3]],
      mapOfLists: ["p": [1, 2], "q": [3]],
      enumList: [.alpha, .betaTwo],
      innerList: [KsInner(value: 21), KsInner(value: 22)],
      enumKeyMap: [.alpha: 1, .betaTwo: 2],
      innerValMap: ["m": KsInner(value: 31)],
      shape: KsCircle(radius: 9.9),
      shapes: [KsCircle(radius: 1.0), KsSquare(side: 5)],
      nInt: 42,
      nStr: "notnull",
      nEnum: .alpha,
      nInner: KsInner(value: 51),
      nBytes: bytesTD([9, 8, 7]),
      nStrList: ["s1", "s2"],
      nMap: ["k": 9],
      nInnerElemList: [KsInner(value: 61), nil],
      nValMap: ["a": 1, "b": nil],
      nShape: KsSquare(side: 3)
    )
  }

  private func makeKsAllNulls() -> KsAll {
    KsAll(
      i: 1,
      d: 2.5,
      s: "three",
      b: false,
      bytes: bytesTD([1, 2, 3, 4]),
      i32: i32TD([10, 20, 30]),
      i64: i64TD([100, 200]),
      f64: f64TD([1.5, 2.5, 3.5]),
      e: .alpha,
      inner: KsInner(value: 11),
      intList: [1, 2, 3],
      strList: ["a", "b"],
      strIntMap: ["x": 1, "y": 2],
      intDoubleMap: [1: 1.1, 2: 2.2],
      nestedInts: [[1, 2], [3]],
      mapOfLists: ["p": [1, 2], "q": [3]],
      enumList: [.alpha, .betaTwo],
      innerList: [KsInner(value: 21), KsInner(value: 22)],
      enumKeyMap: [.alpha: 1, .betaTwo: 2],
      innerValMap: ["m": KsInner(value: 31)],
      shape: KsSquare(side: 7),
      shapes: [KsCircle(radius: 1.0), KsSquare(side: 5)],
      nInt: nil,
      nStr: nil,
      nEnum: nil,
      nInner: nil,
      nBytes: nil,
      nStrList: nil,
      nMap: nil,
      nInnerElemList: [nil, nil],
      nValMap: ["a": nil],
      nShape: nil
    )
  }
}
