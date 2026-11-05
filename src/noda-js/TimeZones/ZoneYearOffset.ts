// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/ZoneYearOffset.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  NodaCultureInfo,
  LocalDate,
  LocalInstant,
  LocalTime,
  NodaConstants,
  Offset,
  Preconditions,
  TransitionMode,
  FormatString,
} from "../internal.ts";
import type { IDateTimeZoneReader, IDateTimeZoneWriter, IEquatable } from "../internal.ts";
import type { Duration } from "../internal.ts";
import { NewArgumentOutOfRangeException, type ArgumentOutOfRangeException } from "../internal.ts";

/**
 * Defines an offset within a year as an expression that can be used to reference multiple
 * years.
 *
 * A year offset defines a way of determining an offset into a year based on certain criteria.
 * The most basic is the month of the year and the day of the month. If only these two are
 * supplied then the offset is always the same day of each year. The only exception is if the
 * day is February 29th, then it only refers to those years that have a February 29th.
 *
 * If the day of the week is specified then the offset determined by the month and day are
 * adjusted to the nearest day that falls on the given day of the week. If the month and day
 * fall on that day of the week then nothing changes. Otherwise the offset is moved forward or
 * backward up to 6 days to make the day fall on the correct day of the week. The direction the
 * offset is moved is determined by the {@link ZoneYearOffset.AdvanceDayOfWeek} property.
 *
 * Finally the {@link ZoneYearOffset.Mode} property determines whether the {@link ZoneYearOffset.TimeOfDay} value
 * is added to the calculated offset to generate an offset within the day.
 *
 * Immutable, thread safe
 * @internal
 */
export class ZoneYearOffset implements IEquatable<ZoneYearOffset> {
  private readonly _dayOfMonth: number;
  private readonly _dayOfWeek: number;
  private readonly _monthOfYear: number;
  private readonly _addDay: boolean;

  /**
   * Gets the method by which offsets are added to Instants to get LocalInstants.
   */
  readonly Mode: TransitionMode;

  /**
   * Gets a value indicating whether [advance day of week].
   */
  readonly AdvanceDayOfWeek: boolean;

  /**
   * Gets the time of day when the rule takes effect.
   */
  readonly TimeOfDay: LocalTime;

