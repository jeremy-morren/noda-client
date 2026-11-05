// Ported from NodaTime 3.3.7: src/NodaTime/Calendars/HebrewScripturalCalculator.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions, YearMonthDay, YearStartCacheEntry } from "../internal.ts";

const MaxYear = 9999;
const MinYear = 1;
// Use the bottom two bits of the day value to indicate Heshvan/Kislev.
// Using the top bits causes issues for negative day values (only relevant for
// invalid years, but still problematic in general).
const IsHeshvanLongCacheBit = 1 << 0;
const IsKislevShortCacheBit = 1 << 1;
// Number of bits to shift the elapsed days in order to get the cache value.
const ElapsedDaysCacheShift = 2;

// Cache of when each year starts (in  terms of absolute days). This is the heart of
// the algorithm, so just caching this is highly effective.
// Each entry additionally encodes the length of Heshvan and Kislev. We could encode
// more information too, but those are the tricky bits.
// (C#: static readonly field; created lazily, as module evaluation mustn't depend on other modules.)
let yearCache: YearStartCacheEntry[] | undefined;

/**
 * Implementation of the algorithms described in
 * https://www.cs.tau.ac.il/~nachum/calendar-book/papers/calendar.ps, using scriptural
 * month numbering.
 * @internal
 */
export class HebrewScripturalCalculator {
  private constructor() {}

  static readonly MaxYear = MaxYear;
  static readonly MinYear = MinYear;

  private static get YearCache(): YearStartCacheEntry[] {
    return (yearCache ??= YearStartCacheEntry.CreateCache());
  }

  static IsLeapYear(year: number): boolean {
    return ((year * 7) + 1) % 19 < 7;
  }

  static GetYearMonthDay(year: number, dayOfYear: number): YearMonthDay {
    // unchecked
    // Work out everything about the year in one go.
    const cache = HebrewScripturalCalculator.GetOrPopulateCache(year);
    const heshvanLength = (cache & IsHeshvanLongCacheBit) !== 0 ? 30 : 29;
    const kislevLength = (cache & IsKislevShortCacheBit) !== 0 ? 29 : 30;
    const isLeap = HebrewScripturalCalculator.IsLeapYear(year);
    const firstAdarLength = isLeap ? 30 : 29;

    if (dayOfYear < 31) {
      // Tishri
      return YearMonthDay.NewYearMonthDay(year, 7, dayOfYear);
    }
    if (dayOfYear < 31 + heshvanLength) {
      // Heshvan
      return YearMonthDay.NewYearMonthDay(year, 8, dayOfYear - 30);
    }
    // Now "day of year without Heshvan"...
    dayOfYear -= heshvanLength;
    if (dayOfYear < 31 + kislevLength) {
      // Kislev
      return YearMonthDay.NewYearMonthDay(year, 9, dayOfYear - 30);
    }
    // Now "day of year without Heshvan or Kislev"...
    dayOfYear -= kislevLength;
    if (dayOfYear < 31 + 29) {
      // Tevet
      return YearMonthDay.NewYearMonthDay(year, 10, dayOfYear - 30);
    }
    if (dayOfYear < 31 + 29 + 30) {
      // Shevat
      return YearMonthDay.NewYearMonthDay(year, 11, dayOfYear - (30 + 29));
    }
    if (dayOfYear < 31 + 29 + 30 + firstAdarLength) {
      // Adar / Adar I
      return YearMonthDay.NewYearMonthDay(year, 12, dayOfYear - (30 + 29 + 30));
    }
    // Now "day of year without first month of Adar"
    dayOfYear -= firstAdarLength;
    if (isLeap) {
      if (dayOfYear < 31 + 29 + 30 + 29) {
        return YearMonthDay.NewYearMonthDay(year, 13, dayOfYear - (30 + 29 + 30));
      }
      // Now "day of year without any Adar"
      dayOfYear -= 29;
    }
    // We could definitely do a binary search from here, but it would only
    // a few comparisons at most, and simplicity trumps optimization.
    if (dayOfYear < 31 + 29 + 30 + 30) {
      // Nisan
      return YearMonthDay.NewYearMonthDay(year, 1, dayOfYear - (30 + 29 + 30));
    }
    if (dayOfYear < 31 + 29 + 30 + 30 + 29) {
      // Iyar
      return YearMonthDay.NewYearMonthDay(year, 2, dayOfYear - (30 + 29 + 30 + 30));
    }
    if (dayOfYear < 31 + 29 + 30 + 30 + 29 + 30) {
      // Sivan
      return YearMonthDay.NewYearMonthDay(year, 3, dayOfYear - (30 + 29 + 30 + 30 + 29));
    }
    if (dayOfYear < 31 + 29 + 30 + 30 + 29 + 30 + 29) {
      // Tamuz
      return YearMonthDay.NewYearMonthDay(year, 4, dayOfYear - (30 + 29 + 30 + 30 + 29 + 30));
    }
    if (dayOfYear < 31 + 29 + 30 + 30 + 29 + 30 + 29 + 30) {
      // Av
      return YearMonthDay.NewYearMonthDay(year, 5, dayOfYear - (30 + 29 + 30 + 30 + 29 + 30 + 29));
    }
    // Elul
    return YearMonthDay.NewYearMonthDay(year, 6, dayOfYear - (30 + 29 + 30 + 30 + 29 + 30 + 29 + 30));
  }

