// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/BadiYearMonthDayCalculator.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  LocalDate,
  Preconditions,
  YearMonthDay,
  YearMonthDayCalculator,
} from "../internal.ts";
// C#: YearInfoRaw = Convert.FromBase64String("..."). tools/NodaJs.Tools (calendars) generates the decoded bytes.
import { YearInfoRaw } from "./BadiYearMonthDayCalculatorData.generated.ts";
import { NewOverflowException } from "../internal.ts";

// named constants to avoid use of raw numbers in the code
const AverageDaysPer10Years = 3652; // Ideally 365.2425 per year...
const DaysInAyyamiHaInLeapYear = 5;
const DaysInAyyamiHaInNormalYear = 4;

const DaysInMonth = 19;
const FirstYearOfStandardizedCalendar = 172;
const GregorianYearOfFirstBadiYear = 1844;

const Month18 = 18;
const Month19 = 19;
const MonthsInYear = 19;

const UnixEpochDayAtStartOfYear1 = -45941;
const BadiMaxYear = 1000; // current lookup tables are pre-calculated for a thousand years
const BadiMinYear = 1;

// C#: static byte[] YearInfoRaw (imported above).
//
// This is the base64 representation of information for years 172 to 1000.
// NazRuzDate falls on March 19, 20, 21, or 22.
// DaysInAyymiHa can be 4,5.
// For each year, the value in the array is (NawRuzDate - 19) + 10 * (DaysInAyyamiHa - 4)

/**
 * See `Badi` (noda-js/calendars/badi) for details about the Badíʿ calendar.
 * @internal
 */
export class BadiYearMonthDayCalculator extends YearMonthDayCalculator {
  static readonly DaysInMonth = DaysInMonth;

  /**
   * There are 19 months in a year. Between the 18th and 19th month are the "days of Ha" (Ayyam-i-Ha).
   * In order to make everything else in Noda Time work appropriately, Ayyam-i-Ha are counted as
   * extra days at the end of month 18.
   */
  static readonly Month18 = Month18;

  // C#: static constructor. Run on construction instead, as module evaluation mustn't use other modules.
  private static CheckYearInfoRaw(): void {
    Preconditions.DebugCheckState(
      FirstYearOfStandardizedCalendar + YearInfoRaw.length === BadiMaxYear + 1,
      `Invalid compressed data. Length: ${YearInfoRaw.length}`);
  }

  private constructor() {
    super(BadiMinYear,
      BadiMaxYear - 1,
      AverageDaysPer10Years,
      UnixEpochDayAtStartOfYear1);
  }

  /** C#: `internal BadiYearMonthDayCalculator()` */
  static New(): BadiYearMonthDayCalculator {
    BadiYearMonthDayCalculator.CheckYearInfoRaw();
    return new BadiYearMonthDayCalculator();
  }

  static GetDaysInAyyamiHa(year: number): number {
    // Year 0 is valid here, for the length of the week-year before the first year: see CalculateStartOfYearDays.
    Preconditions.CheckArgumentRange("year", year, BadiMinYear - 1, BadiMaxYear);
    if (year < FirstYearOfStandardizedCalendar) {
      return CalendarSystem.Iso.YearMonthDayCalculator.IsLeapYear(year + GregorianYearOfFirstBadiYear)
        ? DaysInAyyamiHaInLeapYear : DaysInAyyamiHaInNormalYear;
    }
    const num = YearInfoRaw[year - FirstYearOfStandardizedCalendar]!;
    return num >= 10 ? DaysInAyyamiHaInLeapYear : DaysInAyyamiHaInNormalYear;
  }

  private static GetNawRuzDayInMarch(year: number): number {
    // Year 0 is valid here: see CalculateStartOfYearDays.
    Preconditions.CheckArgumentRange("year", year, BadiMinYear - 1, BadiMaxYear);
    if (year < FirstYearOfStandardizedCalendar) {
      return 21;
    }
    const dayInMarchForOffsetToNawRuz = 19;
    const num = YearInfoRaw[year - FirstYearOfStandardizedCalendar]!;
    return dayInMarchForOffsetToNawRuz + (num % 10);
  }

  protected override CalculateStartOfYearDays(year: number): number {
    // As documented in YearMonthDayCalculator, the year may be one outside the calendar's range: week-year
    // rules need the start of the year before the first year (year 0, which starts on March 21st 1843 like
    // every year before the standardized calendar) and after the last year (BadiMaxYear, one more than MaxYear).
    Preconditions.CheckArgumentRange("year", year, BadiMinYear - 1, BadiMaxYear);

    // The epoch is the same regardless of calendar system, so if we work out when the
    // start of the Badíʿ year is in terms of the Gregorian year, we can just use that
    // date's days-since-epoch value.
    const gregorianYear = year + GregorianYearOfFirstBadiYear - 1;
    const nawRuz = new LocalDate(gregorianYear, 3, BadiYearMonthDayCalculator.GetNawRuzDayInMarch(year));
    return nawRuz.DaysSinceEpoch;
  }

  protected override GetDaysFromStartOfYearToStartOfMonth(year: number, month: number): number {
    let daysFromStartOfYearToStartOfMonth = DaysInMonth * (month - 1);

    if (month === Month19) {
      daysFromStartOfYearToStartOfMonth += BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year);
    }

