// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/HebrewScripturalCalculator.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/Preconditions.dart';
import '../YearMonthDay.dart';
import 'YearStartCacheEntry.dart';

/// Implementation of the algorithms described in
/// https://www.cs.tau.ac.il/~nachum/calendar-book/papers/calendar.ps, using scriptural
/// month numbering.
@internal
abstract final class HebrewScripturalCalculator {
  static const int MaxYear = 9999;
  static const int MinYear = 1;
  // Use the bottom two bits of the day value to indicate Heshvan/Kislev.
  // Using the top bits causes issues for negative day values (only relevant for
  // invalid years, but still problematic in general).
  static const int _IsHeshvanLongCacheBit = 1 << 0;
  static const int _IsKislevShortCacheBit = 1 << 1;
  // Number of bits to shift the elapsed days in order to get the cache value.
  static const int _ElapsedDaysCacheShift = 2;

  // Cache of when each year starts (in  terms of absolute days). This is the heart of
  // the algorithm, so just caching this is highly effective.
  // Each entry additionally encodes the length of Heshvan and Kislev. We could encode
  // more information too, but those are the tricky bits.
  static final List<YearStartCacheEntry> _YearCache = YearStartCacheEntry.CreateCache();

  static bool IsLeapYear(int year) => ((year * 7) + 1).remainder(19) < 7;

