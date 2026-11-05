// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/ZoneEqualityComparer.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZone, Instant, Preconditions } from "../internal.ts";
import type { Interval, ZoneInterval } from "../internal.ts";
import { ZoneEqualityComparerOptions } from "./ZoneEqualityComparer.Options.generated.ts";
import { NewArgumentOutOfRangeException, type ArgumentOutOfRangeException } from "../internal.ts";

// Not ported here: the nested Options enum, which is generated as ZoneEqualityComparerOptions
// (src/noda-js/TimeZones/ZoneEqualityComparer.Options.generated.ts) and exposed as ZoneEqualityComparer.Options.

/**
 * Checks whether the given set of options includes the candidate one. This would be an extension method, but
 * that causes problems on Mono at the moment.
 */
function CheckOption(options: ZoneEqualityComparerOptions, candidate: ZoneEqualityComparerOptions): boolean {
  return (options & candidate) !== 0;
}

/** @internal */
export class ZoneEqualityComparerZoneIntervalEqualityComparer {
  private readonly _options: ZoneEqualityComparerOptions;
  private readonly _interval: Interval;

  // noda-js: the C# constructor is internal; the class itself is internal, so the constructor is kept
  // alongside the mechanical factory.
  constructor(options: ZoneEqualityComparerOptions, interval: Interval) {
    this._options = options;
    this._interval = interval;
  }

  static NewOptionsInterval(options: ZoneEqualityComparerOptions, interval: Interval): ZoneEqualityComparerZoneIntervalEqualityComparer {
    return new ZoneEqualityComparerZoneIntervalEqualityComparer(options, interval);
  }

  *CoalesceIntervals(zoneIntervals: Iterable<ZoneInterval>): Generator<ZoneInterval> {
    let current: ZoneInterval | null = null;
    for (const zoneInterval of zoneIntervals) {
      if (current === null) {
        current = zoneInterval;
        continue;
      }
      if (this.EqualExceptStartAndEnd(current, zoneInterval)) {
        current = current.WithEnd(zoneInterval.RawEnd);
      } else {
        yield current;
        current = zoneInterval;
      }
    }
    // current will only be null if start == end...
    if (current !== null) {
      yield current;
    }
  }

  // This is only called with non-null zone intervals - we never expose it.
  Equals(x: ZoneInterval | null, y: ZoneInterval | null): boolean {
    if (!this.EqualExceptStartAndEnd(x!, y!)) {
      return false;
    }
    return this.GetEffectiveStart(x!).Equals(this.GetEffectiveStart(y!)) &&
      this.GetEffectiveEnd(x!).Equals(this.GetEffectiveEnd(y!));
  }

  // Not ported: GetHashCode(ZoneInterval) (hash codes are omitted; see docs/porting-conventions.md)

  private GetEffectiveStart(zoneInterval: ZoneInterval): Instant {
    return CheckOption(this._options, ZoneEqualityComparerOptions.MatchStartAndEndTransitions)
      ? zoneInterval.RawStart : Instant.Max(zoneInterval.RawStart, this._interval.Start);
  }

  private GetEffectiveEnd(zoneInterval: ZoneInterval): Instant {
    return CheckOption(this._options, ZoneEqualityComparerOptions.MatchStartAndEndTransitions)
      ? zoneInterval.RawEnd : Instant.Min(zoneInterval.RawEnd, this._interval.End);
  }

  /**
   * Compares the parts of two zone intervals which are deemed "interesting" by the options.
   * The wall offset is always compared, regardless of options, but the start/end points are
   * never compared.
   */
  private EqualExceptStartAndEnd(x: ZoneInterval, y: ZoneInterval): boolean {
    if (!x.WallOffset.Equals(y.WallOffset)) {
      return false;
    }
    // As we've already compared wall offsets, we only need to compare savings...
    // If the savings are equal, the standard offset will be too.
    if (CheckOption(this._options, ZoneEqualityComparerOptions.MatchOffsetComponents) && !x.Savings.Equals(y.Savings)) {
      return false;
    }
    if (CheckOption(this._options, ZoneEqualityComparerOptions.MatchNames) && x.Name !== y.Name) {
      return false;
    }
    return true;
  }
}

/**
 * Equality comparer for time zones, comparing specific aspects of the zone intervals within
 * a time zone for a specific interval of the time line.
 *
 * The default behaviour of this comparator is to consider two time zones to be equal if they share the same wall
 * offsets at all points within a given time interval, regardless of other aspects of each
 * {@link ZoneInterval} within the two time zones. This behaviour can be changed using the
 * {@link WithOptions} method.
 */
export class ZoneEqualityComparer {
  /**
   * Options to use when comparing time zones for equality. Each option makes the comparison more restrictive.
   * See {@link ZoneEqualityComparerOptions}.
   */
  static readonly Options = ZoneEqualityComparerOptions;

