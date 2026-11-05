// Ported from NodaTime 3.3.0: src/NodaTime/Calendars/WeekYearRules.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  ArgumentError,
  ArgumentOutOfRangeError,
  IsoDayOfWeek,
  SimpleWeekYearRule,
  type IWeekYearRule,
} from "../internal.ts";
import type { DateTimeFormatInfo } from "../internal.ts";

let iso: IWeekYearRule | undefined;

/**
 * Factory methods to construct week-year rules supported by Noda Time.
 */
export class WeekYearRules {
  private constructor() {}

  /**
   * Returns an {@link IWeekYearRule} consistent with ISO-8601.
   *
   * In the standard ISO-8601 week algorithm, the first week of the year
   * is that in which at least 4 days are in the year. As a result of this
   * definition, day 1 of the first week may be in the previous year. In ISO-8601,
   * weeks always begin on a Monday, so this rule is equivalent to the first Thursday
   * being in the first Monday-to-Sunday week of the year.
   *
   * For example, January 1st 2011 was a Saturday, so only two days of that week
   * (Saturday and Sunday) were in 2011. Therefore January 1st is part of
   * week 52 of week-year 2010. Conversely, December 31st 2012 is a Monday,
   * so is part of week 1 of week-year 2013.
   */
  static get Iso(): IWeekYearRule {
    return (iso ??= SimpleWeekYearRule.NewMinDaysInFirstWeekFirstDayOfWeekIrregularWeeks(4, IsoDayOfWeek.Monday, false));
  }

  /**
   * Creates a week year rule where the boundary between one week-year and the next
   * is parameterized in terms of how many days of the first week of the week
   * year have to be in the new calendar year, and also (optionally) by which day is deemed
   * to be the first day of the week. Without `firstDayOfWeek`, weeks are always deemed to begin on a Monday.
   *
   * `minDaysInFirstWeek` determines when the first week of the week-year starts.
   * For any given calendar year X, consider the week that includes the first day of the
   * calendar year. Usually, some days of that week are in calendar year X, and some are in calendar year
   * X-1. If `minDaysInFirstWeek` or more of the days are in year X, then the week is
   * deemed to be the first week of week-year X. Otherwise, the week is deemed to be the last week of
   * week-year X-1, and the first week of week-year X starts on the following `firstDayOfWeek`.
   *
   * @param minDaysInFirstWeek The minimum number of days in the first week (starting on
   * `firstDayOfWeek`) which have to be in the new calendar year for that week
   * to count as being in that week-year. Must be in the range 1 to 7 inclusive.
   * @param firstDayOfWeek The first day of the week.
   * @returns A {@link SimpleWeekYearRule} with the specified minimum number of days in the first
   * week and first day of the week.
   */
  static ForMinDaysInFirstWeek(minDaysInFirstWeek: number, firstDayOfWeek: IsoDayOfWeek = IsoDayOfWeek.Monday): IWeekYearRule {
    return SimpleWeekYearRule.NewMinDaysInFirstWeekFirstDayOfWeekIrregularWeeks(minDaysInFirstWeek, firstDayOfWeek, false);
  }

  /**
   * Creates a rule which behaves the same way as the BCL
   * `Calendar.GetWeekOfYear(DateTime, CalendarWeekRule, DayOfWeek)`
   * method.
   *
   * The BCL week year rules are subtly different to the ISO rules.
   * In particular, the last few days of the calendar year are always part of the same
   * week-year in the BCL rules, whereas in the ISO rules they can fall into the next
   * week-year. (The first few days of the calendar year can be part of the previous
   * week-year in both kinds of rule.) This means that in the BCL rules, some weeks
   * are incomplete, whereas ISO weeks are always exactly 7 days long.
   *
   * noda-js: the BCL enums are represented by their numeric values, as found in culture data
   * ({@link DateTimeFormatInfo.CalendarWeekRule} and {@link DateTimeFormatInfo.FirstDayOfWeek}).
   *
   * @param calendarWeekRule The BCL rule to emulate: a `System.Globalization.CalendarWeekRule` value
   * (0 = FirstDay, 1 = FirstFullWeek, 2 = FirstFourDayWeek).
   * @param firstDayOfWeek The first day of the week to use in the rule: a `System.DayOfWeek` value
   * (0 = Sunday to 6 = Saturday, as returned by `Date.prototype.getDay()`).
   * @returns A rule which behaves the same way as the BCL
   * `Calendar.GetWeekOfYear(DateTime, CalendarWeekRule, DayOfWeek)` method.
   */
  static FromCalendarWeekRule(calendarWeekRule: number, firstDayOfWeek: number): IWeekYearRule {
    let minDaysInFirstWeek: number;
    switch (calendarWeekRule) {
      case CalendarWeekRuleFirstDay: minDaysInFirstWeek = 1; break;
      case CalendarWeekRuleFirstFourDayWeek: minDaysInFirstWeek = 4; break;
      case CalendarWeekRuleFirstFullWeek: minDaysInFirstWeek = 7; break;
      default: throw new ArgumentError(`Unsupported CalendarWeekRule: ${calendarWeekRule}`, "calendarWeekRule");
    }
    return SimpleWeekYearRule.NewMinDaysInFirstWeekFirstDayOfWeekIrregularWeeks(minDaysInFirstWeek, ToIsoDayOfWeek(firstDayOfWeek), true);
  }
}

// System.Globalization.CalendarWeekRule values.
const CalendarWeekRuleFirstDay = 0;
const CalendarWeekRuleFirstFullWeek = 1;
const CalendarWeekRuleFirstFourDayWeek = 2;

// C#: DayOfWeekExtensions.ToIsoDayOfWeek / BclConversions.ToIsoDayOfWeek (BCL interop, not otherwise ported).
function ToIsoDayOfWeek(dayOfWeek: number): IsoDayOfWeek {
  if (!(dayOfWeek >= 0 && dayOfWeek <= 6)) {
    throw new ArgumentOutOfRangeError("dayOfWeek");
  }
  return dayOfWeek === 0 ? IsoDayOfWeek.Sunday : dayOfWeek as IsoDayOfWeek;
}
