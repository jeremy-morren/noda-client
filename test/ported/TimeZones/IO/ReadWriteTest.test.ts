// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/IO/ReadWriteTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { DateTimeZoneWriter, Duration, Instant, Int32, Offset } from "../../../../src/noda-js/internal.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TimeZones/IO/ReadWriteTest.generated.ts";
import { DtzIoHelper } from "./DtzIoHelper.ts";

port(fixture, {
  Count() {
    const dio = DtzIoHelper.createNoStringPool();

    for (let i = 0; i < 16; i++) {
      dio.testCount(i);
    }
    dio.testCount(0x0f);
    dio.testCount(0x10);
    dio.testCount(0x7f);
    dio.testCount(0x80);
    dio.testCount(0x81);
    dio.testCount(0x3fff);
    dio.testCount(0x4000);
    dio.testCount(0x4001);
    dio.testCount(0x1fffff);
    dio.testCount(0x200000);
    dio.testCount(0x200001);
    dio.testCount(Int32.MaxValue);
    dio.testCount(0, [0x00]);
    dio.testCount(1, [0x01]);
    dio.testCount(127, [0x7f]);
    dio.testCount(128, [0x80, 0x01]);
    dio.testCount(300, [0xac, 0x02]);
  },

  SignedCount() {
    const dio = DtzIoHelper.createNoStringPool();
    for (let i = -16; i < 16; i++) {
      dio.testSignedCount(i);
    }
    dio.testSignedCount(0x4000000);
    dio.testSignedCount(-0x4000000);
    dio.testSignedCount(Int32.MinValue);
    dio.testSignedCount(Int32.MinValue + 1);
    dio.testSignedCount(Int32.MaxValue - 1);
    dio.testSignedCount(Int32.MaxValue);
    dio.testSignedCount(0, [0x00]);
    dio.testSignedCount(-1, [0x01]);
    dio.testSignedCount(1, [0x02]);
    dio.testSignedCount(-2, [0x03]);
    dio.testSignedCount(64, [0x80, 0x01]);
    dio.testSignedCount(-65, [0x81, 0x01]);
    dio.testSignedCount(128, [0x80, 0x02]);
  },

  Test_Dictionary() {
    const dio = DtzIoHelper.createNoStringPool();
    const expected = new Map<string, string>();
    dio.testDictionary(expected);

    expected.set("Able", "able");
    dio.testDictionary(expected);

    expected.set("Baker", "baker");
    expected.set("Charlie", "charlie");
    expected.set("Delta", "delta");
    dio.testDictionary(expected);
  },

  Test_ZoneIntervalTransition() {
    const dio = DtzIoHelper.createNoStringPool();
    dio.testZoneIntervalTransition(null, Instant.BeforeMinValue);
    dio.testZoneIntervalTransition(null, Instant.MinValue);
    // No test for Instant.MaxValue, as it's not on a tick boundary.
    dio.testZoneIntervalTransition(null, Instant.AfterMaxValue);

    dio.testZoneIntervalTransition(null, Instant.MinValue.PlusTicks(1));
    // The ZoneIntervalTransition has precision to the tick (with no real need to change that).
    // Round to the tick just lower than Instant.MaxValue...
    // (noda-js: via the exact tick count, as ToUnixTimeTicks returns the nearest double.)
    const tickBeforeMaxInstant = Instant.FromUnixTimeTicks(Instant.MaxValue.ToUnixTimeTicksExact());
    dio.testZoneIntervalTransition(null, tickBeforeMaxInstant);

    // Encoding as hours-since-previous.
    const previous = Instant.FromUtc(1990, 1, 1, 11, 30); // arbitrary
    dio.testZoneIntervalTransition(previous, previous);
    dio.testZoneIntervalTransition(previous, previous.Plus(Duration.FromHours(
      DateTimeZoneWriter.ZoneIntervalConstants.MinValueForHoursSincePrevious)));
    dio.testZoneIntervalTransition(previous, previous.Plus(Duration.FromHours(
      DateTimeZoneWriter.ZoneIntervalConstants.MinValueForHoursSincePrevious - 1))); // too soon
    dio.testZoneIntervalTransition(previous, previous.Plus(Duration.FromHours(1))); // too soon
    dio.testZoneIntervalTransition(previous, previous.Plus(Duration.FromHours(
      DateTimeZoneWriter.ZoneIntervalConstants.MinValueForMinutesSinceEpoch - 1))); // maximum hours
    dio.testZoneIntervalTransition(previous, previous.Plus(Duration.FromHours(
      DateTimeZoneWriter.ZoneIntervalConstants.MinValueForMinutesSinceEpoch))); // out of range
    // A large difference from the previous transition.
    dio.testZoneIntervalTransition(Instant.MinValue.PlusTicks(1), tickBeforeMaxInstant);

    // Encoding as minutes-since-epoch.
    const epoch = DateTimeZoneWriter.ZoneIntervalConstants.EpochForMinutesSinceEpoch;
    dio.testZoneIntervalTransition(null, epoch);
    dio.testZoneIntervalTransition(null, epoch.Plus(
      Duration.FromMinutes(DateTimeZoneWriter.ZoneIntervalConstants.MinValueForMinutesSinceEpoch)));
    dio.testZoneIntervalTransition(null, epoch.Plus(Duration.FromMinutes(Int32.MaxValue))); // maximum minutes

    // Out of range cases, or not a multiple of minutes since the epoch.
    dio.testZoneIntervalTransition(null, epoch.Plus(Duration.FromHours(1))); // too soon
    dio.testZoneIntervalTransition(null, epoch.Plus(Duration.FromMinutes(1))); // too soon
    dio.testZoneIntervalTransition(null, epoch.Plus(Duration.FromSeconds(1)));
    dio.testZoneIntervalTransition(null, epoch.Plus(Duration.FromMilliseconds(1)));
    dio.testZoneIntervalTransition(null, epoch.Minus(Duration.FromHours(1)));
    dio.testZoneIntervalTransition(null, epoch.Plus(Duration.FromMinutes(Int32.MaxValue + 1)));

    // Example from Pacific/Auckland which failed at one time, and a similar one with seconds.
    dio.testZoneIntervalTransition(null, Instant.FromUtc(1927, 11, 5, 14, 30));
    dio.testZoneIntervalTransition(null, Instant.FromUtc(1927, 11, 5, 14, 30, 5));
  },

  Test_Offset() {
    const dio = DtzIoHelper.createNoStringPool();
    dio.testOffset(Offset.MinValue);
    dio.testOffset(Offset.MaxValue);
    dio.testOffset(Offset.FromHours(0));
    dio.testOffset(Offset.FromHours(5));
    dio.testOffset(Offset.FromHours(-5));
    dio.testOffset(Offset.FromHoursAndMinutes(5, 15));
    dio.testOffset(Offset.FromHoursAndMinutes(5, 30));
    dio.testOffset(Offset.FromHoursAndMinutes(5, 45));
    dio.testOffset(Offset.FromHoursAndMinutes(-5, -15));
    dio.testOffset(Offset.FromHoursAndMinutes(-5, -30));
    dio.testOffset(Offset.FromHoursAndMinutes(-5, -45));
    dio.testOffset(Offset.FromSeconds(1));
    dio.testOffset(Offset.FromSeconds(-1));
    dio.testOffset(Offset.FromSeconds(1000));
    dio.testOffset(Offset.FromSeconds(-1000));
  },

  String_NoPool() {
    const dio = DtzIoHelper.createNoStringPool();
    dio.testString("");
    dio.testString("This is a test string");
  },

  String_WithPool() {
    const dio = DtzIoHelper.createWithStringPool();
    dio.testString("");
    dio.testString("This is a test string");
  },

  ReadByte_AfterHasMoreData() {
    const dio = DtzIoHelper.createNoStringPool();
    dio.writer.WriteByte(5);

    expect(dio.reader.HasMoreData).toBe(true);
    expect(dio.reader.ReadByte()).toBe(5);
  },

  ReadString_AfterHasMoreData() {
    const dio = DtzIoHelper.createNoStringPool();
    dio.writer.WriteString("foo");

    expect(dio.reader.HasMoreData).toBe(true);
    expect(dio.reader.ReadString()).toBe("foo");
  },
});
