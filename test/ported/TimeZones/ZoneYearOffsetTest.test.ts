// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/ZoneYearOffsetTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal ZoneYearOffset constructors are the static factories
// NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(AddDay). System.DayOfWeek values are written as numbers.

import { expect } from "vitest";
import {
  IsoDayOfWeek,
  LocalDateTime,
  LocalInstant,
  LocalTime,
  TransitionMode,
  ZoneYearOffset,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { DtzIoHelper } from "./IO/DtzIoHelper.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/ZoneYearOffsetTest.generated.ts";

/** C# `new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay[, addDay])`. */
function newZoneYearOffset(
  mode: TransitionMode,
  monthOfYear: number,
  dayOfMonth: number,
  dayOfWeek: number,
  advance: boolean,
  timeOfDay: LocalTime,
  addDay?: boolean,
): ZoneYearOffset {
  return addDay === undefined
    ? ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay)
    : ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, addDay);
}

/** System.DayOfWeek.Wednesday */
const DayOfWeekWednesday = 3;

port(
  fixture,
  {
    Construct_InvalidMonth_Exception() {
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 0, 1, 1, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 34, 1, 1, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, -3, 1, 1, true, LocalTime.Midnight));
    },

    Construct_InvalidDayOfMonth_Exception() {
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, 0, 1, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, 32, 1, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, 475, 1, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, -32, 1, true, LocalTime.Midnight));
    },

    Construct_InvalidDayOfWeek_Exception() {
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, 3, -1, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, 3, 8, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, 3, 5756, true, LocalTime.Midnight));
      assertThrows("ArgumentOutOfRangeException", () => newZoneYearOffset(TransitionMode.Standard, 2, 3, -347, true, LocalTime.Midnight));
    },

    Construct_ValidMonths() {
      for (let month = 1; month <= 12; month++) {
        expect(newZoneYearOffset(TransitionMode.Standard, month, 1, 1, true, LocalTime.Midnight), `Month ${month}`).not.toBeNull();
      }
    },

    Construct_ValidDays() {
      for (let day = 1; day <= 31; day++) {
        expect(newZoneYearOffset(TransitionMode.Standard, 1, day, 1, true, LocalTime.Midnight), `Day ${day}`).not.toBeNull();
      }
      for (let day = -1; day >= -31; day--) {
        expect(newZoneYearOffset(TransitionMode.Standard, 1, day, 1, true, LocalTime.Midnight), `Day ${day}`).not.toBeNull();
      }
    },

    Construct_ValidDaysOfWeek() {
      for (let dayOfWeek = 0; dayOfWeek <= 7; dayOfWeek++) {
        expect(newZoneYearOffset(TransitionMode.Standard, 1, 1, dayOfWeek, true, LocalTime.Midnight), `Day of week ${dayOfWeek}`).not.toBeNull();
      }
    },

    GetOccurrenceForYear_Defaults_Epoch() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1970);
      const expected = new LocalDateTime(1970, 1, 1, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_Year_1971() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1971);
      const expected = new LocalDateTime(1971, 1, 1, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_Milliseconds() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 1, 1, 0, true, new LocalTime(0, 0, 0, 1));
      const actual = offset.GetOccurrenceForYear(1970);
      const expected = new LocalDateTime(1970, 1, 1, 0, 0, 0, 1).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_WednesdayForward() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 1, 1, DayOfWeekWednesday, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1970);
      const expected = new LocalDateTime(1970, 1, 7, 0, 0).ToLocalInstant(); // 1970-01-01 was a Thursday
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_WednesdayBackward() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 1, 15, DayOfWeekWednesday, false, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1970);
      const expected = new LocalDateTime(1970, 1, 14, 0, 0).ToLocalInstant(); // 1970-01-15 was a Thursday
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_JanMinusTwo() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 1, -2, 0, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1970);
      const expected = new LocalDateTime(1970, 1, 30, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_JanFive() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 1, 5, 0, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1970);
      const expected = new LocalDateTime(1970, 1, 5, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_Feb() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 2, 1, 0, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1970);
      const expected = new LocalDateTime(1970, 2, 1, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_LastSundayInOctober() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 10, -1, IsoDayOfWeek.Sunday, false, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(1996);
      const expected = new LocalDateTime(1996, 10, 27, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_ExactlyFeb29th_LeapYear() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 2, 29, 0, false, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(2012);
      const expected = new LocalDateTime(2012, 2, 29, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_ExactlyFeb29th_NotLeapYear() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 2, 29, 0, false, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(2013);
      const expected = new LocalDateTime(2013, 2, 28, 0, 0).ToLocalInstant(); // For "exact", go to Feb 28th
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_AtLeastFeb29th_LeapYear() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(2012);
      const expected = new LocalDateTime(2012, 3, 4, 0, 0).ToLocalInstant(); // March 4th is the first Sunday after 2012-02-29
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_AtLeastFeb29th_NotLeapYear() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday, true, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(2013);
      const expected = new LocalDateTime(2013, 3, 3, 0, 0).ToLocalInstant(); // March 3rd is the first Sunday after the non-existent 2013-02-29
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_AtMostFeb29th_LeapYear() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday, false, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(2012);
      const expected = new LocalDateTime(2012, 2, 26, 0, 0).ToLocalInstant(); // Feb 26th is the last Sunday before 2012-02-29
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_AtMostFeb29th_NotLeapYear() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday, false, LocalTime.Midnight);
      const actual = offset.GetOccurrenceForYear(2013);
      const expected = new LocalDateTime(2013, 2, 24, 0, 0).ToLocalInstant(); // Feb 24th is the last Sunday is February 2013
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_WithAddDay() {
      // Last Thursday in October, then add 24 hours. The last Thursday in October 2013 is the 31st, so
      // we should get the start of November 1st.
      const offset = newZoneYearOffset(TransitionMode.Utc, 10, -1, IsoDayOfWeek.Thursday, false, LocalTime.Midnight, true);
      const actual = offset.GetOccurrenceForYear(2013);
      const expected = new LocalDateTime(2013, 11, 1, 0, 0).ToLocalInstant();
      assertNodaEqual(actual, expected);
    },

    GetOccurrenceForYear_WithAddDay_December31st9999() {
      const offset = newZoneYearOffset(TransitionMode.Utc, 12, 31, 0, false, LocalTime.Midnight, true);
      const actual = offset.GetOccurrenceForYear(9999);
      const expected = LocalInstant.AfterMaxValue;
      assertNodaEqual(actual, expected);
    },

    IEquatable_Tests() {
      const value = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true, LocalTime.Midnight);
      const equalValue = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true, LocalTime.Midnight);
      const unequalValue = newZoneYearOffset(TransitionMode.Utc, 9, 31, DayOfWeekWednesday, true, LocalTime.Midnight);

      TestHelper.testEqualsClass(value, equalValue, unequalValue);
    },

    Serialization() {
      const dio = DtzIoHelper.createNoStringPool();
      let expected = newZoneYearOffset(TransitionMode.Utc, 10, 31, DayOfWeekWednesday, true,
        new LocalTime(12, 34, 45, 678));
      dio.testZoneYearOffset(expected);

      dio.reset();
      expected = newZoneYearOffset(TransitionMode.Utc, 10, -31, DayOfWeekWednesday, true, LocalTime.Midnight);
      dio.testZoneYearOffset(expected);
    },
  },
);
