// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/PrecalculatedDateTimeZone.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZone, Instant, InvalidOperationError, Offset, Preconditions, StandardDaylightAlternatingMap, ZoneInterval } from "../internal.ts";
import type { IDateTimeZoneReader, IZoneIntervalMap } from "../internal.ts";

/**
 * Most time zones have a relatively small set of transitions at their start until they finally
 * settle down to either a fixed time zone or a daylight savings time zone. This provides the
 * container for the initial zone intervals and a pointer to the time zone that handles all of
 * the rest until the end of time.
 * @internal
 */
export class PrecalculatedDateTimeZone extends DateTimeZone {
  private readonly _periods: readonly ZoneInterval[];
  private readonly _tailZone: IZoneIntervalMap | null;
  /**
   * The first instant covered by the tail zone, or Instant.AfterMaxValue if there's no tail zone.
   */
  private readonly _tailZoneStart: Instant;
  private readonly _firstTailZoneInterval: ZoneInterval | null = null;

  /**
   * Initializes a new instance of the {@link PrecalculatedDateTimeZone} class.
   * @param id The id.
   * @param intervals The intervals before the tail zone.
   * @param tailZone The tail zone - which can be any IZoneIntervalMap for normal operation,
   * but must be a StandardDaylightAlternatingMap if the result is to be serialized.
   */
  static NewIdIntervalsTailZone(id: string, intervals: readonly ZoneInterval[], tailZone: IZoneIntervalMap | null): PrecalculatedDateTimeZone {
    return new PrecalculatedDateTimeZone(id, intervals, tailZone);
  }

  private constructor(id: string, intervals: readonly ZoneInterval[], tailZone: IZoneIntervalMap | null) {
    super(
      id,
      false,
      PrecalculatedDateTimeZone.ComputeOffset(intervals, tailZone, (x, y) => Offset.Min(x, y)),
      PrecalculatedDateTimeZone.ComputeOffset(intervals, tailZone, (x, y) => Offset.Max(x, y)),
    );
    this._periods = intervals;
    this._tailZone = tailZone;
    this._tailZoneStart = intervals[intervals.length - 1]!.RawEnd; // We want this to be AfterMaxValue for tail-less zones.
    if (tailZone !== null) {
      // Cache a "clamped" zone interval for use at the start of the tail zone.
      this._firstTailZoneInterval = tailZone.GetZoneInterval(this._tailZoneStart).WithStart(this._tailZoneStart);
    }
    PrecalculatedDateTimeZone.ValidatePeriods(intervals, tailZone);
  }

  /**
   * Validates that all the periods before the tail zone make sense. We have to start at the beginning of time,
   * and then have adjoining periods. This is only called in the constructors.
   *
   * This is only called from the constructors, but is internal to make it easier to test.
   * @throws {ArgumentError} The periods specified are invalid.
   * @internal
   */
  static ValidatePeriods(periods: readonly ZoneInterval[], tailZone: IZoneIntervalMap | null): void {
    Preconditions.CheckArgument(periods.length > 0, "periods", "No periods specified in precalculated time zone");
    Preconditions.CheckArgument(!periods[0]!.HasStart, "periods", "Periods in precalculated time zone must start with the beginning of time");
    for (let i = 0; i < periods.length - 1; i++) {
      // Safe to use End here: there can't be a period *after* an endless one. Likewise it's safe to use Start on the next
      // period, as there can't be a period *before* one which goes back to the start of time.
      Preconditions.CheckArgument(periods[i]!.End.Equals(periods[i + 1]!.Start), "periods", "Non-adjoining ZoneIntervals for precalculated time zone");
    }
    Preconditions.CheckArgument(
      tailZone !== null || periods[periods.length - 1]!.RawEnd.Equals(Instant.AfterMaxValue),
      "tailZone",
      "Null tail zone given but periods don't cover all of time",
    );
  }

