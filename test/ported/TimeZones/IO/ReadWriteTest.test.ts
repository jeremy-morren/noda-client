// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/IO/ReadWriteTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: DateTimeZoneWriter isn't ported, so the write/read round trips (DtzIoHelper.TestXxx(value)) can't be.
// What's ported is the reader side wherever the test itself gives the bytes: the TestCount/TestSignedCount cases with
// expected bytes (read back to the value), and the HasMoreData tests (whose written data is a byte, or a string).
// Methods that are nothing but round trips are skipped.

import { expect } from "vitest";
import type { DateTimeZoneReader } from "../../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TimeZones/IO/ReadWriteTest.generated.ts";
import { readerFor, stringBytes } from "./DtzIoHelper.ts";

/** IoStream.AssertEndOfStream */
function assertEndOfStream(reader: DateTimeZoneReader): void {
  expect(reader.HasMoreData).toBe(false);
}

/** The reader half of DtzIoHelper.TestCount(int value, byte[] expected): the bytes read back as the value. */
function testCount(value: number, bytes: number[]): void {
  const reader = readerFor(bytes);
  assertNodaEqual(reader.ReadCount(), value);
  assertEndOfStream(reader);
}

/** The reader half of DtzIoHelper.TestSignedCount(int value, byte[] expected). */
function testSignedCount(value: number, bytes: number[]): void {
  const reader = readerFor(bytes);
  assertNodaEqual(reader.ReadSignedCount(), value);
  assertEndOfStream(reader);
}

const writerSkip = "Write/read round trip: needs DateTimeZoneWriter, which isn't ported";

port(
  fixture,
  {
    Count() {
      // Not ported: dio.TestCount(i) round trips for 0..15, 0x0f, 0x10, 0x7f, 0x80, 0x81, 0x3fff, 0x4000, 0x4001,
      // 0x1fffff, 0x200000, 0x200001 and Int32.MaxValue (they need DateTimeZoneWriter).
      testCount(0, [0x00]);
      testCount(1, [0x01]);
      testCount(127, [0x7f]);
      testCount(128, [0x80, 0x01]);
      testCount(300, [0xac, 0x02]);
    },

    SignedCount() {
      // Not ported: dio.TestSignedCount(i) round trips for -16..15, ±0x4000000, Int32.MinValue, Int32.MinValue + 1,
      // Int32.MaxValue - 1 and Int32.MaxValue (they need DateTimeZoneWriter).
      testSignedCount(0, [0x00]);
      testSignedCount(-1, [0x01]);
      testSignedCount(1, [0x02]);
      testSignedCount(-2, [0x03]);
      testSignedCount(64, [0x80, 0x01]);
      testSignedCount(-65, [0x81, 0x01]);
      testSignedCount(128, [0x80, 0x02]);
    },

    ReadByte_AfterHasMoreData() {
      // dio.Writer.WriteByte(5);
      const reader = readerFor([5]);

      expect(reader.HasMoreData).toBe(true);
      expect(reader.ReadByte()).toBe(5);
    },

    ReadString_AfterHasMoreData() {
      // dio.Writer.WriteString("foo");
      const reader = readerFor(stringBytes("foo"));

      expect(reader.HasMoreData).toBe(true);
      expect(reader.ReadString()).toBe("foo");
    },
  },
  {
    skip: {
      Test_Dictionary: writerSkip,
      Test_ZoneIntervalTransition: writerSkip,
      Test_Offset: writerSkip,
      String_NoPool: writerSkip,
      String_WithPool: writerSkip,
    },
  },
);