    return daysFromStartOfYearToStartOfMonth;
  }

  override AddMonths(start: YearMonthDay, months: number): YearMonthDay {
    if (months === 0) {
      return start;
    }

    const movingBackwards = months < 0;

    let thisMonth = start.Month;
    const thisYear = start.Year;
    const thisDay = start.Day;

    let nextDay = thisDay;

    // TODO: It's not clear that this is correct. If we add 19 months,
    // it's probably okay to stay in Ayyam-i-Ha.
    if (BadiYearMonthDayCalculator.IsInAyyamiHa(start)) {
      nextDay = thisDay - DaysInMonth;

      if (movingBackwards) {
        thisMonth++;
      }
    }

    let nextYear = thisYear;
    let nextMonthNum = thisMonth + months;

    if (nextMonthNum > MonthsInYear) {
      nextYear = thisYear + Math.trunc((nextMonthNum - 1) / MonthsInYear);
      nextMonthNum = (nextMonthNum - 1) % MonthsInYear + 1;
    } else if (nextMonthNum < 1) {
      nextMonthNum = MonthsInYear - nextMonthNum;
      nextYear = thisYear - Math.trunc(nextMonthNum / MonthsInYear);
      nextMonthNum = MonthsInYear - nextMonthNum % MonthsInYear;
    }

    if (nextYear < this.MinYear || nextYear > this.MaxYear) {
      throw NewOverflowException("Date computation would overflow calendar bounds.");
    }

    const result = YearMonthDay.NewYearMonthDay(nextYear, nextMonthNum, nextDay);

    return result;
  }

  override GetDaysInMonth(year: number, month: number): number {
    Preconditions.CheckArgumentRange("year", year, BadiMinYear, BadiMaxYear);
    return month === Month18 ? DaysInMonth + BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year) : DaysInMonth;
  }

  override GetDaysInYear(year: number): number {
    return 361 + BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year);
  }

  override GetDaysSinceEpoch(target: YearMonthDay): number {
    const month = target.Month;
    const year = target.Year;

    const firstDay0OfYear = this.CalculateStartOfYearDays(year) - 1;

    let daysSinceEpoch = firstDay0OfYear
      + (month - 1) * DaysInMonth
      + target.Day;

    if (month === Month19) {
      daysSinceEpoch += BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year);
    }

    return daysSinceEpoch;
  }

  override GetMonthsInYear(year: number): number {
    void year;
    return MonthsInYear;
  }

  protected override GetYearMonthDayFromYearAndDayOfYear(year: number, dayOfYear: number): YearMonthDay {
    Preconditions.CheckArgumentRange("dayOfYear", dayOfYear, 1, this.GetDaysInYear(year));

    const firstOfLoftiness = 1 + DaysInMonth * Month18 + BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year);

    if (dayOfYear >= firstOfLoftiness) {
      return YearMonthDay.NewYearMonthDay(year, Month19, dayOfYear - firstOfLoftiness + 1);
    }

    const month = Math.min(1 + Math.trunc((dayOfYear - 1) / DaysInMonth), Month18);
    const day = dayOfYear - (month - 1) * DaysInMonth;

    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  static IsInAyyamiHa(ymd: YearMonthDay): boolean {
    return ymd.Month === Month18 && ymd.Day > DaysInMonth;
  }

  override IsLeapYear(year: number): boolean {
    return BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year) !== DaysInAyyamiHaInNormalYear;
  }

  override MonthsBetween(start: YearMonthDay, end: YearMonthDay): number {
    const startMonth = start.Month;
    const startYear = start.Year;

    const endMonth = end.Month;
    const endYear = end.Year;

    const diff = (endYear - startYear) * MonthsInYear + endMonth - startMonth;

    // If we just add the difference in months to start, what do we get?
    const simpleAddition = this.AddMonths(start, diff);

    // Note: this relies on naive comparison of year/month/date values.
    if (start.CompareTo(end) <= 0) {
      // Moving forward: if the result of the simple addition is before or equal to the end,
      // we're done. Otherwise, rewind a month because we've overshot.
      return simpleAddition.CompareTo(end) <= 0 ? diff : diff - 1;
    } else {
      // Moving backward: if the result of the simple addition (of a non-positive number)
      // is after or equal to the end, we're done. Otherwise, increment by a month because
      // we've overshot backwards.
      return simpleAddition.CompareTo(end) >= 0 ? diff : diff + 1;
    }
  }

  override SetYear(start: YearMonthDay, newYear: number): YearMonthDay {
    Preconditions.CheckArgumentRange("newYear", newYear, BadiMinYear, BadiMaxYear);

    const month = start.Month;
    const day = start.Day;

    if (BadiYearMonthDayCalculator.IsInAyyamiHa(start)) {
      // Moving a year while within Ayyam-i-Ha is not well defined.
      // In this implementation, if starting on day 5, end on day 4 (stay in Ayyam-i-Ha)
      const daysInThisAyyamiHa = BadiYearMonthDayCalculator.GetDaysInAyyamiHa(newYear);
      return YearMonthDay.NewYearMonthDay(newYear, month, Math.min(day, DaysInMonth + daysInThisAyyamiHa));
    }

    return YearMonthDay.NewYearMonthDay(newYear, month, day);
  }

  override ValidateYearMonthDay(year: number, month: number, day: number): void {
    Preconditions.CheckArgumentRange("year", year, BadiMinYear, BadiMaxYear);
    Preconditions.CheckArgumentRange("month", month, 1, MonthsInYear);

    const daysInMonth = month === Month18 ? DaysInMonth + BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year) : DaysInMonth;
    Preconditions.CheckArgumentRange("day", day, 1, daysInMonth);
  }
}
