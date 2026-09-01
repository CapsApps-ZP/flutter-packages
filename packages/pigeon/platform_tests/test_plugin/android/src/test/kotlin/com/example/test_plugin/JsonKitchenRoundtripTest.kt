// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.example.test_plugin

import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

// Exhaustive round-trip test for the fork-specific `generateJson` emitter,
// driven by the kitchen-sink contract (pigeons/json_kitchen.dart). It compiles
// the generated toJson/fromJson (JsonKitchen.gen.kt) and asserts
// fromJson(toJson(x)) == x across every JSON-relevant type configuration —
// numeric typed-data lists, nested collections, enum/class map keys & values,
// deeply-nested nullables, and polymorphic sealed fields. Equality uses the
// generated deepEquals, which compares ByteArray/IntArray/LongArray/DoubleArray
// and nested List/Map by content, so a swapped/dropped/mis-typed field fails.
//
// ByteArray fields go through android.util.Base64, a throwing stub on plain JVM
// unit tests, so its two static methods are bridged to java.util.Base64 (both
// use a no-wrap alphabet, so the bytes match).
internal class JsonKitchenRoundtripTest {
  @Before
  fun bridgeAndroidBase64ToJava() {
    mockkStatic(android.util.Base64::class)
    every { android.util.Base64.encodeToString(any(), any()) } answers
        {
          java.util.Base64.getEncoder().encodeToString(firstArg<ByteArray>())
        }
    every { android.util.Base64.decode(any<String>(), any()) } answers
        {
          java.util.Base64.getDecoder().decode(firstArg<String>())
        }
  }

  @After
  fun releaseBase64() {
    unmockkStatic(android.util.Base64::class)
  }

  private fun assertRoundtrip(original: Any, restored: Any?) {
    assertEquals("round-trip mismatch for ${original::class.simpleName}", original, restored)
    assertEquals(original::class, restored!!::class)
  }

  @Test
  fun ksAll_fullyPopulated_roundtripsThroughString() {
    val x = makeKsAll()
    assertRoundtrip(x, KsAllJson.fromJsonString(x.toJsonString()))
  }

  @Test
  fun ksAll_nullables_roundtripThroughString() {
    val x = makeKsAllNulls()
    assertRoundtrip(x, KsAllJson.fromJsonString(x.toJsonString()))
  }

  @Test
  fun ksAll_roundtripsThroughMapForm() {
    // The Map<String, Any?> form is the primary contract; the string form is a
    // thin wrapper. Exercise the map form directly too.
    makeKsAll().let { assertRoundtrip(it, KsAllJson.fromJson(it.toJson())) }
    makeKsAllNulls().let { assertRoundtrip(it, KsAllJson.fromJson(it.toJson())) }
  }

  @Test
  fun ksShape_polymorphic_roundtripsThroughBaseDecoder() {
    // Decode via the sealed base so both the "type" discriminator and the
    // per-subtype field mapping are exercised.
    KsCircle(radius = 3.25).let { assertRoundtrip(it, KsShapeJson.fromJsonString(it.toJsonString())) }
    KsSquare(side = 8L).let { assertRoundtrip(it, KsShapeJson.fromJsonString(it.toJsonString())) }
  }

  // Every field gets a distinct, non-default value so a swapped/dropped key
  // fails the round-trip. Collection-of-nullable and map-of-nullable carry a
  // null entry to exercise those paths.
  private fun makeKsAll(): KsAll =
      KsAll(
          i = 1L,
          d = 2.5,
          s = "three",
          b = true,
          bytes = byteArrayOf(1, 2, 3, 4),
          i32 = intArrayOf(10, 20, 30),
          i64 = longArrayOf(100L, 200L),
          f64 = doubleArrayOf(1.5, 2.5, 3.5),
          e = KsEnum.BETA_TWO,
          inner = KsInner(value = 11L),
          intList = listOf(1L, 2L, 3L),
          strList = listOf("a", "b"),
          strIntMap = mapOf("x" to 1L, "y" to 2L),
          intDoubleMap = mapOf(1L to 1.1, 2L to 2.2),
          nestedInts = listOf(listOf(1L, 2L), listOf(3L)),
          mapOfLists = mapOf("p" to listOf(1L, 2L), "q" to listOf(3L)),
          enumList = listOf(KsEnum.ALPHA, KsEnum.BETA_TWO),
          innerList = listOf(KsInner(value = 21L), KsInner(value = 22L)),
          enumKeyMap = mapOf(KsEnum.ALPHA to 1L, KsEnum.BETA_TWO to 2L),
          innerValMap = mapOf("m" to KsInner(value = 31L)),
          shape = KsCircle(radius = 9.9),
          shapes = listOf(KsCircle(radius = 1.0), KsSquare(side = 5L)),
          nInt = 42L,
          nStr = "notnull",
          nEnum = KsEnum.ALPHA,
          nInner = KsInner(value = 51L),
          nBytes = byteArrayOf(9, 8, 7),
          nStrList = listOf("s1", "s2"),
          nMap = mapOf("k" to 9L),
          nInnerElemList = listOf(KsInner(value = 61L), null),
          nValMap = mapOf("a" to 1L, "b" to null),
          nShape = KsSquare(side = 3L),
      )

  private fun makeKsAllNulls(): KsAll =
      KsAll(
          i = 1L,
          d = 2.5,
          s = "three",
          b = false,
          bytes = byteArrayOf(1, 2, 3, 4),
          i32 = intArrayOf(10, 20, 30),
          i64 = longArrayOf(100L, 200L),
          f64 = doubleArrayOf(1.5, 2.5, 3.5),
          e = KsEnum.ALPHA,
          inner = KsInner(value = 11L),
          intList = listOf(1L, 2L, 3L),
          strList = listOf("a", "b"),
          strIntMap = mapOf("x" to 1L, "y" to 2L),
          intDoubleMap = mapOf(1L to 1.1, 2L to 2.2),
          nestedInts = listOf(listOf(1L, 2L), listOf(3L)),
          mapOfLists = mapOf("p" to listOf(1L, 2L), "q" to listOf(3L)),
          enumList = listOf(KsEnum.ALPHA, KsEnum.BETA_TWO),
          innerList = listOf(KsInner(value = 21L), KsInner(value = 22L)),
          enumKeyMap = mapOf(KsEnum.ALPHA to 1L, KsEnum.BETA_TWO to 2L),
          innerValMap = mapOf("m" to KsInner(value = 31L)),
          shape = KsSquare(side = 7L),
          shapes = listOf(KsCircle(radius = 1.0), KsSquare(side = 5L)),
          nInt = null,
          nStr = null,
          nEnum = null,
          nInner = null,
          nBytes = null,
          nStrList = null,
          nMap = null,
          nInnerElemList = listOf(null, null),
          nValMap = mapOf("a" to null),
          nShape = null,
      )
}