  /**
   * Gets the zone offset period for the given instant.
   * @param instant The Instant to find.
   * @returns The ZoneInterval including the given instant.
   */
  override GetZoneInterval(instant: Instant): ZoneInterval {
    if (this._tailZone !== null && instant.CompareTo(this._tailZoneStart) >= 0) {
      // Clamp the tail zone interval to start at the end of our final period, if necessary, so that the
      // join is seamless.
      const intervalFromTailZone = this._tailZone.GetZoneInterval(instant);
      return intervalFromTailZone.RawStart.CompareTo(this._tailZoneStart) < 0 ? this._firstTailZoneInterval! : intervalFromTailZone;
    }

    let lower = 0; // Inclusive
    let upper = this._periods.length; // Exclusive

    while (lower < upper) {
      const current = (lower + upper) >> 1;
      const candidate = this._periods[current]!;
      if (candidate.RawStart.CompareTo(instant) > 0) {
        upper = current;
      }
      // Safe to use RawEnd, as it's just for the comparison.
      else if (candidate.RawEnd.CompareTo(instant) <= 0) {
        lower = current + 1;
      } else {
        return candidate;
      }
    }
    // Note: this would indicate a bug. The time zone is meant to cover the whole of time.
    throw new InvalidOperationError(`Instant ${instant} did not exist in time zone ${this.Id}`);
  }

  // #region I/O
  // Not ported: Write(IDateTimeZoneWriter) (DateTimeZoneWriter is not ported; used in TzdbCompiler)

  /**
   * Reads a time zone from the specified reader.
   * @param reader The reader.
   * @param id The id.
   * @returns The time zone.
   * @internal
   */
  static Read(reader: IDateTimeZoneReader, id: string): DateTimeZone {
    Preconditions.DebugCheckNotNull(reader, "reader");
    Preconditions.DebugCheckNotNull(id, "id");
    const size = reader.ReadCount();
    const periods = new Array<ZoneInterval>(size);
    // It's not entirely clear why we don't just assume that the first zone interval always starts at Instant.BeforeMinValue
    // (given that we check that later) but we don't... and changing that now could cause compatibility issues.
    let start = reader.ReadZoneIntervalTransition(null);
    for (let i = 0; i < size; i++) {
      const name = reader.ReadString();
      const offset = reader.ReadOffset();
      const savings = reader.ReadOffset();
      const nextStart = reader.ReadZoneIntervalTransition(start);
      periods[i] = ZoneInterval.NewNameStartEndWallOffsetSavings(name, start, nextStart, offset, savings);
      start = nextStart;
    }
    const tailZone = reader.ReadByte() === 1 ? StandardDaylightAlternatingMap.Read(reader) : null;
    return new PrecalculatedDateTimeZone(id, periods, tailZone);
  }
  // #endregion // I/O

  // #region Offset computation for constructors
  // Essentially Func<Offset, Offset, Offset>
  // (C#'s OffsetAggregator and OffsetExtractor delegates become function types.)

  // Reasonably simple way of computing the maximum/minimum offset
  // from either periods or transitions, with or without a tail zone.
  private static ComputeOffset(
    intervals: readonly ZoneInterval[],
    tailZone: IZoneIntervalMap | null,
    aggregator: (x: Offset, y: Offset) => Offset,
  ): Offset {
    Preconditions.CheckNotNull(intervals, "intervals");
    Preconditions.CheckArgument(intervals.length > 0, "intervals", "No intervals specified");
    let ret = intervals[0]!.WallOffset;
    for (let i = 1; i < intervals.length; i++) {
      ret = aggregator(ret, intervals[i]!.WallOffset);
    }
    if (tailZone !== null) {
      // Effectively a shortcut for picking either tailZone.MinOffset or
      // tailZone.MaxOffset
      const bestFromZone = aggregator(tailZone.MinOffset, tailZone.MaxOffset);
      ret = aggregator(ret, bestFromZone);
    }
    return ret;
  }
  // #endregion
}
