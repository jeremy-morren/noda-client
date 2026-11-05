// Ported from NodaTime 3.3.0: src/NodaTime/Calendars/YearStartCacheEntry.cs
// (No copyright header in the original file.)

const CacheIndexBits = 10;
const CacheSize = 1 << CacheIndexBits;
const CacheIndexMask = CacheSize - 1;
const EntryValidationBits = 7;
const EntryValidationMask = (1 << EntryValidationBits) - 1;

// Smallest (positive) year such that the validator is as high as possible.
// (We shift the mask down by one because the top bit of the validator is effectively the sign bit for the
// year, and so a validation value with all bits set is already used for e.g. year -1.)
const InvalidEntryYear = (EntryValidationMask >> 1) << CacheIndexBits;

/**
 * Entry which is guaranteed to be obviously invalid for any real date, by having
 * a validation value which is larger than any valid year number.
 */
let invalid: YearStartCacheEntry | undefined;

/**
 * Type containing as much logic as possible for how the cache of "start of year" data works.
 * As of Noda Time 1.3, this is not specific to YearMonthDayCalculator - it can be used for
 * other frames of reference, so long as they comply with the restrictions listed below.
 *
 * Each entry in the cache is a 32-bit number. The "value" part of the entry consists of the
 * number of days since the Unix epoch (negative for a value before the epoch). As Noda Time
 * only supports a number of ticks since the Unix epoch of between long.MinValue and long.MaxValue,
 * we only need to support a number of days in the range
 * [long.MinValue / TicksPerDay, long.MaxValue / TicksPerDay] which is [-10675200, 10675200] (rounding
 * away from 0). This value can be stored in 25 bits.
 *
 * The remaining 7 bits of the value are used for validation. For any given year, the bottom
 * 10 bits are used as the index into the cache (which is an array). The next 7 most significant
 * bits are stored in the entry. So long as we have fewer than 17 significant bits in the year value,
 * this will be a unique combination. A single validation value (the most highly positive value) is
 * reserved to indicate an invalid entry. The cache is initialized with all entries invalid.
 * This gives us a range of year numbers greater than [-60000, 60000] without any risk of collisions. By
 * contrast, the ISO calendar years are in the range [-27255, 31195] - so we'd have to be dealing with a
 * calendar with either very short years, or an epoch a long way ahead or behind the Unix epoch.
 *
 * The fact that each cache entry is only 32 bits means that we can safely use the cache from multiple
 * threads without locking. 32-bit aligned values are guaranteed to be accessed atomically, so we know we'll
 * never get the value for one year with the validation bits for another, for example.
 * @internal
 */
export class YearStartCacheEntry {
  static readonly InvalidEntryYear = InvalidEntryYear;

  /**
   * Entry value: most significant 25 bits are the number of days (e.g. since the Unix epoch); remaining 7 bits are
   * the validator.
   */
  private readonly _value: number;

  private constructor(year: number, days: number) {
    this._value = (days << EntryValidationBits) | YearStartCacheEntry.GetValidator(year);
  }

  /** C#: `internal YearStartCacheEntry(int year, int days)` */
  static NewYearDays(year: number, days: number): YearStartCacheEntry {
    return new YearStartCacheEntry(year, days);
  }

  static CreateCache(): YearStartCacheEntry[] {
    invalid ??= new YearStartCacheEntry(InvalidEntryYear, 0);
    const cache = new Array<YearStartCacheEntry>(CacheSize);
    for (let i = 0; i < cache.length; i++) {
      cache[i] = invalid;
    }
    return cache;
  }

  /**
   * Returns the validator to use for a given year, a non-negative number containing at most
   * EntryValidationBits bits.
   */
  private static GetValidator(year: number): number {
    // Note that we assume that the input year fits into EntryValidationBits+CacheIndexBits bits - if not,
    // this would return the same validator for more than one input year, meaning that we could potentially
    // use the wrong cache value.
    // The masking here is necessary to remove some of the sign-extended high bits for negative years.
    return (year >> CacheIndexBits) & EntryValidationMask;
  }

  /**
   * Returns the cache index, in [0, CacheSize), that should be used to store the given year's cache entry.
   */
  static GetCacheIndex(year: number): number {
    // Effectively keep only the bottom CacheIndexBits bits.
    return year & CacheIndexMask;
  }

  /**
   * Returns whether this cache entry is valid for the given year, and so is safe to use.  (We assume that we
   * have located this entry via the correct cache index.)
   */
  IsValidForYear(year: number): boolean {
    return YearStartCacheEntry.GetValidator(year) === (this._value & EntryValidationMask);
  }

  /**
   * Returns the (signed) number of days since the Unix epoch for the cache entry.
   */
  get StartOfYearDays(): number {
    return this._value >> EntryValidationBits;
  }
}
