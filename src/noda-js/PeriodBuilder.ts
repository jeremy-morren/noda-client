// Ported from NodaTime 3.3.0: src/NodaTime/PeriodBuilder.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ArgumentOutOfRangeError, Int32, Int64, Period, PeriodUnits, Preconditions } from "./internal.ts";
import type { Int64Value, Long } from "./internal.ts";

/**
 * A mutable builder class for {@link Period} values. Each property can
 * be set independently, and then a Period can be created from the result
 * using the {@link Build} method.
 *
 * This type is not thread-safe without extra synchronization, but has no
 * thread affinity.
 */
export class PeriodBuilder {
  private _yearsValue = 0;
  private _monthsValue = 0;
  private _weeksValue = 0;
  private _daysValue = 0;
  // noda-js: the long-valued properties are held exactly, as Int64Values (see Period.ts). Their setters accept a number
  // or a decimal string (exact beyond 2^53), as Int64.fromArgument does; the getters return the nearest number.
  private _hoursValue: Int64Value = 0;
  private _minutesValue: Int64Value = 0;
  private _secondsValue: Int64Value = 0;
  private _millisecondsValue: Int64Value = 0;
  private _ticksValue: Int64Value = 0;
  private _nanosecondsValue: Int64Value = 0;

  // #region Properties
  /**
   * Gets or sets the number of years within the period.
   */
  get Years(): number {
    return this._yearsValue;
  }

  set Years(value: number) {
    this._yearsValue = value;
  }

  /**
   * Gets or sets the number of months within the period.
   */
  get Months(): number {
    return this._monthsValue;
  }

  set Months(value: number) {
    this._monthsValue = value;
  }

  /**
   * Gets or sets the number of weeks within the period.
   */
  get Weeks(): number {
    return this._weeksValue;
  }

  set Weeks(value: number) {
    this._weeksValue = value;
  }

  /**
   * Gets or sets the number of days within the period.
   */
  get Days(): number {
    return this._daysValue;
  }

  set Days(value: number) {
    this._daysValue = value;
  }

  /**
   * Gets or sets the number of hours within the period.
   */
  get Hours(): number {
    return Int64.ToNumber(this._hoursValue);
  }

  set Hours(value: number | string) {
    this._hoursValue = Int64.FromArgument(value, "value");
  }

  /**
   * Gets or sets the number of minutes within the period.
   */
  get Minutes(): number {
    return Int64.ToNumber(this._minutesValue);
  }

  set Minutes(value: number | string) {
    this._minutesValue = Int64.FromArgument(value, "value");
  }

  /**
   * Gets or sets the number of seconds within the period.
   */
  get Seconds(): number {
    return Int64.ToNumber(this._secondsValue);
  }

  set Seconds(value: number | string) {
    this._secondsValue = Int64.FromArgument(value, "value");
  }

  /**
   * Gets or sets the number of milliseconds within the period.
   */
  get Milliseconds(): number {
    return Int64.ToNumber(this._millisecondsValue);
  }

  set Milliseconds(value: number | string) {
    this._millisecondsValue = Int64.FromArgument(value, "value");
  }

  /**
   * Gets or sets the number of ticks within the period.
   */
  get Ticks(): number {
    return Int64.ToNumber(this._ticksValue);
  }

  set Ticks(value: number | string) {
    this._ticksValue = Int64.FromArgument(value, "value");
  }

  /**
   * Gets or sets the number of nanoseconds within the period.
   */
  get Nanoseconds(): number {
    return Int64.ToNumber(this._nanosecondsValue);
  }

  set Nanoseconds(value: number | string) {
    this._nanosecondsValue = Int64.FromArgument(value, "value");
  }
  // #endregion

  /**
   * Creates a new period builder with an initially zero period.
   */
  constructor();
  /**
   * Creates a new period builder with the values from an existing
   * period. Calling this constructor instead of {@link Period.ToBuilder}
   * allows object initializers to be used.
   *
   * @param period An existing period to copy values from.
   */
  constructor(period: Period);
  constructor(...args: [] | [Period]) {
    if (args.length === 0) {
      return;
    }
    const period = args[0];
    Preconditions.CheckNotNull(period, "period");
    this.Years = period.Years;
    this.Months = period.Months;
    this.Weeks = period.Weeks;
    this.Days = period.Days;
    this._hoursValue = period.ExactHours;
    this._minutesValue = period.ExactMinutes;
    this._secondsValue = period.ExactSeconds;
    this._millisecondsValue = period.ExactMilliseconds;
    this._ticksValue = period.ExactTicks;
    this._nanosecondsValue = period.ExactNanoseconds;
  }