  static YearMonthDay GetYearMonthDay(int year, int dayOfYear) {
    // unchecked
    // Work out everything about the year in one go.
    int cache = _GetOrPopulateCache(year);
    int heshvanLength = (cache & _IsHeshvanLongCacheBit) != 0 ? 30 : 29;
    int kislevLength = (cache & _IsKislevShortCacheBit) != 0 ? 29 : 30;
    bool isLeap = IsLeapYear(year);
    int firstAdarLength = isLeap ? 30 : 29;

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

  static int GetDaysFromStartOfYearToStartOfMonth(int year, int month) {
    // Work out everything about the year in one go. (Admittedly we don't always need it all... but for
    // anything other than Tishri and Heshvan, we at least need the length of Heshvan...)
    // unchecked
    int cache = _GetOrPopulateCache(year);
    int heshvanLength = (cache & _IsHeshvanLongCacheBit) != 0 ? 30 : 29;
    int kislevLength = (cache & _IsKislevShortCacheBit) != 0 ? 29 : 30;
    bool isLeap = IsLeapYear(year);
    int firstAdarLength = isLeap ? 30 : 29;
    int secondAdarLength = isLeap ? 29 : 0;
    return switch (month) {
      // Note: this could be made slightly faster (at least in terms of the apparent IL) by
      // putting all the additions of compile-time constants in one place. Indeed, we could
      // go further by only using isLeap at most once per case. However, this code is clearer
      // and there's no evidence that this is a bottleneck.
      // Nisan
      1 => 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength,
      // Iyar
      2 => 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + 30,
      // Sivan
      3 => 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29),
      // Tamuz
      4 => 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29 + 30),
      // Av
      5 => 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29 + 30 + 29),
      // Elul
      6 => 30 + heshvanLength + kislevLength + (29 + 30) + firstAdarLength + secondAdarLength + (30 + 29 + 30 + 29 + 30),
      // Tishri
      7 => 0,
      // Heshvan
      8 => 30,
      // Kislev
      9 => 30 + heshvanLength,
      // Tevet
      10 => 30 + heshvanLength + kislevLength,
      // Shevat
      11 => 30 + heshvanLength + kislevLength + 29,
      // Adar / Adar I
      12 => 30 + heshvanLength + kislevLength + 29 + 30,
      // Adar II
      13 => 30 + heshvanLength + kislevLength + 29 + 30 + firstAdarLength,
      _ => Preconditions.ThrowArgumentOutOfRangeExceptionWithReturn<int>('month', month, 1, 13)
    };
  }

  static int DaysInMonth(int year, int month) => switch (month) {
        2 || 4 || 6 || 10 || 13 => 29,
        8 => _IsHeshvanLong(year) ? 30 : 29,
        9 => _IsKislevShort(year) ? 29 : 30,
        12 => IsLeapYear(year) ? 30 : 29,
        _ => 30 // 1, 3, 5, 7, 11
      };

  static bool _IsHeshvanLong(int year) {
    int cache = _GetOrPopulateCache(year);
    return (cache & _IsHeshvanLongCacheBit) != 0;
  }

  static bool _IsKislevShort(int year) {
    int cache = _GetOrPopulateCache(year);
    return (cache & _IsKislevShortCacheBit) != 0;
  }

  /// Elapsed days since the Hebrew epoch at the start of the given Hebrew year.
  /// This is *inclusive* of the first day of the year, so ElapsedDays(1) returns 1.
  static int ElapsedDays(int year) {
    int cache = _GetOrPopulateCache(year);
    // noda_dart: toSigned(32), as dart2js's >> is unsigned for negative values (year 0).
    return (cache >> _ElapsedDaysCacheShift).toSigned(32);
  }

  static int _ElapsedDaysNoCache(int year) {
    int monthsElapsed = (235 * ((year - 1) ~/ 19)) + // Months in complete cycles so far
        (12 * ((year - 1).remainder(19))) + // Regular months in this cycle
        ((((year - 1).remainder(19)) * 7 + 1) ~/ 19); // Leap months this cycle
    // Second option in the paper, which keeps values smaller
    int partsElapsed = 204 + (793 * (monthsElapsed.remainder(1080)));
    int hoursElapsed = 5 + (12 * monthsElapsed) + (793 * (monthsElapsed ~/ 1080)) + (partsElapsed ~/ 1080);
    int day = 1 + (29 * monthsElapsed) + (hoursElapsed ~/ 24);
    int parts = ((hoursElapsed.remainder(24)) * 1080) + (partsElapsed.remainder(1080));
    bool postponeRoshHaShanah = (parts >= 19440) ||
        (day.remainder(7) == 2 && parts >= 9924 && !IsLeapYear(year)) ||
        (day.remainder(7) == 1 && parts >= 16789 && IsLeapYear(year - 1));
    int alternativeDay = postponeRoshHaShanah ? 1 + day : day;
    int alternativeDayMod7 = alternativeDay.remainder(7);
    return (alternativeDayMod7 == 0 || alternativeDayMod7 == 3 || alternativeDayMod7 == 5)
        ? alternativeDay + 1
        : alternativeDay;
  }

  /// Returns the cached "elapsed day at start of year / IsHeshvanLong / IsKislevShort" combination,
  /// populating the cache if necessary. Bits 2-24 are the "elapsed days start of year"; bit 0 is
  /// "is Heshvan long"; bit 1 is "is Kislev short". If the year is out of the range for the cache,
  /// the value is populated but not cached.
  ///
  /// [year]:
  static int _GetOrPopulateCache(int year) {
    if (year < MinYear || year > MaxYear) {
      return _ComputeCacheEntry(year);
    }
    int cacheIndex = YearStartCacheEntry.GetCacheIndex(year);
    YearStartCacheEntry cacheEntry = _YearCache[cacheIndex];
    if (!cacheEntry.IsValidForYear(year)) {
      int days = _ComputeCacheEntry(year);
      cacheEntry = YearStartCacheEntry.NewYearDays(year, days);
      _YearCache[cacheIndex] = cacheEntry;
    }
    return cacheEntry.StartOfYearDays;
  }

  /// Computes the cache entry value for the given year, but without populating the cache.
  static int _ComputeCacheEntry(int year) {
    int days = _ElapsedDaysNoCache(year);
    // We want the elapsed days for the next year as well. Check the cache if possible.
    int nextYear = year + 1;
    int nextYearDays;
    if (nextYear <= MaxYear) {
      int cacheIndex = YearStartCacheEntry.GetCacheIndex(nextYear);
      YearStartCacheEntry cacheEntry = _YearCache[cacheIndex];
      nextYearDays = cacheEntry.IsValidForYear(nextYear)
          ? (cacheEntry.StartOfYearDays >> _ElapsedDaysCacheShift).toSigned(32)
          : _ElapsedDaysNoCache(nextYear);
    } else {
      nextYearDays = _ElapsedDaysNoCache(year + 1);
    }
    int daysInYear = nextYearDays - days;
    bool isHeshvanLong = daysInYear.remainder(10) == 5;
    bool isKislevShort = daysInYear.remainder(10) == 3;
    // noda_dart: wrapped to 32 bits, as C#'s int shift.
    return ((days << _ElapsedDaysCacheShift) |
            (isHeshvanLong ? _IsHeshvanLongCacheBit : 0) |
            (isKislevShort ? _IsKislevShortCacheBit : 0))
        .toSigned(32);
  }

  static int DaysInYear(int year) => ElapsedDays(year + 1) - ElapsedDays(year);
}
