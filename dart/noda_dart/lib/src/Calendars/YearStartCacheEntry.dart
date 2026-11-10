// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/YearStartCacheEntry.cs
// (No copyright header in the original file.)

import 'package:meta/meta.dart';

/// Type containing as much logic as possible for how the cache of "start of year" data works.
/// As of Noda Time 1.3, this is not specific to YearMonthDayCalculator - it can be used for
/// other frames of reference, so long as they comply with the restrictions listed below.
///
/// Each entry in the cache is a 32-bit number. The "value" part of the entry consists of the
/// number of days since the Unix epoch (negative for a value before the epoch). As Noda Time
/// only supports a number of ticks since the Unix epoch of between long.MinValue and long.MaxValue,
/// we only need to support a number of days in the range
/// [long.MinValue / TicksPerDay, long.MaxValue / TicksPerDay] which is [-10675200, 10675200] (rounding
/// away from 0). This value can be stored in 25 bits.
///
/// The remaining 7 bits of the value are used for validation. For any given year, the bottom
/// 10 bits are used as the index into the cache (which is an array). The next 7 most significant
/// bits are stored in the entry. So long as we have fewer than 17 significant bits in the year value,
/// this will be a unique combination. A single validation value (the most highly positive value) is
/// reserved to indicate an invalid entry. The cache is initialized with all entries invalid.
/// This gives us a range of year numbers greater than [-60000, 60000] without any risk of collisions. By
/// contrast, the ISO calendar years are in the range [-27255, 31195] - so we'd have to be dealing with a
/// calendar with either very short years, or an epoch a long way ahead or behind the Unix epoch.
///
/// The fact that each cache entry is only 32 bits means that we can safely use the cache from multiple
/// threads without locking. 32-bit aligned values are guaranteed to be accessed atomically, so we know we'll
/// never get the value for one year with the validation bits for another, for example.
@internal
final class YearStartCacheEntry {
  static const int _CacheIndexBits = 10;
  static const int _CacheIndexMask = _CacheSize - 1;
  static const int _EntryValidationBits = 7;
  static const int _EntryValidationMask = (1 << _EntryValidationBits) - 1;

  static const int _CacheSize = 1 << _CacheIndexBits;
  // Smallest (positive) year such that the validator is as high as possible.
  // (We shift the mask down by one because the top bit of the validator is effectively the sign bit for the
  // year, and so a validation value with all bits set is already used for e.g. year -1.)
  static const int InvalidEntryYear = (_EntryValidationMask >> 1) << _CacheIndexBits;

  /// Entry which is guaranteed to be obviously invalid for any real date, by having
  /// a validation value which is larger than any valid year number.
  static final YearStartCacheEntry _Invalid = YearStartCacheEntry.NewYearDays(InvalidEntryYear, 0);

  /// Entry value: most significant 25 bits are the number of days (e.g. since the Unix epoch); remaining 7 bits are
  /// the validator.
  final int _value;

  YearStartCacheEntry.NewYearDays(int year, int days)
      // noda_dart: wrapped to 32 bits, as C#'s int shift.
      : _value = ((days << _EntryValidationBits) | _GetValidator(year)).toSigned(32);

  static List<YearStartCacheEntry> CreateCache() {
    List<YearStartCacheEntry> cache = List<YearStartCacheEntry>.filled(_CacheSize, _Invalid);
    for (int i = 0; i < cache.length; i++) {
      cache[i] = YearStartCacheEntry._Invalid;
    }
    return cache;
  }

  /// Returns the validator to use for a given year, a non-negative number containing at most
  /// EntryValidationBits bits.
  static int _GetValidator(int year) =>
      // Note that we assume that the input year fits into EntryValidationBits+CacheIndexBits bits - if not,
      // this would return the same validator for more than one input year, meaning that we could potentially
      // use the wrong cache value.
      // The masking here is necessary to remove some of the sign-extended high bits for negative years.
      (year >> _CacheIndexBits) & _EntryValidationMask;

  /// Returns the cache index, in [0, CacheSize), that should be used to store the given year's cache entry.
  static int GetCacheIndex(int year) =>
      // Effectively keep only the bottom CacheIndexBits bits.
      year & _CacheIndexMask;

  /// Returns whether this cache entry is valid for the given year, and so is safe to use.  (We assume that we
  /// have located this entry via the correct cache index.)
  bool IsValidForYear(int year) => _GetValidator(year) == (_value & _EntryValidationMask);

  /// Returns the (signed) number of days since the Unix epoch for the cache entry.
  // noda_dart: toSigned(32), as dart2js's >> gives an unsigned 32-bit result for a negative value (days before 1970).
  int get StartOfYearDays => (_value >> _EntryValidationBits).toSigned(32);
}
