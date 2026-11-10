// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/IslamicCalendarSystemTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  CalendarSystem,
  Era,
  IslamicEpoch,
  IslamicLeapYearPattern,
  IslamicYearMonthDayCalculator,
  IsoDayOfWeek,
  LocalDate,
  LocalDateTime,
} from "../../../src/noda-js/internal.ts";
import { GetIslamicCalendar, IslamicBcl } from "../../../src/noda-js/entries/calendars/islamic.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/IslamicCalendarSystemTest.generated.ts";

const SampleCalendar = GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil);
// C#: Enum.GetValues(typeof(IslamicEpoch)).Cast<IslamicEpoch>()
const Epochs: readonly IslamicEpoch[] = Object.values(IslamicEpoch).filter((v): v is IslamicEpoch => typeof v === "number");
// C#: Enum.GetValues(typeof(IslamicLeapYearPattern)).Cast<IslamicLeapYearPattern>()
const LeapYearPatterns: readonly IslamicLeapYearPattern[] =
  Object.values(IslamicLeapYearPattern).filter((v): v is IslamicLeapYearPattern => typeof v === "number");

port(fixture, {
  SampleDate1() {
    // Note: field checks removed from the tests.
    let ldt = new LocalDateTime(1945, 11, 12, 0, 0, 0, 0, CalendarSystem.Iso);

    ldt = ldt.WithCalendar(SampleCalendar);
    assertNodaEqual(ldt.Era, Era.AnnoHegirae);
    assertNodaEqual(ldt.YearOfEra, 1364);

    assertNodaEqual(ldt.Year, 1364);
    assertNodaEqual(ldt.Month, 12);
    assertNodaEqual(ldt.Day, 6);
    assertNodaEqual(ldt.DayOfWeek, IsoDayOfWeek.Monday);
    assertNodaEqual(ldt.DayOfYear, 6 * 30 + 5 * 29 + 6);

    assertNodaEqual(ldt.Hour, 0);
    assertNodaEqual(ldt.Minute, 0);
    assertNodaEqual(ldt.Second, 0);
    assertNodaEqual(ldt.TickOfSecond, 0);
  },

  SampleDate2() {
    let ldt = new LocalDateTime(2005, 11, 26, 0, 0, 0, 0, CalendarSystem.Iso);
    ldt = ldt.WithCalendar(SampleCalendar);
    assertNodaEqual(ldt.Era, Era.AnnoHegirae);
    assertNodaEqual(ldt.YearOfEra, 1426);

    assertNodaEqual(ldt.Year, 1426);
    assertNodaEqual(ldt.Month, 10);
    assertNodaEqual(ldt.Day, 24);
    assertNodaEqual(ldt.DayOfWeek, IsoDayOfWeek.Saturday);
    assertNodaEqual(ldt.DayOfYear, 5 * 30 + 4 * 29 + 24);
    assertNodaEqual(ldt.Hour, 0);
    assertNodaEqual(ldt.Minute, 0);
    assertNodaEqual(ldt.Second, 0);
    assertNodaEqual(ldt.TickOfSecond, 0);
  },

  SampleDate3() {
    const ldt = new LocalDateTime(1426, 12, 24, 0, 0, 0, 0, SampleCalendar);
    assertNodaEqual(ldt.Era, Era.AnnoHegirae);

    assertNodaEqual(ldt.Year, 1426);
    assertNodaEqual(ldt.Month, 12);
    assertNodaEqual(ldt.Day, 24);
    assertNodaEqual(ldt.DayOfWeek, IsoDayOfWeek.Tuesday);
    assertNodaEqual(ldt.DayOfYear, 6 * 30 + 5 * 29 + 24);
    assertNodaEqual(ldt.Hour, 0);
    assertNodaEqual(ldt.Minute, 0);
    assertNodaEqual(ldt.Second, 0);
    assertNodaEqual(ldt.TickOfSecond, 0);
  },

  InternalConsistency() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
    // Check construction and then deconstruction for every day of every year in one 30-year cycle.
    for (let year = 1; year <= 30; year++) {
      for (let month = 1; month <= 12; month++) {
        const monthLength = calendar.GetDaysInMonth(year, month);
        for (let day = 1; day < monthLength; day++) {
          const date = new LocalDate(year, month, day, calendar);
          assertNodaEqual(date.Year, year, `Year of ${year}-${month}-${day}`);
          assertNodaEqual(date.Month, month, `Month of ${year}-${month}-${day}`);
          assertNodaEqual(date.Day, day, `Day of ${year}-${month}-${day}`);
        }
      }
    }
  },

  Base15LeapYear() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);

    assertNodaEqual(calendar.IsLeapYear(1), false);
    assertNodaEqual(calendar.IsLeapYear(2), true);
    assertNodaEqual(calendar.IsLeapYear(3), false);
    assertNodaEqual(calendar.IsLeapYear(4), false);
    assertNodaEqual(calendar.IsLeapYear(5), true);
    assertNodaEqual(calendar.IsLeapYear(6), false);
    assertNodaEqual(calendar.IsLeapYear(7), true);
    assertNodaEqual(calendar.IsLeapYear(8), false);
    assertNodaEqual(calendar.IsLeapYear(9), false);
    assertNodaEqual(calendar.IsLeapYear(10), true);
    assertNodaEqual(calendar.IsLeapYear(11), false);
    assertNodaEqual(calendar.IsLeapYear(12), false);
    assertNodaEqual(calendar.IsLeapYear(13), true);
    assertNodaEqual(calendar.IsLeapYear(14), false);
    assertNodaEqual(calendar.IsLeapYear(15), true);
    assertNodaEqual(calendar.IsLeapYear(16), false);
    assertNodaEqual(calendar.IsLeapYear(17), false);
    assertNodaEqual(calendar.IsLeapYear(18), true);
    assertNodaEqual(calendar.IsLeapYear(19), false);
    assertNodaEqual(calendar.IsLeapYear(20), false);
    assertNodaEqual(calendar.IsLeapYear(21), true);
    assertNodaEqual(calendar.IsLeapYear(22), false);
    assertNodaEqual(calendar.IsLeapYear(23), false);
    assertNodaEqual(calendar.IsLeapYear(24), true);
    assertNodaEqual(calendar.IsLeapYear(25), false);
    assertNodaEqual(calendar.IsLeapYear(26), true);
    assertNodaEqual(calendar.IsLeapYear(27), false);
    assertNodaEqual(calendar.IsLeapYear(28), false);
    assertNodaEqual(calendar.IsLeapYear(29), true);
    assertNodaEqual(calendar.IsLeapYear(30), false);
  },

  Base16LeapYear() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil);

    assertNodaEqual(calendar.IsLeapYear(1), false);
    assertNodaEqual(calendar.IsLeapYear(2), true);
    assertNodaEqual(calendar.IsLeapYear(3), false);
    assertNodaEqual(calendar.IsLeapYear(4), false);
    assertNodaEqual(calendar.IsLeapYear(5), true);
    assertNodaEqual(calendar.IsLeapYear(6), false);
    assertNodaEqual(calendar.IsLeapYear(7), true);
    assertNodaEqual(calendar.IsLeapYear(8), false);
    assertNodaEqual(calendar.IsLeapYear(9), false);
    assertNodaEqual(calendar.IsLeapYear(10), true);
    assertNodaEqual(calendar.IsLeapYear(11), false);
    assertNodaEqual(calendar.IsLeapYear(12), false);
    assertNodaEqual(calendar.IsLeapYear(13), true);
    assertNodaEqual(calendar.IsLeapYear(14), false);
    assertNodaEqual(calendar.IsLeapYear(15), false);
    assertNodaEqual(calendar.IsLeapYear(16), true);
    assertNodaEqual(calendar.IsLeapYear(17), false);
    assertNodaEqual(calendar.IsLeapYear(18), true);
    assertNodaEqual(calendar.IsLeapYear(19), false);
    assertNodaEqual(calendar.IsLeapYear(20), false);
    assertNodaEqual(calendar.IsLeapYear(21), true);
    assertNodaEqual(calendar.IsLeapYear(22), false);
    assertNodaEqual(calendar.IsLeapYear(23), false);
    assertNodaEqual(calendar.IsLeapYear(24), true);
    assertNodaEqual(calendar.IsLeapYear(25), false);
    assertNodaEqual(calendar.IsLeapYear(26), true);
    assertNodaEqual(calendar.IsLeapYear(27), false);
    assertNodaEqual(calendar.IsLeapYear(28), false);
    assertNodaEqual(calendar.IsLeapYear(29), true);
    assertNodaEqual(calendar.IsLeapYear(30), false);
  },

  IndianBasedLeapYear() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Civil);

    assertNodaEqual(calendar.IsLeapYear(1), false);
    assertNodaEqual(calendar.IsLeapYear(2), true);
    assertNodaEqual(calendar.IsLeapYear(3), false);
    assertNodaEqual(calendar.IsLeapYear(4), false);
    assertNodaEqual(calendar.IsLeapYear(5), true);
    assertNodaEqual(calendar.IsLeapYear(6), false);
    assertNodaEqual(calendar.IsLeapYear(7), false);
    assertNodaEqual(calendar.IsLeapYear(8), true);
    assertNodaEqual(calendar.IsLeapYear(9), false);
    assertNodaEqual(calendar.IsLeapYear(10), true);
    assertNodaEqual(calendar.IsLeapYear(11), false);
    assertNodaEqual(calendar.IsLeapYear(12), false);
    assertNodaEqual(calendar.IsLeapYear(13), true);
    assertNodaEqual(calendar.IsLeapYear(14), false);
    assertNodaEqual(calendar.IsLeapYear(15), false);
    assertNodaEqual(calendar.IsLeapYear(16), true);
    assertNodaEqual(calendar.IsLeapYear(17), false);
    assertNodaEqual(calendar.IsLeapYear(18), false);
    assertNodaEqual(calendar.IsLeapYear(19), true);
    assertNodaEqual(calendar.IsLeapYear(20), false);
    assertNodaEqual(calendar.IsLeapYear(21), true);
    assertNodaEqual(calendar.IsLeapYear(22), false);
    assertNodaEqual(calendar.IsLeapYear(23), false);
    assertNodaEqual(calendar.IsLeapYear(24), true);
    assertNodaEqual(calendar.IsLeapYear(25), false);
    assertNodaEqual(calendar.IsLeapYear(26), false);
    assertNodaEqual(calendar.IsLeapYear(27), true);
    assertNodaEqual(calendar.IsLeapYear(28), false);
    assertNodaEqual(calendar.IsLeapYear(29), true);
    assertNodaEqual(calendar.IsLeapYear(30), false);
  },

  HabashAlHasibBasedLeapYear() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil);

    assertNodaEqual(calendar.IsLeapYear(1), false);
    assertNodaEqual(calendar.IsLeapYear(2), true);
    assertNodaEqual(calendar.IsLeapYear(3), false);
    assertNodaEqual(calendar.IsLeapYear(4), false);
    assertNodaEqual(calendar.IsLeapYear(5), true);
    assertNodaEqual(calendar.IsLeapYear(6), false);
    assertNodaEqual(calendar.IsLeapYear(7), false);
    assertNodaEqual(calendar.IsLeapYear(8), true);
    assertNodaEqual(calendar.IsLeapYear(9), false);
    assertNodaEqual(calendar.IsLeapYear(10), false);
    assertNodaEqual(calendar.IsLeapYear(11), true);
    assertNodaEqual(calendar.IsLeapYear(12), false);
    assertNodaEqual(calendar.IsLeapYear(13), true);
    assertNodaEqual(calendar.IsLeapYear(14), false);
    assertNodaEqual(calendar.IsLeapYear(15), false);
    assertNodaEqual(calendar.IsLeapYear(16), true);
    assertNodaEqual(calendar.IsLeapYear(17), false);
    assertNodaEqual(calendar.IsLeapYear(18), false);
    assertNodaEqual(calendar.IsLeapYear(19), true);
    assertNodaEqual(calendar.IsLeapYear(20), false);
    assertNodaEqual(calendar.IsLeapYear(21), true);
    assertNodaEqual(calendar.IsLeapYear(22), false);
    assertNodaEqual(calendar.IsLeapYear(23), false);
    assertNodaEqual(calendar.IsLeapYear(24), true);
    assertNodaEqual(calendar.IsLeapYear(25), false);
    assertNodaEqual(calendar.IsLeapYear(26), false);
    assertNodaEqual(calendar.IsLeapYear(27), true);
    assertNodaEqual(calendar.IsLeapYear(28), false);
    assertNodaEqual(calendar.IsLeapYear(29), false);
    assertNodaEqual(calendar.IsLeapYear(30), true);
  },

  ThursdayEpoch() {
    const thursdayEpochCalendar = IslamicBcl;
    const julianCalendar = CalendarSystem.Julian;

    const thursdayEpoch = new LocalDate(1, 1, 1, thursdayEpochCalendar);
    const thursdayEpochJulian = new LocalDate(622, 7, 15, julianCalendar);
    assertNodaEqual(thursdayEpoch.WithCalendar(julianCalendar), thursdayEpochJulian);
  },

  FridayEpoch() {
    const fridayEpochCalendar = GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil);
    const julianCalendar = CalendarSystem.Julian;

    const fridayEpoch = new LocalDate(1, 1, 1, fridayEpochCalendar);
    const fridayEpochJulian = new LocalDate(622, 7, 16, julianCalendar);
    assertNodaEqual(fridayEpoch.WithCalendar(julianCalendar), fridayEpochJulian);
  },

  // Not ported: BclUsesAstronomicalEpoch, SampleDateBclCompatibility, BclThroughHistory (see skip, below)

  GetDaysInMonth() {
    // Just check that we've got the long/short the right way round...
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil);
    assertNodaEqual(calendar.GetDaysInMonth(7, 1), 30);
    assertNodaEqual(calendar.GetDaysInMonth(7, 2), 29);
    assertNodaEqual(calendar.GetDaysInMonth(7, 3), 30);
    assertNodaEqual(calendar.GetDaysInMonth(7, 4), 29);
    assertNodaEqual(calendar.GetDaysInMonth(7, 5), 30);
    assertNodaEqual(calendar.GetDaysInMonth(7, 6), 29);
    assertNodaEqual(calendar.GetDaysInMonth(7, 7), 30);
    assertNodaEqual(calendar.GetDaysInMonth(7, 8), 29);
    assertNodaEqual(calendar.GetDaysInMonth(7, 9), 30);
    assertNodaEqual(calendar.GetDaysInMonth(7, 10), 29);
    assertNodaEqual(calendar.GetDaysInMonth(7, 11), 30);
    // As noted before, 7 isn't a leap year in this calendar
    assertNodaEqual(calendar.GetDaysInMonth(7, 12), 29);
    // As noted before, 8 is a leap year in this calendar
    assertNodaEqual(calendar.GetDaysInMonth(8, 12), 30);
  },

  GetInstance_Caching() {
    const queue: CalendarSystem[] = [];
    const set = new Set<CalendarSystem>();
    const ids = new Set<string>();

    for (const leapYearPattern of LeapYearPatterns) {
      for (const epoch of Epochs) {
        const calendar = GetIslamicCalendar(leapYearPattern, epoch);
        queue.push(calendar);
        // Check we haven't already seen it...
        expect(set.has(calendar)).toBe(false);
        set.add(calendar);
        expect(ids.has(calendar.Id)).toBe(false);
        ids.add(calendar.Id);
      }
    }

    // Now check we get the same references again...
    for (const leapYearPattern of LeapYearPatterns) {
      for (const epoch of Epochs) {
        const oldCalendar = queue.shift()!;
        const newCalendar = GetIslamicCalendar(leapYearPattern, epoch);
        expect(newCalendar).toBe(oldCalendar);
      }
    }
  },

  GetInstance_ArgumentValidation() {
    const minPattern = Math.min(...LeapYearPatterns);
    const maxPattern = Math.max(...LeapYearPatterns);
    const minEpoch = Math.min(...Epochs);
    const maxEpoch = Math.max(...Epochs);
    assertThrows("ArgumentOutOfRangeException", () => GetIslamicCalendar(minPattern - 1, minEpoch));
    assertThrows("ArgumentOutOfRangeException", () => GetIslamicCalendar(minPattern, minEpoch - 1));
    assertThrows("ArgumentOutOfRangeException", () => GetIslamicCalendar(maxPattern + 1, minEpoch));
    assertThrows("ArgumentOutOfRangeException", () => GetIslamicCalendar(minPattern, maxEpoch + 1));
  },

  PlusYears_Simple() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
    const start = new LocalDateTime(5, 8, 20, 2, 0, calendar);
    const expectedEnd = new LocalDateTime(10, 8, 20, 2, 0, calendar);
    assertNodaEqual(start.PlusYears(5), expectedEnd);
  },

  PlusYears_TruncatesAtLeapYear() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
    expect(calendar.IsLeapYear(2)).toBe(true);
    expect(calendar.IsLeapYear(3)).toBe(false);

    const start = new LocalDateTime(2, 12, 30, 2, 0, calendar);
    const expectedEnd = new LocalDateTime(3, 12, 29, 2, 0, calendar);

    assertNodaEqual(start.PlusYears(1), expectedEnd);
  },

  PlusYears_DoesNotTruncateFromOneLeapYearToAnother() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
    expect(calendar.IsLeapYear(2)).toBe(true);
    expect(calendar.IsLeapYear(5)).toBe(true);

    const start = new LocalDateTime(2, 12, 30, 2, 0, calendar);
    const expectedEnd = new LocalDateTime(5, 12, 30, 2, 0, calendar);

    assertNodaEqual(start.PlusYears(3), expectedEnd);
  },

  PlusMonths_Simple() {
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
    expect(calendar.IsLeapYear(2)).toBe(true);

    const start = new LocalDateTime(2, 12, 30, 2, 0, calendar);
    const expectedEnd = new LocalDateTime(3, 11, 30, 2, 0, calendar);
    assertNodaEqual(expectedEnd.Month, 11);
    assertNodaEqual(expectedEnd.Day, 30);
    assertNodaEqual(start.PlusMonths(11), expectedEnd);
  },

  Constructor_InvalidEnumsForCoverage() {
    assertThrows("ArgumentOutOfRangeException", () => IslamicYearMonthDayCalculator.NewLeapYearPatternEpoch(IslamicLeapYearPattern.Base15 + 100, IslamicEpoch.Astronomical));
    assertThrows("ArgumentOutOfRangeException", () => IslamicYearMonthDayCalculator.NewLeapYearPatternEpoch(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical + 100));
  },
}, {
  skip: {
    BclUsesAstronomicalEpoch: "uses the BCL's System.Globalization.HijriCalendar as the oracle; test/golden/calendars.test.ts covers every year of every calendar against NodaTime's own data",
    SampleDateBclCompatibility: "uses the BCL's System.Globalization.HijriCalendar as the oracle; test/golden/calendars.test.ts covers every year of every calendar against NodaTime's own data",
    BclThroughHistory: "uses the BCL's System.Globalization.HijriCalendar as the oracle (BclEquivalenceHelper); test/golden/calendars.test.ts covers every year of every calendar against NodaTime's own data",
  },
});
