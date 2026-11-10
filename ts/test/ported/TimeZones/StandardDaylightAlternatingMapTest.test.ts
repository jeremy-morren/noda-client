// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/StandardDaylightAlternatingMapTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  DateTimeZoneReader,
  DateTimeZoneWriter,
  Instant,
  Int32,
  LocalDateTime,
  LocalTime,
  MemoryStream,
  Offset,
  PrecalculatedDateTimeZone,
  StandardDaylightAlternatingMap,
  TransitionMode,
  ZoneInterval,
  ZoneRecurrence,
  ZoneYearOffset,
  type DateTimeZone,
  type ZoneLocalMapping,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/StandardDaylightAlternatingMapTest.generated.ts";

/** C# `new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay)`. */
function newZoneYearOffset(mode: TransitionMode, monthOfYear: number, dayOfMonth: number, dayOfWeek: number, advance: boolean, timeOfDay: LocalTime): ZoneYearOffset {
  return ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay);
}

/** C# `new StandardDaylightAlternatingMap(standardOffset, startRecurrence, endRecurrence)`. */
function newMap(standardOffset: Offset, startRecurrence: ZoneRecurrence, endRecurrence: ZoneRecurrence): StandardDaylightAlternatingMap {
  return StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(standardOffset, startRecurrence, endRecurrence);
}

const Winter = new ZoneRecurrence("Winter", Offset.Zero, newZoneYearOffset(TransitionMode.Wall, 10, 5, 0, false, new LocalTime(2, 0)), 2000, Int32.MaxValue);

const Summer = new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(1, 0)), 2000, Int32.MaxValue);

/**
 * Time zone with the following characteristics:
 * - Only valid from March 10th 2000
 * - Standard offset of +5 (so 4am UTC = 9am local)
 * - Summer time (DST = 1 hour) always starts at 1am local time on March 10th (skips to 2am)
 * - Winter time (DST = 0) always starts at 2am local time on October 5th (skips to 1am)
 */
const TestMap = newMap(Offset.FromHours(5), Winter, Summer);

const TestZone: DateTimeZone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone(
  "zone",
  [new ZoneInterval("Before", Instant.BeforeMinValue, Instant.FromUtc(1999, 12, 1, 0, 0), Offset.FromHours(5), Summer.Savings)],
  newMap(Offset.FromHours(5), Winter, Summer),
);

function checkMapping(mapping: ZoneLocalMapping, earlyIntervalName: string, lateIntervalName: string, count: number): void {
  expect(mapping.EarlyInterval.Name).toBe(earlyIntervalName);
  expect(mapping.LateInterval.Name).toBe(lateIntervalName);
  expect(mapping.Count).toBe(count);
}

