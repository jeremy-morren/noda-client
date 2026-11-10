// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/IsoCalendarSystemTest.cs
// (+ IsoCalendarSystemTest.Era.cs, IsoCalendarSystemTest.FieldValidation.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  CalendarSystem,
  Era,
  Instant,
  IsoDayOfWeek,
  LocalDate,
  LocalDateTime,
  NodaConstants,
  WeekYearRules,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/IsoCalendarSystemTest.generated.ts";

// C#: (TimeOfGreatAchievement - UnixEpochDateTime).Ticks, where
// TimeOfGreatAchievement = new DateTime(2009, 11, 27, 18, 38, 25, 345, DateTimeKind.Utc) + TimeSpan.FromTicks(8765).
// This was when I was writing the tests, having finally made everything work - several thousand lines
// of shockingly untested code.
const TimeOfGreatAchievementTicks = BigInt(Date.UTC(2009, 10, 27, 18, 38, 25, 345)) * 10000n + 8765n;
// C#: TimeOfGreatAchievement.DayOfYear
const TimeOfGreatAchievementDayOfYear = (Date.UTC(2009, 10, 27) - Date.UTC(2009, 0, 1)) / 86400000 + 1;

const Iso = CalendarSystem.Iso;

port(fixture, {
  // #region IsoCalendarSystemTest.cs
  FieldsOf_UnixEpoch() {
    // It's easiest to test this using a LocalDateTime in the ISO calendar system.
    // LocalDateTime just passes everything through anyway.
    const epoch: LocalDateTime = NodaConstants.UnixEpoch.InUtc().LocalDateTime;

    assertNodaEqual(epoch.Year, 1970);
    assertNodaEqual(epoch.YearOfEra, 1970);
    assertNodaEqual(WeekYearRules.Iso.GetWeekYear(epoch.Date), 1970);
    assertNodaEqual(WeekYearRules.Iso.GetWeekOfWeekYear(epoch.Date), 1);
    assertNodaEqual(epoch.Month, 1);
    assertNodaEqual(epoch.Day, 1);
    assertNodaEqual(epoch.DayOfYear, 1);
    assertNodaEqual(epoch.DayOfWeek, IsoDayOfWeek.Thursday);
    assertNodaEqual(epoch.Era, Era.Common);
    assertNodaEqual(epoch.Hour, 0);
    assertNodaEqual(epoch.Minute, 0);
    assertNodaEqual(epoch.Second, 0);
    assertNodaEqual(epoch.Millisecond, 0);
    assertNodaEqual(epoch.TickOfDay, 0);
    assertNodaEqual(epoch.TickOfSecond, 0);
  },

  FieldsOf_GreatAchievement() {
    const now = Instant.FromUnixTimeTicks(TimeOfGreatAchievementTicks.toString()).InUtc().LocalDateTime;

    assertNodaEqual(now.Year, 2009);
    assertNodaEqual(now.YearOfEra, 2009);
    assertNodaEqual(WeekYearRules.Iso.GetWeekYear(now.Date), 2009);
    assertNodaEqual(WeekYearRules.Iso.GetWeekOfWeekYear(now.Date), 48);
    assertNodaEqual(now.Month, 11);
    assertNodaEqual(now.Day, 27);
    assertNodaEqual(now.DayOfYear, TimeOfGreatAchievementDayOfYear);
    assertNodaEqual(now.DayOfWeek, IsoDayOfWeek.Friday);
    assertNodaEqual(now.Era, Era.Common);
    assertNodaEqual(now.Hour, 18);
    assertNodaEqual(now.Minute, 38);
    assertNodaEqual(now.Second, 25);
    assertNodaEqual(now.Millisecond, 345);
    assertNodaEqual(now.TickOfSecond, 3458765);
    assertNodaEqual(now.TickOfDay,
      18 * NodaConstants.TicksPerHour +
      38 * NodaConstants.TicksPerMinute +
      25 * NodaConstants.TicksPerSecond +
      3458765);
  },

  ConstructLocalInstant_WithAllFields() {
    const localAchievement = new LocalDateTime(2009, 11, 27, 18, 38, 25, 345).PlusTicks(8765).ToLocalInstant();
    const bclTicks = TimeOfGreatAchievementTicks;
    const bclDays = Number(bclTicks / BigInt(NodaConstants.TicksPerDay));
    const bclTickOfDay = Number(bclTicks % BigInt(NodaConstants.TicksPerDay));
    assertNodaEqual(localAchievement.DaysSinceEpoch, bclDays);
    assertNodaEqual(Math.trunc(localAchievement.NanosecondOfDay / NodaConstants.NanosecondsPerTick), bclTickOfDay);
  },

  IsLeapYear() {
    expect(CalendarSystem.Iso.IsLeapYear(2012)).toBe(true); // 4 year rule
    expect(CalendarSystem.Iso.IsLeapYear(2011)).toBe(false); // 4 year rule
    expect(CalendarSystem.Iso.IsLeapYear(2100)).toBe(false); // 100 year rule
    expect(CalendarSystem.Iso.IsLeapYear(2000)).toBe(true); // 400 year rule
  },

  GetDaysInMonth() {
    assertNodaEqual(CalendarSystem.Iso.GetDaysInMonth(2010, 9), 30);
    assertNodaEqual(CalendarSystem.Iso.GetDaysInMonth(2010, 1), 31);
    assertNodaEqual(CalendarSystem.Iso.GetDaysInMonth(2010, 2), 28);
    assertNodaEqual(CalendarSystem.Iso.GetDaysInMonth(2012, 2), 29);
  },

  BeforeCommonEra() {
    // Year -1 in absolute terms is 2BCE
    const localDate = new LocalDate(-1, 1, 1);
    assertNodaEqual(localDate.Era, Era.BeforeCommon);
    assertNodaEqual(localDate.Year, -1);
    assertNodaEqual(localDate.YearOfEra, 2);
  },

  BeforeCommonEra_BySpecifyingEra() {
    // Year -1 in absolute terms is 2BCE
    const localDate = new LocalDate(Era.BeforeCommon, 2, 1, 1);
    assertNodaEqual(localDate.Era, Era.BeforeCommon);
    assertNodaEqual(localDate.Year, -1);
    assertNodaEqual(localDate.YearOfEra, 2);
  },
  // #endregion

  // #region IsoCalendarSystemTest.Era.cs
  GetMaxYearOfEra() {
    let date = new LocalDate(Iso.MaxYear, 1, 1);
    assertNodaEqual(Iso.GetMaxYearOfEra(Era.Common), date.YearOfEra);
    assertNodaEqual(date.Era, Era.Common);
    date = new LocalDate(Iso.MinYear, 1, 1);
    assertNodaEqual(date.Year, Iso.MinYear);
    assertNodaEqual(Iso.GetMaxYearOfEra(Era.BeforeCommon), date.YearOfEra);
    assertNodaEqual(date.Era, Era.BeforeCommon);
  },

  GetMinYearOfEra() {
    let date = new LocalDate(1, 1, 1);
    assertNodaEqual(Iso.GetMinYearOfEra(Era.Common), date.YearOfEra);
    assertNodaEqual(date.Era, Era.Common);
    date = new LocalDate(0, 1, 1);
    assertNodaEqual(Iso.GetMinYearOfEra(Era.BeforeCommon), date.YearOfEra);
    assertNodaEqual(date.Era, Era.BeforeCommon);
  },

  GetAbsoluteYear() {
    assertNodaEqual(Iso.GetAbsoluteYear(1, Era.Common), 1);
    assertNodaEqual(Iso.GetAbsoluteYear(1, Era.BeforeCommon), 0);
    assertNodaEqual(Iso.GetAbsoluteYear(2, Era.BeforeCommon), -1);
    assertNodaEqual(Iso.GetAbsoluteYear(Iso.GetMaxYearOfEra(Era.Common), Era.Common), Iso.MaxYear);
    assertNodaEqual(Iso.GetAbsoluteYear(Iso.GetMaxYearOfEra(Era.BeforeCommon), Era.BeforeCommon), Iso.MinYear);
  },
  // #endregion

  // #region IsoCalendarSystemTest.FieldValidation.cs
  // These tests assume that if the method doesn't throw, it's doing the right thing - this
  // is all tested elsewhere.
  ValidateYearMonthDay_AllValues_ValidValuesDoesntThrow() {
    Iso.ValidateYearMonthDay(20, 2, 20);
  },

  ValidateYearMonthDay_InvalidYear_Throws() {
    assertThrows("ArgumentOutOfRangeException", () => Iso.ValidateYearMonthDay(50000, 2, 20));
  },

  GetLocalInstant_InvalidMonth_Throws() {
    assertThrows("ArgumentOutOfRangeException", () => Iso.ValidateYearMonthDay(2010, 13, 20));
  },

  GetLocalInstant_29thOfFebruaryInNonLeapYear_Throws() {
    assertThrows("ArgumentOutOfRangeException", () => Iso.ValidateYearMonthDay(2010, 2, 29));
  },

  GetLocalInstant_29thOfFebruaryInLeapYear_DoesntThrow() {
    Iso.ValidateYearMonthDay(2012, 2, 29);
  },
  // #endregion
});
