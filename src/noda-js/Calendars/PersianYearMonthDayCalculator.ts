// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/PersianYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions, RegularYearMonthDayCalculator, YearMonthDay, NewNotImplementedException } from "../internal.ts";
import { AstronomicalLeapYearBits } from "./PersianYearMonthDayCalculatorAstronomicalData.generated.ts";

const DaysPerNonLeapYear = (31 * 6) + (30 * 5) + 29;
const DaysPerLeapYear = DaysPerNonLeapYear + 1;
// Approximation; it'll be pretty close in all variants.
const AverageDaysPer10Years = Math.trunc((DaysPerNonLeapYear * 25 + DaysPerLeapYear * 8) * 10 / 33);
const MaxPersianYear = 9377;

/** The number of days preceding the 1-indexed month - so [0, 0, 31, 62, 93, ...] */
const TotalDaysByMonth: readonly number[] = GenerateTotalDaysByMonth();

function GenerateTotalDaysByMonth(): number[] {
  let days = 0;
  const ret = new Array<number>(13).fill(0);
  for (let i = 1; i <= 12; i++) {
    ret[i] = days;
    const daysInMonth = i <= 6 ? 31 : 30;
    // This doesn't take account of leap years, but that doesn't matter - because
    // it's not used on the last iteration, and leap years only affect the final month
    // in the Persian calendar.
    days += daysInMonth;
  }
  return ret;
}

/**
 * Base class for the three variants of the Persian (Solar Hijri) calendar.
 * Concrete subclasses are nested to allow different start dates and leap year calculations.
 *
 * The constructor uses IsLeapYear to precompute lots of data; it is therefore important that
 * the implementation of IsLeapYear in subclasses uses no instance fields.
 *
 * Deviation from the porting conventions: the nested classes (`Simple`, `Arithmetic`, `Astronomical`) extend
 * this class, so they're declared *after* it in this file (a class can't extend one declared later), and the
 * `Simple`/`Arithmetic`/`Astronomical` statics are getters rather than `static readonly` fields (which would
 * read the subclasses before they're declared).
 * @internal
 */
export abstract class PersianYearMonthDayCalculator extends RegularYearMonthDayCalculator {
  static readonly MaxPersianYear = MaxPersianYear;

  /** C#: nested class `Simple`. */
  static get Simple(): typeof PersianYearMonthDayCalculatorSimple {
    return PersianYearMonthDayCalculatorSimple;
  }

  /** C#: nested class `Arithmetic`. */
  static get Arithmetic(): typeof PersianYearMonthDayCalculatorArithmetic {
    return PersianYearMonthDayCalculatorArithmetic;
  }

  /** C#: nested class `Astronomical`. */
  static get Astronomical(): typeof PersianYearMonthDayCalculatorAstronomical {
    return PersianYearMonthDayCalculatorAstronomical;
  }

  private readonly _startOfYearInDaysCache: number[];

  // C#: private, but TypeScript doesn't let subclasses (C#'s nested classes) call a private constructor.
  protected constructor(daysAtStartOfYear1: number) {
    super(1, MaxPersianYear, 12, AverageDaysPer10Years, daysAtStartOfYear1);
    this._startOfYearInDaysCache = new Array<number>(this.MaxYear + 2).fill(0);
    let startOfYear = this.DaysAtStartOfYear1 - this.GetDaysInYear(0);
    for (let year = 0; year <= this.MaxYear + 1; year++) {
      this._startOfYearInDaysCache[year] = startOfYear;
      startOfYear += this.GetDaysInYear(year);
    }
  }

  protected override GetDaysFromStartOfYearToStartOfMonth(year: number, month: number): number {
    void year;
    return TotalDaysByMonth[month]!;
  }

  override GetStartOfYearInDays(year: number): number {
    Preconditions.DebugCheckArgumentRange("year", year, this.MinYear - 1, this.MaxYear + 1);
    return this._startOfYearInDaysCache[year]!;
  }

  // C#: [ExcludeFromCodeCoverage]
  protected override CalculateStartOfYearDays(year: number): number {
    void year;
    // This would only be called from GetStartOfYearInDays, which is overridden.
    // C#: throw new NotImplementedException();
    throw NewNotImplementedException();
  }