  static GetDaysFromStartOfYearToStartOfMonth(year: number, month: number): number {
    // Work out everything about the year in one go. (Admittedly we don't always need it all... but for
    // anything other than Tishri and Heshvan, we at least need the length of Heshvan...)
    // unchecked
    const cache = HebrewScripturalCalculator.GetOrPopulateCache(year);
    const heshvanLength = (cache & IsHeshvanLongCacheBit) !== 0 ? 30 : 29;
    const kislevLength = (cache & IsKislevShortCacheBit) !== 0 ? 29 : 30;
    const isLeap = HebrewScripturalCalculator.IsLeapYear(year);
    const firstAdarLength = isLeap ? 30 : 29;
    const secondAdarLength = isLeap ? 29 : 0;
    switch (month) {
      // Note: this could be made slightly faster (at least in terms of the apparent IL) by
      // putting all the additions of compile-time constants in one place. Indeed, we could
      // go further by only using isLeap at most once per case. However, this code is clearer
      // and there's no evidence that this is a bottleneck.
      // Nisan
      case 1: return 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength;
      // Iyar
      case 2: return 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + 30;
      // Sivan
      case 3: return 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29);
      // Tamuz
      case 4: return 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29 + 30);
      // Av
      case 5: return 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29 + 30 + 29);
      // Elul
      case 6: return 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29 + 30 + 29 + 30);
      // Tishri
      case 7: return 0;
      // Heshvan
      case 8: return 30;
      // Kislev
      case 9: return 30 + heshvanLength;
      // Tevet
      case 10: return 30 + heshvanLength + kislevLength;
      // Shevat
      case 11: return 30 + heshvanLength + kislevLength + 29;
      // Adar / Adar I
      case 12: return 30 + heshvanLength + kislevLength + 29 + 30;
      // Adar II
      case 13: return 30 + heshvanLength + kislevLength + 29 + 30 + firstAdarLength;
      default: return Preconditions.ThrowArgumentOutOfRangeExceptionWithReturn("month", month, 1, 13);
    }
  }

  static DaysInMonth(year: number, month: number): number {
    switch (month) {
      case 2: case 4: case 6: case 10: case 13: return 29;
      case 8: return HebrewScripturalCalculator.IsHeshvanLong(year) ? 30 : 29;
      case 9: return HebrewScripturalCalculator.IsKislevShort(year) ? 29 : 30;
      case 12: return HebrewScripturalCalculator.IsLeapYear(year) ? 30 : 29;
      default: return 30; // 1, 3, 5, 7, 11
    }
  }

  private static IsHeshvanLong(year: number): boolean {
    const cache = HebrewScripturalCalculator.GetOrPopulateCache(year);
    return (cache & IsHeshvanLongCacheBit) !== 0;
  }

  private static IsKislevShort(year: number): boolean {
    const cache = HebrewScripturalCalculator.GetOrPopulateCache(year);
    return (cache & IsKislevShortCacheBit) !== 0;
  }

  /**
   * Elapsed days since the Hebrew epoch at the start of the given Hebrew year.
   * This is *inclusive* of the first day of the year, so ElapsedDays(1) returns 1.
   */
  static ElapsedDays(year: number): number {
    const cache = HebrewScripturalCalculator.GetOrPopulateCache(year);
    return cache >> ElapsedDaysCacheShift;
  }

  private static ElapsedDaysNoCache(year: number): number {
    const monthsElapsed = (235 * Math.trunc((year - 1) / 19)) // Months in complete cycles so far
      + (12 * ((year - 1) % 19)) // Regular months in this cycle
      + Math.trunc((((year - 1) % 19) * 7 + 1) / 19); // Leap months this cycle
    // Second option in the paper, which keeps values smaller
    const partsElapsed = 204 + (793 * (monthsElapsed % 1080));
    const hoursElapsed = 5 + (12 * monthsElapsed) + (793 * Math.trunc(monthsElapsed / 1080)) + Math.trunc(partsElapsed / 1080);
    const day = 1 + (29 * monthsElapsed) + Math.trunc(hoursElapsed / 24);
    const parts = ((hoursElapsed % 24) * 1080) + (partsElapsed % 1080);
    const postponeRoshHaShanah = (parts >= 19440) ||
      (day % 7 === 2 && parts >= 9924 && !HebrewScripturalCalculator.IsLeapYear(year)) ||
      (day % 7 === 1 && parts >= 16789 && HebrewScripturalCalculator.IsLeapYear(year - 1));
    const alternativeDay = postponeRoshHaShanah ? 1 + day : day;
    const alternativeDayMod7 = alternativeDay % 7;
    return (alternativeDayMod7 === 0 || alternativeDayMod7 === 3 || alternativeDayMod7 === 5)
      ? alternativeDay + 1 : alternativeDay;
  }

  /**
   * Returns the cached "elapsed day at start of year / IsHeshvanLong / IsKislevShort" combination,
   * populating the cache if necessary. Bits 2-24 are the "elapsed days start of year"; bit 0 is
   * "is Heshvan long"; bit 1 is "is Kislev short". If the year is out of the range for the cache,
   * the value is populated but not cached.
   */
  private static GetOrPopulateCache(year: number): number {
    if (year < MinYear || year > MaxYear) {
      return HebrewScripturalCalculator.ComputeCacheEntry(year);
    }
    const cacheIndex = YearStartCacheEntry.GetCacheIndex(year);
    let cacheEntry = HebrewScripturalCalculator.YearCache[cacheIndex]!;
    if (!cacheEntry.IsValidForYear(year)) {
      const days = HebrewScripturalCalculator.ComputeCacheEntry(year);
      cacheEntry = YearStartCacheEntry.NewYearDays(year, days);
      HebrewScripturalCalculator.YearCache[cacheIndex] = cacheEntry;
    }
    return cacheEntry.StartOfYearDays;
  }

  /**
   * Computes the cache entry value for the given year, but without populating the cache.
   */
  private static ComputeCacheEntry(year: number): number {
    const days = HebrewScripturalCalculator.ElapsedDaysNoCache(year);
    // We want the elapsed days for the next year as well. Check the cache if possible.
    const nextYear = year + 1;
    let nextYearDays: number;
    if (nextYear <= MaxYear) {
      const cacheIndex = YearStartCacheEntry.GetCacheIndex(nextYear);
      const cacheEntry = HebrewScripturalCalculator.YearCache[cacheIndex]!;
      nextYearDays = cacheEntry.IsValidForYear(nextYear)
        ? cacheEntry.StartOfYearDays >> ElapsedDaysCacheShift
        : HebrewScripturalCalculator.ElapsedDaysNoCache(nextYear);
    } else {
      nextYearDays = HebrewScripturalCalculator.ElapsedDaysNoCache(year + 1);
    }
    const daysInYear = nextYearDays - days;
    const isHeshvanLong = daysInYear % 10 === 5;
    const isKislevShort = daysInYear % 10 === 3;
    return (days << ElapsedDaysCacheShift)
      | (isHeshvanLong ? IsHeshvanLongCacheBit : 0)
      | (isKislevShort ? IsKislevShortCacheBit : 0);
  }

  static DaysInYear(year: number): number {
    return HebrewScripturalCalculator.ElapsedDays(year + 1) - HebrewScripturalCalculator.ElapsedDays(year);
  }
}
