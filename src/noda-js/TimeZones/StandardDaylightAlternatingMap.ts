// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/StandardDaylightAlternatingMap.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Int32, Offset, Preconditions, ZoneInterval, ZoneRecurrence, ZoneYearOffset } from "../internal.ts";
import type { IDateTimeZoneReader, IDateTimeZoneWriter, IEquatable, IZoneIntervalMap, Instant, Transition } from "../internal.ts";
import { NewInvalidOperationException, type ArgumentOutOfRangeException } from "../internal.ts";

// Reader notes, 2017-04-05:
// - It's not clear that this really needs to be standard/daylight - it could just be two arbitrary recurrences
//   with the same standard offset. Knowing which one is standard avoids one memory access (for the offset) in
//   many occurrences, but we could potentially optimize this in other ways anyway.
//
// - The comment around America/Resolute was added on July 20th 2011. The TZDB release at the time was 2011h.
//   From https://github.com/eggert/tz/blob/338ff27740c38fcef26920c9dbd776c09768eb3b/northamerica
//     Rule    Resolute 2006	max	-	Nov	Sun>=1	2:00	0	ES
//     Rule    Resolute 2007	max	-	Mar Sun>=8	2:00	0	CD
//   We probably still want to be able to consume 2011h later, so let's not remove that functionality.

/**
 * Provides a zone interval map representing an infinite sequence of standard/daylight
 * transitions from a pair of rules.
 *
 * IMPORTANT: This class *accepts* recurrences which start from a particular year
 * rather than being infinite back to the start of time, but *treats* them as if
 * they were infinite. This makes various calculations easier, but this map should
 * only be used as part of a zone which will only ask it for values within the right
 * portion of the timeline.
 * @internal
 */
export class StandardDaylightAlternatingMap implements IEquatable<StandardDaylightAlternatingMap>, IZoneIntervalMap {
  private readonly _standardOffset: Offset;
  private readonly _standardRecurrence: ZoneRecurrence;
  private readonly _dstRecurrence: ZoneRecurrence;

  get MinOffset(): Offset {
    return Offset.Min(this._standardOffset, this._standardOffset.Plus(this._dstRecurrence.Savings));
  }
  get MaxOffset(): Offset {
    return Offset.Max(this._standardOffset, this._standardOffset.Plus(this._dstRecurrence.Savings));
  }

  /**
   * Initializes a new instance of the {@link StandardDaylightAlternatingMap} class.
   *
   * At least one of the recurrences (it doesn't matter which) must be a "standard", i.e. not have any savings
   * applied. The other may still not have any savings (e.g. for America/Resolute) or (for BCL compatibility) may
   * even have negative daylight savings.
   * @param standardOffset The standard offset.
   * @param startRecurrence The start recurrence.
   * @param endRecurrence The end recurrence.
   */
  static NewStandardOffsetStartRecurrenceEndRecurrence(
    standardOffset: Offset,
    startRecurrence: ZoneRecurrence,
    endRecurrence: ZoneRecurrence,
  ): StandardDaylightAlternatingMap {
    return new StandardDaylightAlternatingMap(standardOffset, startRecurrence, endRecurrence);
  }

  private constructor(standardOffset: Offset, startRecurrence: ZoneRecurrence, endRecurrence: ZoneRecurrence) {
    this._standardOffset = standardOffset;
    // Treat the recurrences as if they extended to the start of time.
    startRecurrence = startRecurrence.ToStartOfTime();
    endRecurrence = endRecurrence.ToStartOfTime();
    Preconditions.CheckArgument(startRecurrence.IsInfinite, "startRecurrence", "Start recurrence must extend to the end of time");
    Preconditions.CheckArgument(endRecurrence.IsInfinite, "endRecurrence", "End recurrence must extend to the end of time");
    let dst = startRecurrence;
    let standard = endRecurrence;
    if (startRecurrence.Savings.Equals(Offset.Zero)) {
      dst = endRecurrence;
      standard = startRecurrence;
    }
    Preconditions.CheckArgument(standard.Savings.Equals(Offset.Zero), "startRecurrence", "At least one recurrence must not have savings applied");
    this._dstRecurrence = dst;
    this._standardRecurrence = standard;
  }