port(
  fixture,
  {
    MinMaxOffsets() {
      assertNodaEqual(TestMap.MaxOffset, Offset.FromHours(6));
      assertNodaEqual(TestMap.MinOffset, Offset.FromHours(5));
    },

    GetZoneInterval_Instant_Summer() {
      const interval = TestMap.GetZoneInterval(Instant.FromUtc(2010, 6, 1, 0, 0));
      expect(interval.Name).toBe("Summer");
      assertNodaEqual(interval.WallOffset, Offset.FromHours(6));
      assertNodaEqual(interval.StandardOffset, Offset.FromHours(5));
      assertNodaEqual(interval.Savings, Offset.FromHours(1));
      assertNodaEqual(interval.IsoLocalStart, new LocalDateTime(2010, 3, 10, 2, 0));
      assertNodaEqual(interval.IsoLocalEnd, new LocalDateTime(2010, 10, 5, 2, 0));
    },

    GetZoneInterval_Instant_Winter() {
      const interval = TestMap.GetZoneInterval(Instant.FromUtc(2010, 11, 1, 0, 0));
      expect(interval.Name).toBe("Winter");
      assertNodaEqual(interval.WallOffset, Offset.FromHours(5));
      assertNodaEqual(interval.StandardOffset, Offset.FromHours(5));
      assertNodaEqual(interval.Savings, Offset.FromHours(0));
      assertNodaEqual(interval.IsoLocalStart, new LocalDateTime(2010, 10, 5, 1, 0));
      assertNodaEqual(interval.IsoLocalEnd, new LocalDateTime(2011, 3, 10, 1, 0));
    },

    GetZoneInterval_Instant_StartOfFirstSummer() {
      // This is only just about valid
      const firstSummer = Instant.FromUtc(2000, 3, 9, 20, 0);
      const interval = TestMap.GetZoneInterval(firstSummer);
      expect(interval.Name).toBe("Summer");
    },

    MapLocal_WithinFirstSummer() {
      const early = new LocalDateTime(2000, 6, 1, 0, 0);
      checkMapping(TestZone.MapLocal(early), "Summer", "Summer", 1);
    },

    MapLocal_WithinFirstWinter() {
      const winter = new LocalDateTime(2000, 12, 1, 0, 0);
      checkMapping(TestZone.MapLocal(winter), "Winter", "Winter", 1);
    },

    MapLocal_AtFirstGapStart() {
      const startOfFirstGap = new LocalDateTime(2000, 3, 10, 1, 0);
      checkMapping(TestZone.MapLocal(startOfFirstGap), "Winter", "Summer", 0);
    },

    MapLocal_WithinFirstGap() {
      const middleOfFirstGap = new LocalDateTime(2000, 3, 10, 1, 30);
      checkMapping(TestZone.MapLocal(middleOfFirstGap), "Winter", "Summer", 0);
    },

    MapLocal_EndOfFirstGap() {
      const endOfFirstGap = new LocalDateTime(2000, 3, 10, 2, 0);
      checkMapping(TestZone.MapLocal(endOfFirstGap), "Summer", "Summer", 1);
    },

    MapLocal_StartOfFirstAmbiguity() {
      const firstAmbiguity = new LocalDateTime(2000, 10, 5, 1, 0);
      checkMapping(TestZone.MapLocal(firstAmbiguity), "Summer", "Winter", 2);
    },

    MapLocal_MiddleOfFirstAmbiguity() {
      const firstAmbiguity = new LocalDateTime(2000, 10, 5, 1, 30);
      checkMapping(TestZone.MapLocal(firstAmbiguity), "Summer", "Winter", 2);
    },

    MapLocal_AfterFirstAmbiguity() {
      const unambiguousWinter = new LocalDateTime(2000, 10, 5, 2, 0);
      checkMapping(TestZone.MapLocal(unambiguousWinter), "Winter", "Winter", 1);
    },

    MapLocal_WithinArbitrarySummer() {
      const summer = new LocalDateTime(2010, 6, 1, 0, 0);
      checkMapping(TestZone.MapLocal(summer), "Summer", "Summer", 1);
    },

    MapLocal_WithinArbitraryWinter() {
      const winter = new LocalDateTime(2010, 12, 1, 0, 0);
      checkMapping(TestZone.MapLocal(winter), "Winter", "Winter", 1);
    },

    MapLocal_AtArbitraryGapStart() {
      const startOfGap = new LocalDateTime(2010, 3, 10, 1, 0);
      checkMapping(TestZone.MapLocal(startOfGap), "Winter", "Summer", 0);
    },

    MapLocal_WithinArbitraryGap() {
      const middleOfGap = new LocalDateTime(2010, 3, 10, 1, 30);
      checkMapping(TestZone.MapLocal(middleOfGap), "Winter", "Summer", 0);
    },

    MapLocal_EndOfArbitraryGap() {
      const endOfGap = new LocalDateTime(2010, 3, 10, 2, 0);
      checkMapping(TestZone.MapLocal(endOfGap), "Summer", "Summer", 1);
    },

    MapLocal_StartOfArbitraryAmbiguity() {
      const ambiguity = new LocalDateTime(2010, 10, 5, 1, 0);
      checkMapping(TestZone.MapLocal(ambiguity), "Summer", "Winter", 2);
    },

    MapLocal_MiddleOfArbitraryAmbiguity() {
      const ambiguity = new LocalDateTime(2010, 10, 5, 1, 30);
      checkMapping(TestZone.MapLocal(ambiguity), "Summer", "Winter", 2);
    },

    MapLocal_AfterArbitraryAmbiguity() {
      const unambiguousWinter = new LocalDateTime(2010, 10, 5, 2, 0);
      checkMapping(TestZone.MapLocal(unambiguousWinter), "Winter", "Winter", 1);
    },

    Equality() {
      // Order of recurrences doesn't matter
      const map1 = newMap(Offset.FromHours(1), Summer, Winter);
      const map2 = newMap(Offset.FromHours(1), Winter, Summer);
      const map3 = newMap(
        Offset.FromHours(1),
        Winter,
        // Summer, but starting from 1900
        new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(1, 0)), 1900, Int32.MaxValue),
      );
      // Standard offset does matter
      const map4 = newMap(Offset.FromHours(0), Summer, Winter);

      TestHelper.testEqualsClass(map1, map2, map4);
      TestHelper.testEqualsClass(map1, map3, map4);

      // Recurrences like Summer, but different in one aspect each, *except* (comment incomplete for years...)
      const unequalMaps = [
        new ZoneRecurrence("Different name", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(1, 0)), 2000, Int32.MaxValue),
        new ZoneRecurrence("Summer", Offset.FromHours(2), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(1, 0)), 2000, Int32.MaxValue),
        new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Standard, 3, 10, 0, false, new LocalTime(1, 0)), 2000, Int32.MaxValue),
        new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 4, 10, 0, false, new LocalTime(1, 0)), 2000, Int32.MaxValue),
        new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 9, 0, false, new LocalTime(1, 0)), 2000, Int32.MaxValue),
        new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 1, false, new LocalTime(1, 0)), 2000, Int32.MaxValue),
        // Advance with day-of-week 0 doesn't make any real difference, but they compare non-equal...
        new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, true, new LocalTime(1, 0)), 2000, Int32.MaxValue),
        new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(2, 0)), 2000, Int32.MaxValue),
      ].map(recurrence => newMap(Offset.FromHours(1), Winter, recurrence));
      TestHelper.testEqualsClass(map1, map2, ...unequalMaps);
    },

    Extremes() {
      const winter = new ZoneRecurrence("Winter", Offset.Zero, newZoneYearOffset(TransitionMode.Wall, 10, 5, 0, false, new LocalTime(2, 0)), Int32.MinValue, Int32.MaxValue);

      const summer = new ZoneRecurrence("Summer", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Wall, 3, 10, 0, false, new LocalTime(1, 0)), Int32.MinValue, Int32.MaxValue);

      const zone = newMap(Offset.Zero, winter, summer);

      const firstSpring = Instant.FromUtc(-9998, 3, 10, 1, 0);
      const firstAutumn = Instant.FromUtc(-9998, 10, 5, 1, 0); // 1am UTC = 2am wall

      const lastSpring = Instant.FromUtc(9999, 3, 10, 1, 0);
      const lastAutumn = Instant.FromUtc(9999, 10, 5, 1, 0); // 1am UTC = 2am wall

      const dstOffset = Offset.FromHours(1);

      // Check both year -9998 and 9999, both the infinite interval and the next one in
      const firstWinter = new ZoneInterval("Winter", Instant.BeforeMinValue, firstSpring, Offset.Zero, Offset.Zero);
      const firstSummer = new ZoneInterval("Summer", firstSpring, firstAutumn, dstOffset, dstOffset);
      const lastSummer = new ZoneInterval("Summer", lastSpring, lastAutumn, dstOffset, dstOffset);
      const lastWinter = new ZoneInterval("Winter", lastAutumn, Instant.AfterMaxValue, Offset.Zero, Offset.Zero);

      assertNodaEqual(zone.GetZoneInterval(Instant.MinValue), firstWinter);
      assertNodaEqual(zone.GetZoneInterval(Instant.FromUtc(-9998, 2, 1, 0, 0)), firstWinter);
      assertNodaEqual(zone.GetZoneInterval(firstSpring), firstSummer);
      assertNodaEqual(zone.GetZoneInterval(Instant.FromUtc(-9998, 5, 1, 0, 0)), firstSummer);

      assertNodaEqual(zone.GetZoneInterval(lastSpring), lastSummer);
      assertNodaEqual(zone.GetZoneInterval(Instant.FromUtc(9999, 5, 1, 0, 0)), lastSummer);
      assertNodaEqual(zone.GetZoneInterval(lastAutumn), lastWinter);
      assertNodaEqual(zone.GetZoneInterval(Instant.FromUtc(9999, 11, 1, 0, 0)), lastWinter);
      assertNodaEqual(zone.GetZoneInterval(Instant.MaxValue), lastWinter);
    },

    InvalidMap_SimultaneousTransition() {
      // Two recurrences with different savings, but which occur at the same instant in time every year.
      const r1 = new ZoneRecurrence("Recurrence1", Offset.Zero, newZoneYearOffset(TransitionMode.Utc, 10, 5, 0, false, new LocalTime(2, 0)), Int32.MinValue, Int32.MaxValue);

      const r2 = new ZoneRecurrence("Recurrence2", Offset.FromHours(1), newZoneYearOffset(TransitionMode.Utc, 10, 5, 0, false, new LocalTime(2, 0)), Int32.MinValue, Int32.MaxValue);

      const map = newMap(Offset.Zero, r1, r2);

      assertThrows("InvalidOperationException", () => map.GetZoneInterval(Instant.FromUtc(2017, 8, 25, 0, 0, 0)));
    },

    ReadWrite() {
      const map1 = newMap(Offset.FromHours(1), Summer, Winter);
      const stream = new MemoryStream();
      const writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      map1.Write(writer);
      stream.Position = 0;

      const reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      const map2 = StandardDaylightAlternatingMap.Read(reader);
      assertNodaEqual(map2, map1);
    },
  },
);
