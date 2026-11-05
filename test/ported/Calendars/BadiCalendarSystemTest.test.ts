// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/BadiCalendarSystemTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  BadiYearMonthDayCalculator,
  CalendarSystem,
  DateAdjusters,
  DateTimeZone,
  Era,
  IsoDayOfWeek,
  LocalDate,
  NodaConstants,
  Period,
  PeriodUnits,
  Preconditions,
} from "../../../src/noda-js/internal.ts";
import { Badi } from "../../../src/noda-js/entries/calendars/badi.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/BadiCalendarSystemTest.generated.ts";

// For use with CreateBadíʿDate, this is a notional "month"
// containing Ayyam-i-Ha. The days here are represented in month
// 18 in LocalDate etc.
const AyyamiHaMonth = 0;

/**
 * Create a {@link LocalDate} in the Badíʿ calendar, treating 0
 * as the month containing Ayyam-i-Ha.
 * @param year Year in the Badíʿ calendar
 * @param month Month (use 0 for Ayyam-i-Ha)
 * @param day Day in month
 */
function CreateBadiDate(year: number, month: number, day: number): LocalDate {
  if (month === AyyamiHaMonth) {
    Preconditions.CheckArgumentRange("day", day, 1, BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year));
    // Move Ayyam-i-Ha days to fall after the last day of month 18.
    month = BadiYearMonthDayCalculator.Month18;
    day += BadiYearMonthDayCalculator.DaysInMonth;
  }
  return new LocalDate(year, month, day, Badi);
}

/**
 * Return the day of this month, treating Ayyam-i-Ha as a separate month.
 */
function BadiDay(input: LocalDate): number {
  Preconditions.CheckArgument(input.Calendar === Badi, "input", "Only valid when using the Badíʿ calendar");

  if (input.Month === BadiYearMonthDayCalculator.Month18 &&
    input.Day > BadiYearMonthDayCalculator.DaysInMonth) {
    return input.Day - BadiYearMonthDayCalculator.DaysInMonth;
  }
  return input.Day;
}

/**
 * Return the month of this date. If in Ayyam-i-Ha, returns 0.
 */
function BadiMonth(input: LocalDate): number {
  Preconditions.CheckArgument(input.Calendar === Badi, "input", "Only valid when using the Badíʿ calendar");

  if (input.Month === BadiYearMonthDayCalculator.Month18 &&
    input.Day > BadiYearMonthDayCalculator.DaysInMonth) {
    return AyyamiHaMonth;
  }
  return input.Month;
}

/**
 * Get a text representation of the date.
 */
function AsBadiString(input: LocalDate): string {
  const year = input.Year;
  const month = BadiMonth(input);
  const day = BadiDay(input);

  return `${year}-${month}-${day}`;
}

// Period related tests
const TestDate1_167_5_15 = CreateBadiDate(167, 5, 15);
const TestDate1_167_6_7 = CreateBadiDate(167, 6, 7);
const TestDate2_167_Ayyam_4 = CreateBadiDate(167, AyyamiHaMonth, 4);
const TestDate3_168_Ayyam_5 = CreateBadiDate(168, AyyamiHaMonth, 5);

/**
 * Tests for the Badíʿ calendar system.
 */
