// Ported from NodaTime 3.3.7: src/NodaTime.Testing/TimeZones/MultiTransitionDateTimeZone.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZone, Offset, ZoneInterval } from "../../internal.ts";
import type { Instant } from "../../internal.ts";
import { NewInvalidOperationException } from "../../internal.ts";

/**
 * Builder to create instances of {@link MultiTransitionDateTimeZone}. Each builder
 * can only be built once.
 * (C#: MultiTransitionDateTimeZone.Builder)
 */
export class MultiTransitionDateTimeZoneBuilder {
  private readonly _intervals: ZoneInterval[] = [];
  private _currentStandardOffset: Offset;
  private _currentSavings: Offset;
  private _currentName: string;
  private _built = false;

  /**
   * Gets the ID of the time zone which will be built.
   */
  Id: string;

  /**
   * Constructs a builder using an ID of "MultiZone", an initial offset of zero (standard and savings),
   * and an initial name of "First".
   */
  constructor();
  /**
   * Constructs a builder using the given first name, standard offset, and a daylight saving
   * offset of 0. The ID is initially "MultiZone".
   * @param firstOffsetHours Standard offset in hours in the first zone interval.
   * @param firstName Name of the first zone interval.
   */
  constructor(firstOffsetHours: number, firstName: string);
  /**
   * Constructs a builder using the given standard offset and saving offset. The ID is initially "MultiZone".
   * @param firstStandardOffsetHours Standard offset in hours in the first zone interval.
   * @param firstSavingOffsetHours Standard offset in hours in the first zone interval.
   */
  constructor(firstStandardOffsetHours: number, firstSavingOffsetHours: number);
  /**
   * Constructs a builder using the given first name, standard offset, and daylight saving offset.
   * The ID is initially "MultiZone".
   * @param firstStandardOffsetHours Standard offset in hours in the first zone interval.
   * @param firstSavingOffsetHours Daylight saving offset in hours in the first zone interval.
   * @param firstName Name of the first zone interval.
   */
  constructor(firstStandardOffsetHours: number, firstSavingOffsetHours: number, firstName: string);
  constructor(firstStandardOffsetHours: number = 0, savingsOrName: number | string = 0, firstName: string = "First") {
    let firstSavingOffsetHours: number;
    if (typeof savingsOrName === "string") {
      firstSavingOffsetHours = 0;
      firstName = savingsOrName;
    } else {
      firstSavingOffsetHours = savingsOrName;
    }
    this.Id = "MultiZone";
    this._currentName = firstName;
    this._currentStandardOffset = Offset.FromHours(firstStandardOffsetHours);
    this._currentSavings = Offset.FromHours(firstSavingOffsetHours);
  }

  /**
   * Adds a transition at the given instant, to the specified new standard offset,
   * with no daylight saving. The name is generated from the transition.
   * @param transition Instant at which the zone changes.
   * @param newStandardOffsetHours The new standard offset, in hours.
   */
  Add(transition: Instant, newStandardOffsetHours: number): void;
  /**
   * Adds a transition at the given instant, to the specified new standard offset,
   * with the new specified daylight saving. The name is generated from the transition.
   * @param transition Instant at which the zone changes.
   * @param newStandardOffsetHours The new standard offset, in hours.
   * @param newSavingOffsetHours The new daylight saving offset, in hours.
   */
  Add(transition: Instant, newStandardOffsetHours: number, newSavingOffsetHours: number): void;
  /**
   * Adds a transition at the given instant, to the specified new standard offset,
   * with the new specified daylight saving. The name is generated from the transition.
   * @param transition Instant at which the zone changes.
   * @param newStandardOffsetHours The new standard offset, in hours.
   * @param newSavingOffsetHours The new daylight saving offset, in hours.
   * @param newName The new zone interval name.
   */
  Add(transition: Instant, newStandardOffsetHours: number, newSavingOffsetHours: number, newName: string): void;
  Add(transition: Instant, newStandardOffsetHours: number, newSavingOffsetHours: number = 0, newName?: string): void {
    newName ??= `Interval from ${transition}`;
    this.EnsureNotBuilt();
    const previousStart = this._intervals.length === 0 ? null : this._intervals[this._intervals.length - 1]!.End;
    // The ZoneInterval constructor will perform validation.
    this._intervals.push(
      new ZoneInterval(this._currentName, previousStart, transition, this._currentStandardOffset.Plus(this._currentSavings), this._currentSavings),
    );
    this._currentName = newName;
    this._currentStandardOffset = Offset.FromHours(newStandardOffsetHours);
    this._currentSavings = Offset.FromHours(newSavingOffsetHours);
  }

  /**
   * Builds a {@link MultiTransitionDateTimeZone} from this builder, invalidating it in the process.
   * @returns The newly-built zone.
   */
  Build(): MultiTransitionDateTimeZone {
    this.EnsureNotBuilt();
    this._built = true;
    const previousStart = this._intervals.length === 0 ? null : this._intervals[this._intervals.length - 1]!.End;
    this._intervals.push(new ZoneInterval(this._currentName, previousStart, null, this._currentStandardOffset.Plus(this._currentSavings), this._currentSavings));
    return MultiTransitionDateTimeZone.NewIdIntervals(this.Id, this._intervals);
  }

  private EnsureNotBuilt(): void {
    if (this._built) {
      throw NewInvalidOperationException("Cannot use a builder after building");
    }
  }

  // Not ported: IEnumerable.GetEnumerator (it only exists to enable C# collection initializers)
}

/**
 * Time zone with multiple transitions, created via a builder.
 */
export class MultiTransitionDateTimeZone extends DateTimeZone {
  /** Nested type: MultiTransitionDateTimeZone.Builder */
  static readonly Builder = MultiTransitionDateTimeZoneBuilder;

  /**
   * Gets the zone intervals within this time zone, in chronological order, spanning the whole time line.
   */
  readonly Intervals: readonly ZoneInterval[];

  /**
   * Gets the transition points between intervals.
   */
  readonly Transitions: readonly Instant[];

  /** @internal */
  static NewIdIntervals(id: string, intervals: readonly ZoneInterval[]): MultiTransitionDateTimeZone {
    return new MultiTransitionDateTimeZone(id, intervals);
  }

  private constructor(id: string, intervals: readonly ZoneInterval[]) {
    super(
      id,
      intervals.length === 1,
      intervals.map((x) => x.WallOffset).reduce((a, b) => Offset.Min(a, b)),
      intervals.map((x) => x.WallOffset).reduce((a, b) => Offset.Max(a, b)),
    );
    this.Intervals = [...intervals];
    this.Transitions = intervals.slice(1).map((x) => x.Start);
  }

  /** @inheritdoc */
  override GetZoneInterval(instant: Instant): ZoneInterval {
    let lower = 0; // Inclusive
    let upper = this.Intervals.length; // Exclusive

    while (lower < upper) {
      const current = (lower + upper) >> 1;
      const candidate = this.Intervals[current]!;
      if (candidate.HasStart && candidate.Start.CompareTo(instant) > 0) {
        upper = current;
      } else if (candidate.HasEnd && candidate.End.CompareTo(instant) <= 0) {
        lower = current + 1;
      } else {
        return candidate;
      }
    }
    // Note: this would indicate a bug. The time zone is meant to cover the whole of time.
    throw NewInvalidOperationException(`Instant ${instant} did not exist in time zone ${this.Id}`);
  }
}
