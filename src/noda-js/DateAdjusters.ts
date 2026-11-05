// Ported from NodaTime 3.3.0: src/NodaTime/DateAdjusters.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  ArgumentOutOfRangeError,
  IsoDayOfWeek,
  LocalDate,
  Preconditions,
  type Period,
} from "./internal.ts";
import type { LocalDateTime, OffsetDateTime } from "./internal.ts";

const StartOfMonth = (date: LocalDate): LocalDate =>
  new LocalDate(date.Year, date.Month, 1, date.Calendar);

const EndOfMonth = (date: LocalDate): LocalDate =>
  new LocalDate(date.Year, date.Month, date.Calendar.GetDaysInMonth(date.Year, date.Month), date.Calendar);

/**
 * Factory class for date adjusters: functions from {@link LocalDate} to `LocalDate`,
 * which can be applied to {@link LocalDate}, {@link LocalDateTime}, and {@link OffsetDateTime}.
 */
export class DateAdjusters {
  private constructor() {}

  /**
   * A date adjuster to move to the first day of the current month.
   */
  static get StartOfMonth(): (date: LocalDate) => LocalDate {
    return StartOfMonth;
  }

  /**
   * A date adjuster to move to the last day of the current month.
   */
  static get EndOfMonth(): (date: LocalDate) => LocalDate {
    return EndOfMonth;
  }

  /**
   * A date adjuster to move to the specified day of the current month.
   *
   * The returned adjuster will throw an exception if it is applied to a date
   * that would create an invalid result.
   *
   * @param day The day of month to adjust dates to.
   * @returns An adjuster which changes the day to `day`,
   * retaining the same year and month.
   */
  static DayOfMonth(day: number): (date: LocalDate) => LocalDate {
    return date => new LocalDate(date.Year, date.Month, day, date.Calendar);
  }

  /**
   * A date adjuster to move to the same day of the specified month.
   *
   * The returned adjuster will throw an exception if it is applied to a date
   * that would create an invalid result.
   *
   * @param month The month to adjust dates to.
   * @returns An adjuster which changes the month to `month`,
   * retaining the same year and day of month.
   */
  static Month(month: number): (date: LocalDate) => LocalDate {
    return date => new LocalDate(date.Year, month, date.Day, date.Calendar);
  }

  /**
   * A date adjuster to move to the next specified day-of-week, but return the
   * original date if the day is already correct.
   * @param dayOfWeek The day-of-week to adjust dates to.
   * @returns An adjuster which advances a date to the next occurrence of the
   * specified day-of-week, or the original date if the day is already correct.
   */
  static NextOrSame(dayOfWeek: IsoDayOfWeek): (date: LocalDate) => LocalDate {
    // Avoids boxing...
    if (!(dayOfWeek >= IsoDayOfWeek.Monday && dayOfWeek <= IsoDayOfWeek.Sunday)) {
      throw new ArgumentOutOfRangeError("dayOfWeek");
    }
    return date => date.DayOfWeek === dayOfWeek ? date : date.Next(dayOfWeek);
  }

  /**
   * A date adjuster to move to the previous specified day-of-week, but return the
   * original date if the day is already correct.
   * @param dayOfWeek The day-of-week to adjust dates to.
   * @returns An adjuster which advances a date to the previous occurrence of the
   * specified day-of-week, or the original date if the day is already correct.
   */
  static PreviousOrSame(dayOfWeek: IsoDayOfWeek): (date: LocalDate) => LocalDate {
    // Avoids boxing...
    if (!(dayOfWeek >= IsoDayOfWeek.Monday && dayOfWeek <= IsoDayOfWeek.Sunday)) {
      throw new ArgumentOutOfRangeError("dayOfWeek");
    }
    return date => date.DayOfWeek === dayOfWeek ? date : date.Previous(dayOfWeek);
  }

  /**
   * A date adjuster to move to the next specified day-of-week, adding
   * a week if the day is already correct.
   *
   * This is the adjuster equivalent of {@link LocalDate.Next}.
   *
   * @param dayOfWeek The day-of-week to adjust dates to.
   * @returns An adjuster which advances a date to the next occurrence of the
   * specified day-of-week.
   */
  static Next(dayOfWeek: IsoDayOfWeek): (date: LocalDate) => LocalDate {
    // Avoids boxing...
    if (!(dayOfWeek >= IsoDayOfWeek.Monday && dayOfWeek <= IsoDayOfWeek.Sunday)) {
      throw new ArgumentOutOfRangeError("dayOfWeek");
    }
    return date => date.Next(dayOfWeek);
  }

  /**
   * A date adjuster to move to the previous specified day-of-week, subtracting
   * a week if the day is already correct.
   *
   * This is the adjuster equivalent of {@link LocalDate.Previous}.
   *
   * @param dayOfWeek The day-of-week to adjust dates to.
   * @returns An adjuster which advances a date to the previous occurrence of the
   * specified day-of-week.
   */
  static Previous(dayOfWeek: IsoDayOfWeek): (date: LocalDate) => LocalDate {
    // Avoids boxing...
    if (!(dayOfWeek >= IsoDayOfWeek.Monday && dayOfWeek <= IsoDayOfWeek.Sunday)) {
      throw new ArgumentOutOfRangeError("dayOfWeek");
    }
    return date => date.Previous(dayOfWeek);
  }

  /**
   * Creates a date adjuster to add the specified period to the date.
   *
   * This is the adjuster equivalent of {@link LocalDate.Plus}.
   *
   * @param period The period to add when the adjuster is invoked. Must not contain any (non-zero) time units.
   * @returns An adjuster which adds the specified period.
   */
  static AddPeriod(period: Period): (date: LocalDate) => LocalDate {
    Preconditions.CheckNotNull(period, "period");
    // Perform this validation eagerly. It will be performed on each invocation as well,
    // but it's good to throw an exception now rather than waiting for the first invocation.
    Preconditions.CheckArgument(!period.HasTimeComponent, "period", "Cannot add a period with a time component to a date");
    return date => LocalDate.Add(date, period);
  }
}