port(fixture, {
  BadiEpoch() {
    const badi = Badi;
    void badi;
    const badiEpoch = CreateBadiDate(1, 1, 1);

    const gregorian = CalendarSystem.Gregorian;
    const converted = badiEpoch.WithCalendar(gregorian);

    const expected = new LocalDate(1844, 3, 21);

    assertNodaEqual(converted.toString(), expected.toString());
  },

  UnixEpoch() {
    const badi = Badi;
    const unixEpochInBadiCalendar = NodaConstants.UnixEpoch.InZone(DateTimeZone.Utc, badi).LocalDateTime.Date;
    const expected = CreateBadiDate(126, 16, 2);
    assertNodaEqual(unixEpochInBadiCalendar, expected);
  },

  SampleDate() {
    const badiCalendar = Badi;
    const iso = new LocalDate(2017, 3, 4);
    const badi = iso.WithCalendar(badiCalendar);

    assertNodaEqual(BadiMonth(badi), 19);

    assertNodaEqual(badi.Era, Era.Bahai);
    assertNodaEqual(badi.YearOfEra, 173);

    assertNodaEqual(badi.Year, 173);
    expect(badiCalendar.IsLeapYear(173)).toBe(false);

    assertNodaEqual(BadiDay(badi), 4);

    assertNodaEqual(badi.DayOfWeek, IsoDayOfWeek.Saturday);
  },

  GeneralConversionNearNawRuz(gYear: number, gMonth: number, gDay: number, bYear: number, bMonth: number, bDay: number) {
    // create in the Badíʿ calendar
    const bDate = CreateBadiDate(bYear, bMonth, bDay);
    const gDate = bDate.WithCalendar(CalendarSystem.Gregorian);
    assertNodaEqual(gDate.Year, gYear);
    assertNodaEqual(gDate.Month, gMonth);
    assertNodaEqual(gDate.Day, gDay);

    // convert to the Badíʿ calendar
    const bDate2 = new LocalDate(gYear, gMonth, gDay).WithCalendar(Badi);
    assertNodaEqual(bDate2.Year, bYear);
    assertNodaEqual(BadiMonth(bDate2), bMonth);
    assertNodaEqual(BadiDay(bDate2), bDay);
  },

  SpecialCases(gYear: number, gMonth: number, gDay: number, bYear: number, bMonth: number, bDay: number) {
    // create in test calendar
    const bDate = CreateBadiDate(bYear, bMonth, bDay);

    // convert to gregorian
    const gDate = bDate.WithCalendar(CalendarSystem.Gregorian);

    assertNodaEqual(`${gDate.Year}-${gDate.Month}-${gDate.Day}`, `${gYear}-${gMonth}-${gDay}`);

    // create in gregorian
    // convert to test calendar
    const gDate2 = new LocalDate(gYear, gMonth, gDay);
    const bDate2 = gDate2.WithCalendar(Badi);

    assertNodaEqual(`${bDate2.Year}-${BadiMonth(bDate2)}-${BadiDay(bDate2)}`, `${bYear}-${bMonth}-${bDay}`);
  },

  GeneralWtoG(bYear: number, bMonth: number, bDay: number, gYear: number, gMonth: number, gDay: number) {
    // create in this calendar
    const bDate = CreateBadiDate(bYear, bMonth, bDay);
    const gDate = bDate.WithCalendar(CalendarSystem.Gregorian);
    assertNodaEqual(gDate.Year, gYear);
    assertNodaEqual(gDate.Month, gMonth);
    assertNodaEqual(gDate.Day, gDay);

    // convert to this calendar
    const bDate2 = new LocalDate(gYear, gMonth, gDay).WithCalendar(Badi);
    assertNodaEqual(bDate2.Year, bYear);
    assertNodaEqual(BadiMonth(bDate2), bMonth);
    assertNodaEqual(BadiDay(bDate2), bDay);
  },

  DaysInAyyamiHa(bYear: number, days: number) {
    assertNodaEqual(BadiYearMonthDayCalculator.GetDaysInAyyamiHa(bYear), days);
  },

  DayOfYear(bYear: number, bMonth: number, bDay: number, dayOfYear: number) {
    const badi = BadiYearMonthDayCalculator.New();
    assertNodaEqual(badi.GetDayOfYear(CreateBadiDate(bYear, bMonth, bDay).YearMonthDay), dayOfYear);
  },

  // Cannot use EndOfMonth with Ayyam-i-Ha because they are internally stored as days in month 18.
  // In Ayyam-i-Ha, EndOfMonth should throw an exception or return the last day of Ayyam-i-Ha.
  // In this implementation, it will always return the last day of the month 18.
  EndOfMonth(year: number, month: number, day: number, eomMonth: number, eomDay: number) {
    const start = CreateBadiDate(year, month, day);
    const end = CreateBadiDate(year, eomMonth, eomDay);
    assertNodaEqual(AsBadiString(DateAdjusters.EndOfMonth(start)), AsBadiString(end));
  },

  LeapYear() {
    const calendar = Badi;
    expect(calendar.IsLeapYear(172)).toBe(false);
    expect(calendar.IsLeapYear(173)).toBe(false);
    expect(calendar.IsLeapYear(207)).toBe(true);
    expect(calendar.IsLeapYear(220)).toBe(true);
  },

  GetMonthsInYear() {
    const calendar = Badi;
    assertNodaEqual(calendar.GetMonthsInYear(180), 19);
  },

  GetDaysInMonth(year: number, month: number, expectedDays: number) {
    const calendar = Badi;
    assertNodaEqual(calendar.GetDaysInMonth(year, month), expectedDays);
  },

  CreateDate_InAyyamiHa() {
    const d1 = CreateBadiDate(180, 0, 3);
    const d3 = CreateBadiDate(180, 18, 22);

    assertNodaEqual(d3, d1);
  },

  CreateDate_Invalid(year: number, month: number, day: number) {
    assertThrows("ArgumentOutOfRangeException", () => CreateBadiDate(year, month, day));
  },

  BetweenLocalDates_InvalidUnits() {
    assertThrows("ArgumentException", () => Period.Between(TestDate1_167_5_15, TestDate2_167_Ayyam_4, 0 as PeriodUnits));
    assertThrows("ArgumentException", () => Period.Between(TestDate1_167_5_15, TestDate2_167_Ayyam_4, -1 as PeriodUnits));
    assertThrows("ArgumentException", () => Period.Between(TestDate1_167_5_15, TestDate2_167_Ayyam_4, PeriodUnits.AllTimeUnits));
    assertThrows("ArgumentException", () => Period.Between(TestDate1_167_5_15, TestDate2_167_Ayyam_4, PeriodUnits.Years | PeriodUnits.Hours));
  },

  SetYear() {
    // Crafted to test SetYear with 0
    const d1 = CreateBadiDate(180, 1, 1);
    const result = LocalDate.Add(d1, Period.FromYears(0));
    assertNodaEqual(result.Year, 180);
  },

  BetweenLocalDates_MovingForwardNoLeapYears_WithExactResults() {
    const actual = Period.Between(TestDate1_167_5_15, TestDate1_167_6_7);
    const expected = Period.FromDays(11);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingForwardNoLeapYears_WithExactResults_2() {
    const actual = Period.Between(TestDate1_167_5_15, TestDate2_167_Ayyam_4);
    const expected = Period.Add(Period.FromMonths(13), Period.FromDays(8));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingForwardInLeapYear_WithExactResults() {
    const actual = Period.Between(TestDate1_167_5_15, TestDate3_168_Ayyam_5);
    const expected = Period.Add(Period.Add(Period.FromYears(1), Period.FromMonths(13)), Period.FromDays(9));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingBackwardNoLeapYears_WithExactResults() {
    const actual = Period.Between(TestDate2_167_Ayyam_4, TestDate1_167_5_15);
    const expected = Period.Add(Period.FromMonths(-13), Period.FromDays(-8));
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingBackward_WithExactResults() {
    // should be -1y -13m -9d
    // but system first moves back a year, and in that year, the last day of Ayyam-i-Ha is day 4
    // from there, it is -13m -8d

    const expected = Period.Add(Period.Add(Period.FromYears(-1), Period.FromMonths(-13)), Period.FromDays(-8));
    const actual = Period.Between(TestDate3_168_Ayyam_5, TestDate1_167_5_15);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingForward_WithJustMonths() {
    const actual = Period.Between(TestDate1_167_5_15, TestDate3_168_Ayyam_5, PeriodUnits.Months);
    const expected = Period.FromMonths(32);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_MovingBackward_WithJustMonths() {
    const actual = Period.Between(TestDate3_168_Ayyam_5, TestDate1_167_5_15, PeriodUnits.Months);
    const expected = Period.FromMonths(-32);
    assertNodaEqual(actual, expected);
  },

  BetweenLocalDates_AsymmetricForwardAndBackward() {
    const d1 = CreateBadiDate(166, 18, 4);
    const d2 = CreateBadiDate(167, 1, 10);

    // spanning Ayyam-i-Ha - not counted as a month
    assertNodaEqual(Period.Between(d1, d2), Period.Add(Period.FromMonths(2), Period.FromDays(6)));
    assertNodaEqual(Period.Between(d2, d1), Period.Add(Period.FromMonths(-2), Period.FromDays(-6)));
  },

  BetweenLocalDates_EndOfMonth() {
    const d1 = CreateBadiDate(171, 5, 19);
    const d2 = CreateBadiDate(171, 6, 19);
    assertNodaEqual(Period.Between(d1, d2), Period.FromMonths(1));
    assertNodaEqual(Period.Between(d2, d1), Period.FromMonths(-1));
  },

  BetweenLocalDates_OnLeapYear() {
    const d1 = new LocalDate(2012, 2, 29).WithCalendar(Badi);
    const d2 = new LocalDate(2013, 2, 28).WithCalendar(Badi);

    assertNodaEqual(AsBadiString(d1), "168-0-4");
    assertNodaEqual(AsBadiString(d2), "169-0-3");

    assertNodaEqual(Period.Between(d1, d2), Period.Add(Period.FromMonths(19), Period.FromDays(18)));
  },

  BetweenLocalDates_AfterLeapYear() {
    const d1 = CreateBadiDate(180, 19, 5);
    const d2 = CreateBadiDate(181, 19, 5);
    assertNodaEqual(Period.Between(d1, d2), Period.FromYears(1));
    assertNodaEqual(Period.Between(d2, d1), Period.FromYears(-1));
  },

  Addition_DayCrossingMonthBoundary() {
    const start = CreateBadiDate(182, 4, 13);
    const result = LocalDate.Add(start, Period.FromDays(10));
    assertNodaEqual(result, CreateBadiDate(182, 5, 4));
  },

  Addition() {
    const start = CreateBadiDate(182, 1, 1);

    let result = LocalDate.Add(start, Period.FromDays(3));
    assertNodaEqual(result, CreateBadiDate(182, 1, 4));

    result = LocalDate.Add(start, Period.FromDays(20));
    assertNodaEqual(result, CreateBadiDate(182, 2, 2));
  },

  Addition_DayCrossingMonthBoundaryFromAyyamiHa() {
    const start = CreateBadiDate(182, AyyamiHaMonth, 3);

    const result = LocalDate.Add(start, Period.FromDays(10));
    // in 182, Ayyam-i-Ha has 5 days
    assertNodaEqual(result, CreateBadiDate(182, 19, 8));
  },

  Addition_OneYearOnLeapDay() {
    const start = CreateBadiDate(182, AyyamiHaMonth, 5);
    const result = LocalDate.Add(start, Period.FromYears(1));
    // Ayyam-i-Ha 5 becomes Ayyam-i-Ha 4
    assertNodaEqual(result, CreateBadiDate(183, AyyamiHaMonth, 4));
  },

  Addition_FiveYearsOnLeapDay() {
    const start = CreateBadiDate(182, AyyamiHaMonth, 5);
    const result = LocalDate.Add(start, Period.FromYears(5));
    assertNodaEqual(result, CreateBadiDate(187, AyyamiHaMonth, 5));
  },

  Addition_YearMonthDay() {
    // One year, one month, two days
    const period = Period.Add(Period.Add(Period.FromYears(1), Period.FromMonths(1)), Period.FromDays(2));
    const start = CreateBadiDate(171, 1, 19);
    // Periods are added in order, so this becomes...
    // Add one year: 172.1.19
    // Add one month: 172.2.19
    // Add two days: 172.3.2
    const result = LocalDate.Add(start, period);
    assertNodaEqual(result, CreateBadiDate(172, 3, 2));
  },

  PlusMonths_ToLastMonthOfNextYear(year: number, month: number, day: number, months: number, expectedYear: number, expectedMonth: number, expectedDay: number) {
    const start = CreateBadiDate(year, month, day);
    const actual = start.PlusMonths(months);
    const expected = CreateBadiDate(expectedYear, expectedMonth, expectedDay);
    assertNodaEqual(actual.YearMonthDay, expected.YearMonthDay);
  },

  PlusMonths_Overflow() {
    const calendar = Badi;
    const earlyDate = new LocalDate(calendar.MinYear, 1, 1, calendar);
    const lateDate = new LocalDate(calendar.MaxYear, 19, 1, calendar);

    assertThrows("OverflowException", () => earlyDate.PlusMonths(-1));
    assertThrows("OverflowException", () => lateDate.PlusMonths(1));
  },

  // See https://github.com/nodatime/nodatime/issues/1908
  EpochDaysRoundtrip() {
    const daysSinceEpoch = 45003;
    const calculator = BadiYearMonthDayCalculator.New();
    const ymd = calculator.GetYearMonthDay(daysSinceEpoch);
    assertNodaEqual(calculator.GetDaysSinceEpoch(ymd), daysSinceEpoch);
  },

  HelperMethod_BadiDay() {
    // ensure that this helper method is working
    assertNodaEqual(10, BadiDay(CreateBadiDate(180, 10, 10)));
    assertNodaEqual(19, BadiDay(CreateBadiDate(180, 18, 19)));
    assertNodaEqual(3, BadiDay(CreateBadiDate(180, 0, 3)));
    assertNodaEqual(1, BadiDay(CreateBadiDate(180, 19, 1)));
  },

  HelperMethod_BadiMonth() {
    // ensure that this helper method is working
    assertNodaEqual(10, BadiMonth(CreateBadiDate(180, 10, 10)));
    assertNodaEqual(18, BadiMonth(CreateBadiDate(180, 18, 19)));
    assertNodaEqual(0, BadiMonth(CreateBadiDate(180, 0, 3)));
    assertNodaEqual(19, BadiMonth(CreateBadiDate(180, 19, 1)));
  },

  HelperMethod_AsBadiString() {
    // ensure that this helper method is working
    assertNodaEqual("180-10-10", AsBadiString(CreateBadiDate(180, 10, 10)));
    assertNodaEqual("180-18-19", AsBadiString(CreateBadiDate(180, 18, 19)));
    assertNodaEqual("180-0-3", AsBadiString(CreateBadiDate(180, 0, 3)));
    assertNodaEqual("180-19-1", AsBadiString(CreateBadiDate(180, 19, 1)));
  },
});