  protected override GetYearMonthDayFromYearAndDayOfYear(year: number, dayOfYear: number): YearMonthDay {
    const dayOfYearZeroBased = dayOfYear - 1;
    let month: number;
    let day: number;
    if (dayOfYear === DaysPerLeapYear) {
      // Last day of a leap year.
      month = 12;
      day = 30;
    } else if (dayOfYearZeroBased < 6 * 31) {
      // In the first 6 months, all of which are 31 days long.
      month = Math.trunc(dayOfYearZeroBased / 31) + 1;
      day = (dayOfYearZeroBased % 31) + 1;
    } else {
      // Last 6 months (other than last day of leap year).
      // Work out where we are within that 6 month block, then use simple arithmetic.
      const dayOfSecondHalf = dayOfYearZeroBased - 6 * 31;
      month = Math.trunc(dayOfSecondHalf / 30) + 7;
      day = (dayOfSecondHalf % 30) + 1;
    }
    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  override GetDaysInMonth(year: number, month: number): number {
    return month < 7 ? 31
      : month < 12 ? 30
        : this.IsLeapYear(year) ? 30 : 29;
  }

  override GetDaysInYear(year: number): number {
    return this.IsLeapYear(year) ? DaysPerLeapYear : DaysPerNonLeapYear;
  }
}

// This is a long because we're notionally handling 33 bits. The top bit is
// false anyway, but IsLeapYear shifts a long for simplicity, so let's be consistent with that.
// (In TypeScript, every set bit is below bit 31, so the value fits in a 32-bit integer.)
const LeapYearPatternBits = (1 << 1) | (1 << 5) | (1 << 9) | (1 << 13)
  | (1 << 17) | (1 << 22) | (1 << 26) | (1 << 30);
const LeapYearCycleLength = 33;

/** The ticks for the epoch of March 21st 622CE. */
const DaysAtStartOfYear1Constant = -492268;

/**
 * Persian calendar using the simple 33-year cycle of 1, 5, 9, 13, 17, 22, 26, or 30.
 * This corresponds to System.Globalization.PersianCalendar before .NET 4.6.
 *
 * C#: nested class `PersianYearMonthDayCalculator.Simple`.
 * @internal
 */
export class PersianYearMonthDayCalculatorSimple extends PersianYearMonthDayCalculator {
  private constructor() {
    super(DaysAtStartOfYear1Constant);
  }

  static New(): PersianYearMonthDayCalculatorSimple {
    return new PersianYearMonthDayCalculatorSimple();
  }

  /**
   * Leap year condition using the simple 33-year cycle of 1, 5, 9, 13, 17, 22, 26, or 30.
   * This corresponds to System.Globalization.PersianCalendar before .NET 4.6.
   */
  override IsLeapYear(year: number): boolean {
    // Handle negative years in order to make calculations near the start of the calendar work cleanly.
    const yearOfCycle = year >= 0 ? year % LeapYearCycleLength
      : (year % LeapYearCycleLength) + LeapYearCycleLength;
    // Note the shift of 1L rather than 1, to avoid issues where shifting by 32
    // would get us back to 1.
    // (JS shifts are 32-bit, so a shift by 32 or 33 would wrap. C#'s `1L << yearOfCycle` for those
    // values has no bit in common with LeapYearPatternBits, so check the range instead.)
    if (yearOfCycle >= 32) {
      return false;
    }
    const key = 1 << yearOfCycle;
    return (LeapYearPatternBits & key) > 0;
  }
}

/**
 * Persian calendar based on Birashk's subcycle/cycle/grand cycle scheme.
 *
 * C#: nested class `PersianYearMonthDayCalculator.Arithmetic`.
 * @internal
 */
export class PersianYearMonthDayCalculatorArithmetic extends PersianYearMonthDayCalculator {
  private constructor() {
    super(-492267);
  }

  static New(): PersianYearMonthDayCalculatorArithmetic {
    return new PersianYearMonthDayCalculatorArithmetic();
  }

  override IsLeapYear(year: number): boolean {
    // Offset the cycles for easier arithmetic.
    const offsetYear = year > 0 ? year - 474 : year - 473;
    const cycleYear = (offsetYear % 2820) + 474;
    return ((cycleYear + 38) * 31) % 128 < 31;
  }
}

/**
 * Persian calendar based on stored BCL 4.6 information (avoids complex arithmetic for
 * midday in Tehran).
 *
 * C#: nested class `PersianYearMonthDayCalculator.Astronomical`.
 * @internal
 */
export class PersianYearMonthDayCalculatorAstronomical extends PersianYearMonthDayCalculator {
  // Ugly, but the simplest way of embedding a big chunk of binary data...
  // C#: private static readonly byte[] AstronomicalLeapYearBits = Convert.FromBase64String("ICIiIkJERESEiIiI...");
  // The decoded bytes are generated into PersianYearMonthDayCalculatorAstronomicalData.generated.ts (imported above).

  private constructor() {
    super(-492267);
  }

  static New(): PersianYearMonthDayCalculatorAstronomical {
    return new PersianYearMonthDayCalculatorAstronomical();
  }

  // 8 years per byte.
  override IsLeapYear(year: number): boolean {
    return (AstronomicalLeapYearBits[year >> 3]! & (1 << (year & 7))) !== 0;
  }
}