  /**
   * Initializes a new instance of the {@link ZoneYearOffset} class.
   * @param mode The transition mode.
   * @param monthOfYear The month year offset.
   * @param dayOfMonth The day of month. Negatives count from end of month.
   * @param dayOfWeek The day of week. 0 means not set.
   * @param advance if set to `true` [advance].
   * @param timeOfDay The tick within the day.
   */
  static NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
    mode: TransitionMode,
    monthOfYear: number,
    dayOfMonth: number,
    dayOfWeek: number,
    advance: boolean,
    timeOfDay: LocalTime,
  ): ZoneYearOffset {
    return new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, false);
  }

  /**
   * Initializes a new instance of the {@link ZoneYearOffset} class.
   * @param mode The transition mode.
   * @param monthOfYear The month year offset.
   * @param dayOfMonth The day of month. Negatives count from end of month.
   * @param dayOfWeek The day of week. 0 means not set.
   * @param advance if set to `true` [advance].
   * @param timeOfDay The time of day at which the transition occurs.
   * @param addDay Whether to add an extra day (for 24:00 handling).
   */
  static NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
    mode: TransitionMode,
    monthOfYear: number,
    dayOfMonth: number,
    dayOfWeek: number,
    advance: boolean,
    timeOfDay: LocalTime,
    addDay: boolean,
  ): ZoneYearOffset {
    return new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, addDay);
  }

  private constructor(
    mode: TransitionMode,
    monthOfYear: number,
    dayOfMonth: number,
    dayOfWeek: number,
    advance: boolean,
    timeOfDay: LocalTime,
    addDay: boolean,
  ) {
    ZoneYearOffset.VerifyFieldValue(1, 12, "monthOfYear", monthOfYear, false);
    ZoneYearOffset.VerifyFieldValue(1, 31, "dayOfMonth", dayOfMonth, true);
    if (dayOfWeek !== 0) {
      ZoneYearOffset.VerifyFieldValue(1, 7, "dayOfWeek", dayOfWeek, false);
    }

    this.Mode = mode;
    this._monthOfYear = monthOfYear;
    this._dayOfMonth = dayOfMonth;
    this._dayOfWeek = dayOfWeek;
    this.AdvanceDayOfWeek = advance;
    this.TimeOfDay = timeOfDay;
    this._addDay = addDay;
  }

  /**
   * Verifies the input value against the valid range of the calendar field.
   *
   * If this becomes more widely required, move to Preconditions.
   * @param minimum The minimum valid value.
   * @param maximum The maximum valid value (inclusive).
   * @param name The name of the field for the error message.
   * @param value The value to check.
   * @param allowNegated if set to `true` all the range of value to be the negative as well.
   * @throws {ArgumentOutOfRangeException} If the given value is not in the valid range of the given calendar field.
   */
  private static VerifyFieldValue(minimum: number, maximum: number, name: string, value: number, allowNegated: boolean): void {
    let failed = false;
    if (allowNegated && value < 0) {
      if (value < -maximum || -minimum < value) {
        failed = true;
      }
    } else {
      if (value < minimum || maximum < value) {
        failed = true;
      }
    }
    if (failed) {
      const range = allowNegated ? `[${minimum}, ${maximum}] or [${-maximum}, ${-minimum}]` : `[${minimum}, ${maximum}]`;
      throw NewArgumentOutOfRangeException(name, value, `${name} is not in the valid range: ${range}`);
    }
  }

  // #region IEquatable<ZoneYearOffset> Members

  /**
   * Indicates whether the current object is equal to another object of the same type.
   * (Merges NodaTime's Equals(ZoneYearOffset) and Equals(object).)
   * @param other An object to compare with this object.
   * @returns true if the current object is equal to the `other` parameter; otherwise, false.
   */
  Equals(other: ZoneYearOffset): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    if (!(other instanceof ZoneYearOffset)) {
      return false;
    }
    if (this === other) {
      return true;
    }
    return (
      this.Mode === other.Mode &&
      this._monthOfYear === other._monthOfYear &&
      this._dayOfMonth === other._dayOfMonth &&
      this._dayOfWeek === other._dayOfWeek &&
      this.AdvanceDayOfWeek === other.AdvanceDayOfWeek &&
      this.TimeOfDay.Equals(other.TimeOfDay) &&
      this._addDay === other._addDay
    );
  }

  // #endregion

  toString(): string {
    return FormatString(
      "ZoneYearOffset[mode:{0} monthOfYear:{1} dayOfMonth:{2} dayOfWeek:{3} advance:{4} timeOfDay:{5} addDay:{6}]",
      TransitionMode[this.Mode],
      this._monthOfYear,
      this._dayOfMonth,
      this._dayOfWeek,
      this.AdvanceDayOfWeek ? "True" : "False",
      this.TimeOfDay.toString("r", NodaCultureInfo.InvariantCulture),
      this._addDay ? "True" : "False",
    );
  }

  /**
   * Returns the occurrence of this rule within the given year, as a LocalInstant.
   *
   * LocalInstant is used here so that we can use the representation of "AfterMaxValue"
   * for December 31st 9999 24:00.
   * @internal
   */
  GetOccurrenceForYear(year: number): LocalInstant {
    let actualDayOfMonth =
      this._dayOfMonth > 0 ? this._dayOfMonth : CalendarSystem.Iso.GetDaysInMonth(year, this._monthOfYear) + this._dayOfMonth + 1;
    if (this._monthOfYear === 2 && this._dayOfMonth === 29 && !CalendarSystem.Iso.IsLeapYear(year)) {
      // In zic.c, this would result in an error if dayOfWeek is 0 or AdvanceDayOfWeek is true.
      // However, it's very convenient to be able to ask any rule for its occurrence in any year.
      // We rely on genuine rules being well-written - and before releasing an nzd file we always
      // check that it's in line with zic anyway. Ignoring the brokenness is simpler than fixing
      // rules that are only in force for a single year.
      actualDayOfMonth = 28; // We'll now look backwards for the right day-of-week.
    }
    let date = new LocalDate(year, this._monthOfYear, actualDayOfMonth);
    if (this._dayOfWeek !== 0) {
      // Optimized "go to next or previous occurrence of day or week". Try to do as few comparisons
      // as possible, and only fetch DayOfWeek once. (If we call Next or Previous, it will work it out again.)
      const currentDayOfWeek = date.DayOfWeek as number;
      if (currentDayOfWeek !== this._dayOfWeek) {
        let diff = this._dayOfWeek - currentDayOfWeek;
        if (diff > 0) {
          if (!this.AdvanceDayOfWeek) {
            diff -= 7;
          }
        } else if (this.AdvanceDayOfWeek) {
          diff += 7;
        }
        date = date.PlusDays(diff);
      }
    }
    if (this._addDay) {
      // Adding a day to the last representable day will fail, but we can return an infinite value instead.
      if (year === 9999 && date.Month === 12 && date.Day === 31) {
        return LocalInstant.AfterMaxValue;
      }
      date = date.PlusDays(1);
    }
    return date.At(this.TimeOfDay).ToLocalInstant();
  }

  /**
   * Writes this object to the given {@link IDateTimeZoneWriter}.
   * @param writer Where to send the output.
   * @internal
   */
  Write(writer: IDateTimeZoneWriter): void {
    // Flags contains four pieces of information in a single byte:
    // 0MMDDDAP:
    // - MM is the mode (0-2)
    // - DDD is the day of week (0-7)
    // - A is the AdvanceDayOfWeek
    // - P is the "addDay" (24:00) flag
    const flags = (this.Mode << 5) |
      (this._dayOfWeek << 2) |
      (this.AdvanceDayOfWeek ? 2 : 0) |
      (this._addDay ? 1 : 0);
    writer.WriteByte(flags & 0xff);
    writer.WriteCount(this._monthOfYear);
    writer.WriteSignedCount(this._dayOfMonth);
    // The time of day is written as a number of milliseconds historical reasons.
    writer.WriteMilliseconds(Math.trunc(this.TimeOfDay.TickOfDay / NodaConstants.TicksPerMillisecond));
  }

  static Read(reader: IDateTimeZoneReader): ZoneYearOffset {
    Preconditions.CheckNotNull(reader, "reader");
    const flags = reader.ReadByte();
    const mode = (flags >> 5) as TransitionMode;
    const dayOfWeek = (flags >> 2) & 7;
    const advance = (flags & 2) !== 0;
    const addDay = (flags & 1) !== 0;
    const monthOfYear = reader.ReadCount();
    const dayOfMonth = reader.ReadSignedCount();
    // The time of day is written as a number of milliseconds for historical reasons.
    const timeOfDay = LocalTime.FromMillisecondsSinceMidnight(reader.ReadMilliseconds());
    return new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, addDay);
  }

  /**
   * Returns the offset to use for this rule's {@link TransitionMode}.
   * The year/month/day/time for a rule is in a specific frame of reference:
   * UTC, "wall" or "standard".
   * @param standardOffset The standard offset.
   * @param savings The daylight savings adjustment.
   * @returns The base time offset as a {@link Duration}.
   * @internal
   */
  GetRuleOffset(standardOffset: Offset, savings: Offset): Offset {
    switch (this.Mode) {
      case TransitionMode.Wall:
        return standardOffset.Plus(savings);
      case TransitionMode.Standard:
        return standardOffset;
      default:
        return Offset.Zero;
    }
  }

  // #region Object overrides

  // Equals(object) is merged into Equals() above.
  // Not ported: GetHashCode (see docs/porting-conventions.md)

  // #endregion
}
