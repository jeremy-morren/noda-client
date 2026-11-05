// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/ZoneRecurrence.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  GregorianYearMonthDayCalculator,
  Instant,
  Int32,
  InvalidOperationError,
  LocalInstant,
  Preconditions,
  Transition,
  ZoneYearOffset,
} from "../internal.ts";
import type { IDateTimeZoneReader, IEquatable, Offset } from "../internal.ts";

/**
 * Extends {@link ZoneYearOffset} with a name and savings.
 *
 * This represents a recurring transition from or to a daylight savings time. The name is the
 * name of the time zone during this period (e.g. PST or PDT). The savings is usually 0 or the
 * daylight offset. This is also used to support some of the tricky transitions that occurred
 * before the time zones were normalized (i.e. when they were still tightly longitude-based,
 * with multiple towns in the same country observing different times).
 *
 * Immutable, thread safe.
 * @internal
 */
export class ZoneRecurrence implements IEquatable<ZoneRecurrence> {
  private readonly _maxLocalInstant: LocalInstant;
  private readonly _minLocalInstant: LocalInstant;

  readonly Name: string;
  readonly Savings: Offset;
  readonly YearOffset: ZoneYearOffset;
  readonly FromYear: number;
  readonly ToYear: number;
  get IsInfinite(): boolean {
    return this.ToYear === Int32.MaxValue;
  }

  /**
   * Initializes a new instance of the {@link ZoneRecurrence} class.
   * @param name The name of the time zone period e.g. PST.
   * @param savings The savings for this period.
   * @param yearOffset The year offset of when this period starts in a year.
   * @param fromYear The first year in which this recurrence is valid
   * @param toYear The last year in which this recurrence is valid
   */
  constructor(name: string, savings: Offset, yearOffset: ZoneYearOffset, fromYear: number, toYear: number) {
    Preconditions.CheckNotNull(name, "name");
    Preconditions.CheckNotNull(yearOffset, "yearOffset");

    Preconditions.CheckArgument(
      fromYear === Int32.MinValue || (fromYear >= -9998 && fromYear <= 9999),
      "fromYear",
      "fromYear must be in the range [-9998, 9999] or Int32.MinValue",
    );
    Preconditions.CheckArgument(
      toYear === Int32.MaxValue || (toYear >= -9998 && toYear <= 9999),
      "toYear",
      "toYear must be in the range [-9998, 9999] or Int32.MaxValue",
    );
    this.Name = name;
    this.Savings = savings;
    this.YearOffset = yearOffset;
    this.FromYear = fromYear;
    this.ToYear = toYear;
    this._minLocalInstant = fromYear === Int32.MinValue ? LocalInstant.BeforeMinValue : yearOffset.GetOccurrenceForYear(fromYear);
    this._maxLocalInstant = toYear === Int32.MaxValue ? LocalInstant.AfterMaxValue : yearOffset.GetOccurrenceForYear(toYear);
  }

  /**
   * Returns a new recurrence which has the same values as this, but a different name.
   * @internal
   */
  WithName(name: string): ZoneRecurrence {
    return new ZoneRecurrence(name, this.Savings, this.YearOffset, this.FromYear, this.ToYear);
  }

  /**
   * Returns a new recurrence with the same values as this, but just for a single year.
   * @internal
   */
  ForSingleYear(year: number): ZoneRecurrence {
    return new ZoneRecurrence(this.Name, this.Savings, this.YearOffset, year, year);
  }

