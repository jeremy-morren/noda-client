// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/IslamicYearMonthDayCalculator.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  IslamicEpoch,
  IslamicLeapYearPattern,
  RegularYearMonthDayCalculator,
  YearMonthDay,
} from "../internal.ts";
import { NewArgumentOutOfRangeException } from "../internal.ts";

/** Days in a pair of months, in days. */
const MonthPairLength = 59;

/** The length of a long month, in days. */
const LongMonthLength = 30;

/** The length of a short month, in days. */
const ShortMonthLength = 29;

/** The typical number of days in 10 years. */
const AverageDaysPer10Years = 3544; // Ideally 354.36667 per year

/** The number of days in a non-leap year. */
const DaysPerNonLeapYear = 354;

/** The number of days in a leap year. */
const DaysPerLeapYear = 355;

/** The days for the civil (Friday) epoch of July 16th 622CE. */
const DaysAtCivilEpoch = -492148;

/** The days for the civil (Thursday) epoch of July 15th 622CE. */
const DaysAtAstronomicalEpoch = DaysAtCivilEpoch - 1;

/** The length of the cycle of leap years. */
const LeapYearCycleLength = 30;

/** The number of days in leap cycle. */
const DaysPerLeapCycle = 19 * DaysPerNonLeapYear + 11 * DaysPerLeapYear;

/** The number of days preceding the 1-indexed month - so [0, 0, 30, 59, ...] */
const TotalDaysByMonth: readonly number[] = GenerateTotalDaysByMonth();

function GenerateTotalDaysByMonth(): number[] {
  let days = 0;
  const ret = new Array<number>(13).fill(0);
  for (let i = 1; i <= 12; i++) {
    ret[i] = days;
    // Here, the month number is 1-based, so odd months are long
    const daysInMonth = (i & 1) === 1 ? LongMonthLength : ShortMonthLength;
    // This doesn't take account of leap years, but that doesn't matter - because
    // it's not used on the last iteration, and leap years only affect the final month
    // in the Islamic calendar.
    days += daysInMonth;
  }
  return ret;
}

/** @internal */
export class IslamicYearMonthDayCalculator extends RegularYearMonthDayCalculator {
  /** The pattern of leap years within a cycle, one bit per year, for this calendar. */
  private readonly _leapYearPatternBits: number;

  private constructor(leapYearPattern: IslamicLeapYearPattern, epoch: IslamicEpoch) {
    super(1, 9665, 12, AverageDaysPer10Years, GetYear1Days(epoch));
    this._leapYearPatternBits = GetLeapYearPatternBits(leapYearPattern);
  }

  /** C#: `internal IslamicYearMonthDayCalculator(IslamicLeapYearPattern leapYearPattern, IslamicEpoch epoch)` */
  static NewLeapYearPatternEpoch(leapYearPattern: IslamicLeapYearPattern, epoch: IslamicEpoch): IslamicYearMonthDayCalculator {
    return new IslamicYearMonthDayCalculator(leapYearPattern, epoch);
  }

  // The number of days at the *start* of a month isn't affected by
  // the year as the only month length which varies by year is the last one.
  /** @inheritDoc */
  protected override GetDaysFromStartOfYearToStartOfMonth(year: number, month: number): number {
    void year;
    return TotalDaysByMonth[month]!;
  }

  // C#: override of GetYearMonthDay(int year, int dayOfYear)
  /** @inheritDoc */
  protected override GetYearMonthDayFromYearAndDayOfYear(year: number, dayOfYear: number): YearMonthDay {
    let month: number, day: number;
    // Special case the last day in a leap year
    if (dayOfYear === DaysPerLeapYear) {
      month = 12;
      day = 30;
    } else {
      const dayOfYearZeroBased = dayOfYear - 1;
      month = Math.trunc((dayOfYearZeroBased * 2) / MonthPairLength) + 1;
      day = ((dayOfYearZeroBased % MonthPairLength) % LongMonthLength) + 1;
    }
    return YearMonthDay.NewYearMonthDay(year, month, day);
  }

  override IsLeapYear(year: number): boolean {
    // Handle negative years in order to make calculations near the start of the calendar work cleanly.
    const yearOfCycle = year >= 0 ? year % LeapYearCycleLength
      : (year % LeapYearCycleLength) + LeapYearCycleLength;
    const key = 1 << yearOfCycle;
    return (this._leapYearPatternBits & key) > 0;
  }

  /** @inheritDoc */
  override GetDaysInYear(year: number): number {
    return this.IsLeapYear(year) ? DaysPerLeapYear : DaysPerNonLeapYear;
  }

  override GetDaysInMonth(year: number, month: number): number {
    if (month === 12 && this.IsLeapYear(year)) {
      return LongMonthLength;
    }
    // Note: month is 1-based here, so even months are the short ones
    return (month & 1) === 0 ? ShortMonthLength : LongMonthLength;
  }

  /** @inheritDoc */
  protected override CalculateStartOfYearDays(year: number): number {
    // The first cycle starts in year 1, not year 0.
    // We try to cope with years outside the normal range, in order to allow arithmetic at the boundaries.
    const cycle = year > 0 ? Math.trunc((year - 1) / LeapYearCycleLength)
      : Math.trunc((year - LeapYearCycleLength) / LeapYearCycleLength);
    const yearAtStartOfCycle = (cycle * LeapYearCycleLength) + 1;

    let days = this.DaysAtStartOfYear1 + cycle * DaysPerLeapCycle;

    // We've got the days at the start of the cycle (e.g. at the start of year 1, 31, 61 etc).
    // Now go from that year to (but not including) the year we're looking for, adding the right
    // number of days in each year. So if we're trying to find the start of year 34, we would
    // find the days at the start of year 31, then add the days *in* year 31, the days in year 32,
    // and the days in year 33.
    // If this ever proves to be a bottleneck, we could create an array for each IslamicLeapYearPattern
    // with "the number of days for the first n years in a cycle".
    for (let i = yearAtStartOfCycle; i < year; i++) {
      days += this.GetDaysInYear(i);
    }
    return days;
  }
}

/**
 * Returns the pattern of leap years within a cycle, one bit per year, for the specified pattern.
 * Note that although cycle years are usually numbered 1-30, the bit pattern is for 0-29; cycle year
 * 30 is represented by bit 0.
 */
function GetLeapYearPatternBits(leapYearPattern: IslamicLeapYearPattern): number {
  switch (leapYearPattern) {
    // When reading bit patterns, don't forget to read right to left...
    case IslamicLeapYearPattern.Base15: return 623158436;        // 0b100101001001001010010010100100
    case IslamicLeapYearPattern.Base16: return 623191204;        // 0b100101001001010010010010100100
    case IslamicLeapYearPattern.Indian: return 690562340;        // 0b101001001010010010010100100100
    case IslamicLeapYearPattern.HabashAlHasib: return 153692453; // 0b001001001010010010100100100101
    default: throw NewArgumentOutOfRangeException("leapYearPattern");
  }
}

/**
 * Returns the days since the Unix epoch at the specified epoch.
 */
function GetYear1Days(epoch: IslamicEpoch): number {
  switch (epoch) {
    // Epoch 1970-01-01 ISO = 1389-10-22 Islamic (civil) or 1389-10-23 Islamic (astronomical)
    case IslamicEpoch.Astronomical: return DaysAtAstronomicalEpoch;
    case IslamicEpoch.Civil: return DaysAtCivilEpoch;
    default: throw NewArgumentOutOfRangeException("epoch");
  }
}