  /** (Merges NodaTime's Equals(object) and Equals(StandardDaylightAlternatingMap).) */
  Equals(other: StandardDaylightAlternatingMap): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return (
      other instanceof StandardDaylightAlternatingMap &&
      this._standardOffset.Equals(other._standardOffset) &&
      this._dstRecurrence.Equals(other._dstRecurrence) &&
      this._standardRecurrence.Equals(other._standardRecurrence)
    );
  }

  // Not ported: GetHashCode (see docs/porting-conventions.md)

  /**
   * Gets the zone interval for the given instant.
   * @param instant The Instant to test.
   * @returns The ZoneInterval in effect at the given instant.
   * @throws {ArgumentOutOfRangeException} The instant falls outside the bounds
   * of the recurrence rules of the zone.
   */
  GetZoneInterval(instant: Instant): ZoneInterval {
    const [next, recurrence] = this.NextTransition(instant);
    // Now we know the recurrence we're in, we can work out when we went into it. (We'll never have
    // two transitions into the same recurrence in a row.)
    const previousSavings = recurrence === this._standardRecurrence ? this._dstRecurrence.Savings : Offset.Zero;
    const previous = recurrence.PreviousOrSameOrFail(instant, this._standardOffset, previousSavings);
    return ZoneInterval.NewNameStartEndWallOffsetSavings(
      recurrence.Name,
      previous.Instant,
      next.Instant,
      this._standardOffset.Plus(recurrence.Savings),
      recurrence.Savings,
    );
  }

  /**
   * Returns the transition occurring strictly after the specified instant. The `recurrence`
   * part of the result will be populated with the recurrence the transition goes *from*.
   * (In C# `recurrence` is an out parameter.)
   * @param instant The instant after which to consider transitions.
   * @returns The transition, and the recurrence it goes from.
   */
  private NextTransition(instant: Instant): [transition: Transition, recurrence: ZoneRecurrence] {
    // Both recurrences are infinite, so they'll both have next transitions (possibly at infinity).
    const dstTransition = this._dstRecurrence.NextOrFail(instant, this._standardOffset, Offset.Zero);
    const standardTransition = this._standardRecurrence.NextOrFail(instant, this._standardOffset, this._dstRecurrence.Savings);
    const standardTransitionInstant = standardTransition.Instant;
    const dstTransitionInstant = dstTransition.Instant;
    if (standardTransitionInstant.CompareTo(dstTransitionInstant) < 0) {
      // Next transition is from DST to standard.
      return [standardTransition, this._dstRecurrence];
    } else if (standardTransitionInstant.CompareTo(dstTransitionInstant) > 0) {
      // Next transition is from standard to DST.
      return [dstTransition, this._standardRecurrence];
    } else {
      // Okay, the transitions happen at the same time. If they're not at infinity, we're stumped.
      if (standardTransitionInstant.IsValid) {
        throw NewInvalidOperationException(
          `Zone recurrence rules have identical transitions. This time zone is broken. Transition time: ${standardTransitionInstant}`,
        );
      }
      // Okay, the two transitions must be to the end of time. Find which recurrence has the later *previous* transition...
      const previousDstTransition = this._dstRecurrence.PreviousOrSameOrFail(instant, this._standardOffset, Offset.Zero);
      const previousStandardTransition = this._standardRecurrence.PreviousOrSameOrFail(instant, this._standardOffset, this._dstRecurrence.Savings);
      // No point in checking for equality here... they can't go back from the end of time to the start...
      if (previousDstTransition.Instant.CompareTo(previousStandardTransition.Instant) > 0) {
        // The previous transition is from standard to DST. Therefore the next one is from DST to standard.
        return [standardTransition, this._dstRecurrence];
      } else {
        // The previous transition is from DST to standard. Therefore the next one is from standard to DST.
        return [dstTransition, this._standardRecurrence];
      }
    }
  }

  /**
   * Writes the time zone to the specified writer.
   * @param writer The writer to write to.
   * @internal
   */
  Write(writer: IDateTimeZoneWriter): void {
    // We don't need everything a recurrence can supply: we know that both recurrences should be
    // infinite, and that only the DST recurrence should have savings.
    Preconditions.CheckNotNull(writer, "writer");
    writer.WriteOffset(this._standardOffset);
    writer.WriteString(this._standardRecurrence.Name);
    this._standardRecurrence.YearOffset.Write(writer);
    writer.WriteString(this._dstRecurrence.Name);
    this._dstRecurrence.YearOffset.Write(writer);
    writer.WriteOffset(this._dstRecurrence.Savings);
  }

  /** @internal */
  static Read(reader: IDateTimeZoneReader): StandardDaylightAlternatingMap {
    Preconditions.CheckNotNull(reader, "reader");
    const standardOffset = reader.ReadOffset();
    const standardName = reader.ReadString();
    const standardYearOffset = ZoneYearOffset.Read(reader);
    const daylightName = reader.ReadString();
    const daylightYearOffset = ZoneYearOffset.Read(reader);
    const savings = reader.ReadOffset();
    const standardRecurrence = new ZoneRecurrence(standardName, Offset.Zero, standardYearOffset, Int32.MinValue, Int32.MaxValue);
    const dstRecurrence = new ZoneRecurrence(daylightName, savings, daylightYearOffset, Int32.MinValue, Int32.MaxValue);
    return new StandardDaylightAlternatingMap(standardOffset, standardRecurrence, dstRecurrence);
  }
}