  // #region IEquatable<ZoneRecurrence> Members
  /**
   * Indicates whether the current object is equal to another object of the same type.
   * (Merges NodaTime's Equals(ZoneRecurrence) and Equals(object).)
   * @param other An object to compare with this object.
   * @returns true if the current object is equal to the `other` parameter;
   * otherwise, false.
   */
  Equals(other: ZoneRecurrence): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    if (!(other instanceof ZoneRecurrence)) {
      return false;
    }
    if (this === other) {
      return true;
    }
    return (
      this.Savings.Equals(other.Savings) &&
      this.FromYear === other.FromYear &&
      this.ToYear === other.ToYear &&
      this.Name === other.Name &&
      this.YearOffset.Equals(other.YearOffset)
    );
  }
  // #endregion

  /**
   * Returns the first transition which occurs strictly after the given instant.
   *
   * If the given instant is before the starting year, the year of the given instant is
   * adjusted to the beginning of the starting year. The first transition after the
   * adjusted instant is determined. If the next adjustment is after the ending year, this
   * method returns null; otherwise the next transition is returned.
   * @param instant The {@link Instant} lower bound for the next transition.
   * @param standardOffset The {@link Offset} standard offset.
   * @param previousSavings The {@link Offset} savings adjustment at the given Instant.
   * @returns The next transition, or null if there is no next transition. The transition may be
   * infinite, i.e. after the end of representable time.
   * @internal
   */
  Next(instant: Instant, standardOffset: Offset, previousSavings: Offset): Transition | null {
    const ruleOffset = this.YearOffset.GetRuleOffset(standardOffset, previousSavings);
    const newOffset = standardOffset.Plus(this.Savings);

    const safeLocal = instant.SafePlus(ruleOffset);
    let targetYear: number;
    if (safeLocal.CompareTo(this._minLocalInstant) < 0) {
      // Asked for a transition after some point before the first transition: crop to first year (so we get the first transition)
      targetYear = this.FromYear;
    } else if (safeLocal.CompareTo(this._maxLocalInstant) >= 0) {
      // Asked for a transition after our final transition... or both are beyond the end of time (in which case
      // we can return an infinite transition). This branch will always be taken for transitions beyond the end
      // of time.
      return this._maxLocalInstant.Equals(LocalInstant.AfterMaxValue) ? new Transition(Instant.AfterMaxValue, newOffset) : null;
    } else if (safeLocal.Equals(LocalInstant.BeforeMinValue)) {
      // We've been asked to find the next transition after some point which is a valid instant, but is before the
      // start of valid local time after applying the rule offset. For example, passing Instant.MinValue for a rule which says
      // "transition uses wall time, which is UTC-5". Proceed as if we'd been asked for something in -9998.
      // I *think* that works...
      targetYear = GregorianYearMonthDayCalculator.MinGregorianYear;
    } else {
      // Simple case: we were asked for a "normal" value in the range of years for which this recurrence is valid.
      [targetYear] = CalendarSystem.Iso.YearMonthDayCalculator.GetYear(safeLocal.DaysSinceEpoch);
    }

    const transition = this.YearOffset.GetOccurrenceForYear(targetYear);

    let safeTransition = transition.SafeMinus(ruleOffset);
    if (safeTransition.CompareTo(instant) > 0) {
      return new Transition(safeTransition, newOffset);
    }

    // We've got a transition earlier than we were asked for. Try next year.
    // Note that this will still be within the FromYear/ToYear range, otherwise
    // safeLocal >= maxLocalInstant would have been triggered earlier.
    targetYear++;
    // Handle infinite transitions
    if (targetYear > GregorianYearMonthDayCalculator.MaxGregorianYear) {
      return new Transition(Instant.AfterMaxValue, newOffset);
    }
    // It's fine for this to be "end of time", and it can't be "start of time" because we're at least finding a transition in -9997.
    safeTransition = this.YearOffset.GetOccurrenceForYear(targetYear).SafeMinus(ruleOffset);
    return new Transition(safeTransition, newOffset);
  }

  /**
   * Returns the last transition which occurs before or on the given instant.
   * @param instant The {@link Instant} lower bound for the next transition.
   * @param standardOffset The {@link Offset} standard offset.
   * @param previousSavings The {@link Offset} savings adjustment at the given Instant.
   * @returns The previous transition, or null if there is no previous transition. The transition may be
   * infinite, i.e. before the start of representable time.
   * @internal
   */
  PreviousOrSame(instant: Instant, standardOffset: Offset, previousSavings: Offset): Transition | null {
    const ruleOffset = this.YearOffset.GetRuleOffset(standardOffset, previousSavings);
    const newOffset = standardOffset.Plus(this.Savings);

    const safeLocal = instant.SafePlus(ruleOffset);
    let targetYear: number;
    if (safeLocal.CompareTo(this._maxLocalInstant) > 0) {
      // Asked for a transition before some point after our last year: crop to last year.
      targetYear = this.ToYear;
    }
    // Deliberately < here; "previous or same" means if safeLocal==minLocalInstant, we should compute it for this year.
    else if (safeLocal.CompareTo(this._minLocalInstant) < 0) {
      // Asked for a transition before our first one
      return null;
    } else if (!safeLocal.IsValid) {
      if (safeLocal.Equals(LocalInstant.BeforeMinValue)) {
        // We've been asked to find the next transition before some point which is a valid instant, but is before the
        // start of valid local time after applying the rule offset.  It's possible that the next transition *would*
        // be representable as an instant (e.g. 1pm Dec 31st -9999 with an offset of -5) but it's reasonable to
        // just return an infinite transition.
        return new Transition(Instant.BeforeMinValue, newOffset);
      } else {
        // We've been asked to find the next transition before some point which is a valid instant, but is after the
        // end of valid local time after applying the rule offset. For example, passing Instant.MaxValue for a rule which says
        // "transition uses wall time, which is UTC+5". Proceed as if we'd been asked for something in 9999.
        // I *think* that works...
        targetYear = GregorianYearMonthDayCalculator.MaxGregorianYear;
      }
    } else {
      // Simple case: we were asked for a "normal" value in the range of years for which this recurrence is valid.
      [targetYear] = CalendarSystem.Iso.YearMonthDayCalculator.GetYear(safeLocal.DaysSinceEpoch);
    }

    const transition = this.YearOffset.GetOccurrenceForYear(targetYear);

    let safeTransition = transition.SafeMinus(ruleOffset);
    if (safeTransition.CompareTo(instant) <= 0) {
      return new Transition(safeTransition, newOffset);
    }

    // We've got a transition later than we were asked for. Try next year.
    // Note that this will still be within the FromYear/ToYear range, otherwise
    // safeLocal < minLocalInstant would have been triggered earlier.
    targetYear--;
    // Handle infinite transitions
    if (targetYear < GregorianYearMonthDayCalculator.MinGregorianYear) {
      return new Transition(Instant.BeforeMinValue, newOffset);
    }
    // It's fine for this to be "start of time", and it can't be "end of time" because we're at latest finding a transition in 9998.
    safeTransition = this.YearOffset.GetOccurrenceForYear(targetYear).SafeMinus(ruleOffset);
    return new Transition(safeTransition, newOffset);
  }

  /**
   * Piggy-backs onto Next, but fails with an InvalidOperationException if there's no such transition.
   * @internal
   */
  NextOrFail(instant: Instant, standardOffset: Offset, previousSavings: Offset): Transition {
    const next = this.Next(instant, standardOffset, previousSavings);
    if (next === null) {
      throw new InvalidOperationError(
        `Noda Time bug or bad data: Expected a transition later than ${instant}; standard offset = ${standardOffset}; previousSavings = ${previousSavings}; recurrence = ${this}`,
      );
    }
    return next;
  }

  /**
   * Piggy-backs onto PreviousOrSame, but fails with a descriptive InvalidOperationException if there's no such transition.
   * @internal
   */
  PreviousOrSameOrFail(instant: Instant, standardOffset: Offset, previousSavings: Offset): Transition {
    const previous = this.PreviousOrSame(instant, standardOffset, previousSavings);
    if (previous === null) {
      throw new InvalidOperationError(
        `Noda Time bug or bad data: Expected a transition earlier than ${instant}; standard offset = ${standardOffset}; previousSavings = ${previousSavings}; recurrence = ${this}`,
      );
    }
    return previous;
  }

  // Not ported: Write(IDateTimeZoneWriter) (DateTimeZoneWriter is not ported)

  /**
   * Reads a recurrence from the specified reader.
   * @param reader The reader.
   * @returns The recurrence read from the reader.
   */
  static Read(reader: IDateTimeZoneReader): ZoneRecurrence {
    Preconditions.CheckNotNull(reader, "reader");
    const name = reader.ReadString();
    const savings = reader.ReadOffset();
    const yearOffset = ZoneYearOffset.Read(reader);
    let fromYear = reader.ReadCount();
    if (fromYear === 0) {
      fromYear = Int32.MinValue;
    }
    const toYear = reader.ReadCount();
    return new ZoneRecurrence(name, savings, yearOffset, fromYear, toYear);
  }

  // #region Object overrides
  // Equals(object) is merged into equals() above.
  // Not ported: GetHashCode (see docs/porting-conventions.md)

  /**
   * Returns a string that represents this instance.
   * @returns A string that represents this instance.
   */
  toString(): string {
    return `${this.Name} ${this.Savings} ${this.YearOffset} [${this.FromYear}-${this.ToYear}]`;
  }

  // #endregion // Object overrides

  /**
   * Returns either "this" (if this zone recurrence already has a from year of int.MinValue)
   * or a new zone recurrence which is identical but with a from year of int.MinValue.
   * @internal
   */
  ToStartOfTime(): ZoneRecurrence {
    return this.FromYear === Int32.MinValue ? this : new ZoneRecurrence(this.Name, this.Savings, this.YearOffset, Int32.MinValue, this.ToYear);
  }
}