  /** @internal */
  static readonly ZoneIntervalEqualityComparer = ZoneEqualityComparerZoneIntervalEqualityComparer;

  private readonly _interval: Interval;
  private readonly _options: ZoneEqualityComparerOptions;

  /**
   * Returns the interval over which this comparer operates.
   * @internal
   */
  get IntervalForTest(): Interval {
    return this._interval;
  }

  /**
   * Returns the options used by this comparer.
   * @internal
   */
  get OptionsForTest(): ZoneEqualityComparerOptions {
    return this._options;
  }

  private readonly _zoneIntervalComparer: ZoneEqualityComparerZoneIntervalEqualityComparer;

  /**
   * Creates a new comparer for the given interval, with the given comparison options.
   *
   * @param interval The interval within the time line to use for comparisons.
   * @param options The options to use when comparing time zones.
   * @throws {ArgumentOutOfRangeException} The specified options are invalid.
   */
  private constructor(interval: Interval, options: ZoneEqualityComparerOptions) {
    this._interval = interval;
    this._options = options;
    if ((options & ~ZoneEqualityComparerOptions.StrictestMatch) !== 0) {
      throw NewArgumentOutOfRangeException("options", undefined, `The value ${options} is not defined within ZoneEqualityComparer.Options`);
    }
    this._zoneIntervalComparer = new ZoneEqualityComparerZoneIntervalEqualityComparer(options, interval);
  }

  /**
   * Returns a {@link ZoneEqualityComparer} for the given interval with the default options.
   *
   * The default behaviour of this comparator is to consider two time zones to be equal if they share the same wall
   * offsets at all points within a given interval.
   * To specify non-default options, call the {@link WithOptions} method on the result
   * of this method.
   *
   * @param interval The interval over which to compare time zones. This must have both a start and an end.
   * @returns A ZoneEqualityComparer for the given interval with the default options.
   */
  static ForInterval(interval: Interval): ZoneEqualityComparer {
    Preconditions.CheckArgument(interval.HasStart && interval.HasEnd, "interval",
      "The interval must have both a start and an end.");
    return new ZoneEqualityComparer(interval, ZoneEqualityComparerOptions.OnlyMatchWallOffset);
  }

  /**
   * Returns a comparer operating over the same interval as this one, but with the given
   * set of options.
   *
   * This method does not modify the comparer on which it's called.
   *
   * @param options New set of options, which must consist of flags defined within the {@link ZoneEqualityComparerOptions} enum.
   * @throws {ArgumentOutOfRangeException} The specified options are invalid.
   * @returns A comparer operating over the same interval as this one, but with the given set of options.
   */
  WithOptions(options: ZoneEqualityComparerOptions): ZoneEqualityComparer {
    return this._options === options ? this : new ZoneEqualityComparer(this._interval, options);
  }

  /**
   * Compares two time zones for equality according to the options and interval provided to this comparer.
   *
   * @param x The first {@link DateTimeZone} to compare.
   * @param y The second {@link DateTimeZone} to compare.
   * @returns `true` if the specified time zones are equal under the options and interval of this comparer; otherwise, `false`.
   */
  Equals(x: DateTimeZone | null, y: DateTimeZone | null): boolean {
    if (x === y) {
      return true;
    }
    // noda-js: also false (rather than a TypeError) for anything that isn't a DateTimeZone.
    if (!(x instanceof DateTimeZone) || !(y instanceof DateTimeZone)) {
      return false;
    }
    // If we ever need to port this to a platform which doesn't support LINQ,
    // we'll need to reimplement this. Until then, it would seem pointless...
    // noda-js: the equivalent of Enumerable.SequenceEqual with zoneIntervalComparer.
    const xs = this.GetIntervals(x)[Symbol.iterator]();
    const ys = this.GetIntervals(y)[Symbol.iterator]();
    while (true) {
      const xNext = xs.next();
      const yNext = ys.next();
      if (xNext.done || yNext.done) {
        return (xNext.done ?? false) && (yNext.done ?? false);
      }
      if (!this._zoneIntervalComparer.Equals(xNext.value, yNext.value)) {
        return false;
      }
    }
  }

  // Not ported: GetHashCode(DateTimeZone) (hash codes are omitted; see docs/porting-conventions.md)

  private GetIntervals(zone: DateTimeZone): Iterable<ZoneInterval> {
    const allIntervals = zone.GetZoneIntervals(this._interval.Start, this._interval.End);
    return CheckOption(this._options, ZoneEqualityComparerOptions.MatchAllTransitions) ? allIntervals : this._zoneIntervalComparer.CoalesceIntervals(allIntervals);
  }
}