  /**
   * Gets the value of a single unit. (The getter of NodaTime's indexer, `this[PeriodUnits unit]`.)
   *
   * The type of this indexer is long for uniformity, but any date unit (year, month, week, day) will only ever have a value
   * in the range of int.
   *
   * @param unit A single value within the {@link PeriodUnits} enumeration.
   * @returns The value of the given unit within this period builder, or zero if the unit is unset.
   * @throws {ArgumentOutOfRangeError} `unit` is not a single unit.
   */
  Get(unit: PeriodUnits): number {
    switch (unit) {
      case PeriodUnits.Years: return this.Years;
      case PeriodUnits.Months: return this.Months;
      case PeriodUnits.Weeks: return this.Weeks;
      case PeriodUnits.Days: return this.Days;
      case PeriodUnits.Hours: return Int64.ToNumber(this._hoursValue);
      case PeriodUnits.Minutes: return Int64.ToNumber(this._minutesValue);
      case PeriodUnits.Seconds: return Int64.ToNumber(this._secondsValue);
      case PeriodUnits.Milliseconds: return Int64.ToNumber(this._millisecondsValue);
      case PeriodUnits.Ticks: return Int64.ToNumber(this._ticksValue);
      case PeriodUnits.Nanoseconds: return Int64.ToNumber(this._nanosecondsValue);
      default: throw new ArgumentOutOfRangeError("unit", undefined, "Indexer for PeriodBuilder only takes a single unit");
    }
  }

  /**
   * Sets the value of a single unit. (The setter of NodaTime's indexer, `this[PeriodUnits unit]`.)
   *
   * @param unit A single value within the {@link PeriodUnits} enumeration.
   * @param value The new value of the given unit.
   * @throws {ArgumentOutOfRangeError} `unit` is not a single unit, or a value is provided for a date unit which is outside the range of int.
   */
  Set(unit: PeriodUnits, value: number | string): void;
  /**
   * noda-js: internal callers (the period parsers) may also pass an exact Long.
   * @internal
   */
  Set(unit: PeriodUnits, value: number | string | Long): void;
  Set(unit: PeriodUnits, value: number | string | Long): void {
    // noda-js: the C# long argument, exactly.
    const longValue = Int64.FromArgument(value, "value");
    if ((unit & PeriodUnits.AllDateUnits) !== 0) {
      Preconditions.CheckArgumentRange("value", longValue, Int32.MinValue, Int32.MaxValue);
    }
    switch (unit) {
      case PeriodUnits.Years: this.Years = longValue as number; return;
      case PeriodUnits.Months: this.Months = longValue as number; return;
      case PeriodUnits.Weeks: this.Weeks = longValue as number; return;
      case PeriodUnits.Days: this.Days = longValue as number; return;
      case PeriodUnits.Hours: this._hoursValue = longValue; return;
      case PeriodUnits.Minutes: this._minutesValue = longValue; return;
      case PeriodUnits.Seconds: this._secondsValue = longValue; return;
      case PeriodUnits.Milliseconds: this._millisecondsValue = longValue; return;
      case PeriodUnits.Ticks: this._ticksValue = longValue; return;
      case PeriodUnits.Nanoseconds: this._nanosecondsValue = longValue; return;
      default: throw new ArgumentOutOfRangeError("unit", undefined, "Indexer for PeriodBuilder only takes a single unit");
    }
  }

  /**
   * Builds a period from the properties in this builder.
   *
   * @returns A period containing the values from this builder.
   */
  Build(): Period {
    return Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
      this.Years, this.Months, this.Weeks, this.Days, this._hoursValue, this._minutesValue, this._secondsValue, this._millisecondsValue,
      this._ticksValue, this._nanosecondsValue);
  }

  // Not ported: AddSchema, IXmlSerializable.GetSchema/ReadXml/WriteXml (XML serialization)
}
