// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/ZoneInterval.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Instant, LocalDateTime, Preconditions } from "../internal.ts";
import type { Duration, IEquatable, LocalInstant, Offset } from "../internal.ts";
import type { ArgumentException, InvalidOperationException, OverflowException } from "../internal.ts";

/**
 * Represents a range of time for which a particular Offset applies.
 *
 * Equality is defined component-wise in terms of all properties: the name, the start and end, and the offsets.
 * There is no ordering defined between zone intervals.
 *
 * This type is an immutable reference type. See the thread safety section of the user guide for more information.
 */
export class ZoneInterval implements IEquatable<ZoneInterval> {
  /**
   * Returns the underlying start instant of this zone interval. If the zone interval extends to the
   * beginning of time, the return value will be {@link Instant.BeforeMinValue}; this value
   * should *not* be exposed publicly.
   * @internal
   */
  readonly RawStart: Instant;

  /**
   * Returns the underlying end instant of this zone interval. If the zone interval extends to the
   * end of time, the return value will be {@link Instant.AfterMaxValue}; this value
   * should *not* be exposed publicly.
   * @internal
   */
  readonly RawEnd: Instant;

  private readonly _localStart: LocalInstant;
  private readonly _localEnd: LocalInstant;

  /**
   * Gets the standard offset for this period. This is the offset without any daylight savings
   * contributions.
   *
   * This is effectively `WallOffset - Savings`.
   */
  get StandardOffset(): Offset {
    return this.WallOffset.Minus(this.Savings);
  }

  /**
   * Gets the duration of this zone interval.
   *
   * This is effectively `End - Start`.
   * @throws {InvalidOperationException} This zone extends to the start or end of time.
   */
  get Duration(): Duration {
    return this.End.Minus(this.Start);
  }

  /**
   * Returns `true` if this zone interval has a fixed start point, or `false` if it
   * extends to the beginning of time.
   */
  get HasStart(): boolean {
    return this.RawStart.IsValid;
  }

  /**
   * Gets the last Instant (exclusive) that the Offset applies.
   * @throws {InvalidOperationException} The zone interval extends to the end of time
   */
  get End(): Instant {
    Preconditions.CheckState(this.RawEnd.IsValid, "Zone interval extends to the end of time");
    return this.RawEnd;
  }

  /**
   * Returns `true` if this zone interval has a fixed end point, or `false` if it
   * extends to the end of time.
   */
  get HasEnd(): boolean {
    return this.RawEnd.IsValid;
  }

  // TODO(feature): Consider whether we need some way of checking whether IsoLocalStart/End will throw.
  // Clients can check HasStart/HasEnd for infinity, but what about unrepresentable local values?

  /**
   * Gets the local start time of the interval, as a {@link LocalDateTime}
   * in the ISO calendar.
   * @throws {OverflowException} The interval starts too early to represent as a `LocalDateTime`.
   * @throws {InvalidOperationException} The interval extends to the start of time.
   */
  get IsoLocalStart(): LocalDateTime {
    // Use the Start property to trigger the appropriate end-of-time exception.
    // Call Plus to trigger an appropriate out-of-range exception.
    return LocalDateTime.NewLocalInstant(this.Start.Plus(this.WallOffset));
  }

  /**
   * Gets the local end time of the interval, as a {@link LocalDateTime}
   * in the ISO calendar.
   *
   * As the end time is exclusive, by the time this local time
   * is reached, the next interval will be in effect and the local time will usually
   * have changed (e.g. by adding or subtracting an hour).
   * @throws {OverflowException} The interval ends too late to represent as a `LocalDateTime`.
   * @throws {InvalidOperationException} The interval extends to the end of time.
   */
  get IsoLocalEnd(): LocalDateTime {
    // Use the End property to trigger the appropriate end-of-time exception.
    // Call Plus to trigger an appropriate out-of-range exception.
    return LocalDateTime.NewLocalInstant(this.End.Plus(this.WallOffset));
  }

  private readonly _name: string;

  /**
   * Gets the name of this offset period (e.g. PST or PDT).
   */
  get Name(): string {
    return this._name;
  }

  private readonly _wallOffset: Offset;

  /**
   * Gets the offset from UTC for this period. This includes any daylight savings value.
   */
  get WallOffset(): Offset {
    return this._wallOffset;
  }

  private readonly _savings: Offset;

  /**
   * Gets the daylight savings value for this period.
   */
  get Savings(): Offset {
    return this._savings;
  }

  /**
   * Gets the first Instant that the Offset applies.
   * @throws {InvalidOperationException} The interval extends to the start of time.
   */
  get Start(): Instant {
    Preconditions.CheckState(this.RawStart.IsValid, "Zone interval extends to the beginning of time");
    return this.RawStart;
  }

  /**
   * Initializes a new instance of the {@link ZoneInterval} class.
   *
   * noda-js: also NodaTime's internal constructor with non-nullable instants
   * ({@link ZoneInterval.NewNameStartEndWallOffsetSavings}).
   *
   * @param name The name of this offset period (e.g. PST or PDT).
   * @param start The first {@link Instant} that the `WallOffset` applies,
   * or `null` to make the zone interval extend to the start of time.
   * @param end The last {@link Instant} (exclusive) that the `WallOffset` applies,
   * or `null` to make the zone interval extend to the end of time.
   * @param wallOffset The {@link WallOffset} from UTC for this period including any daylight savings.
   * @param savings The {@link WallOffset} daylight savings contribution to the offset.
   * @throws {ArgumentException} If `start >= end`.
   */
  constructor(name: string, start: Instant | null, end: Instant | null, wallOffset: Offset, savings: Offset) {
    const rawStart = start ?? Instant.BeforeMinValue;
    const rawEnd = end ?? Instant.AfterMaxValue;
    Preconditions.CheckNotNull(name, "name");
    Preconditions.CheckArgument(rawStart.CompareTo(rawEnd) < 0, "start",
      "The start Instant must be less than the end Instant. start: {0}; end: {1}", rawStart, rawEnd);
    this._name = name;
    this.RawStart = rawStart;
    this.RawEnd = rawEnd;
    this._wallOffset = wallOffset;
    this._savings = savings;
    // Work out the corresponding local instants, taking care to "go infinite" appropriately.
    this._localStart = rawStart.SafePlus(wallOffset);
    this._localEnd = rawEnd.SafePlus(wallOffset);
  }

  /**
   * Initializes a new instance of the {@link ZoneInterval} class.
   * (NodaTime's internal constructor.)
   *
   * @param name The name of this offset period (e.g. PST or PDT).
   * @param start The first {@link Instant} that the `WallOffset` applies,
   * or {@link Instant.BeforeMinValue} to make the zone interval extend to the start of time.
   * @param end The last {@link Instant} (exclusive) that the `WallOffset` applies,
   * or {@link Instant.AfterMaxValue} to make the zone interval extend to the end of time.
   * @param wallOffset The {@link WallOffset} from UTC for this period including any daylight savings.
   * @param savings The {@link WallOffset} daylight savings contribution to the offset.
   * @throws {ArgumentException} If `start >= end`.
   * @internal
   */
  static NewNameStartEndWallOffsetSavings(name: string, start: Instant, end: Instant, wallOffset: Offset, savings: Offset): ZoneInterval {
    return new ZoneInterval(name, start, end, wallOffset, savings);
  }

  /**
   * Returns a copy of this zone interval, but with the given start instant.
   * @internal
   */
  WithStart(newStart: Instant): ZoneInterval {
    return new ZoneInterval(this.Name, newStart, this.RawEnd, this.WallOffset, this.Savings);
  }

  /**
   * Returns a copy of this zone interval, but with the given end instant.
   * @internal
   */
  WithEnd(newEnd: Instant): ZoneInterval {
    return new ZoneInterval(this.Name, this.RawStart, newEnd, this.WallOffset, this.Savings);
  }

  // #region Contains
  /**
   * Determines whether this period contains the given Instant in its range.
   *
   * Usually this is half-open, i.e. the end is exclusive, but an interval with an end point of "the end of time"
   * is deemed to be inclusive at the end.
   *
   * @param instant The instant to test.
   * @returns `true` if this period contains the given Instant in its range; otherwise, `false`.
   */
  Contains(instant: Instant): boolean;
  /**
   * Determines whether this period contains the given LocalInstant in its range.
   *
   * @param localInstant The local instant to test.
   * @returns `true` if this period contains the given LocalInstant in its range; otherwise, `false`.
   * @internal
   */
  Contains(localInstant: LocalInstant): boolean;
  Contains(value: Instant | LocalInstant): boolean {
    if (value instanceof Instant) {
      return this.RawStart.CompareTo(value) <= 0 && value.CompareTo(this.RawEnd) < 0;
    }
    return this._localStart.CompareTo(value) <= 0 && value.CompareTo(this._localEnd) < 0;
  }

  /**
   * Returns whether this zone interval has the same offsets and name as another.
   * @internal
   */
  EqualIgnoreBounds(other: ZoneInterval): boolean {
    Preconditions.DebugCheckNotNull(other, "other");
    return other.WallOffset.Equals(this.WallOffset) && other.Savings.Equals(this.Savings) && other.Name === this.Name;
  }

  // #endregion // Contains

  // #region IEquatable<ZoneInterval> Members
  /**
   * Indicates whether the current object is equal to another object of the same type.
   * See the type documentation for a description of equality semantics.
   * (Merges NodaTime's Equals(ZoneInterval), Equals(object) and operator ==.)
   *
   * @param other An object to compare with this object.
   * @returns true if the current object is equal to the `other` parameter; otherwise, false.
   */
  Equals(other: ZoneInterval): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    if (!(other instanceof ZoneInterval)) {
      return false;
    }
    if (this === other) {
      return true;
    }
    return this.Name === other.Name && this.RawStart.Equals(other.RawStart) && this.RawEnd.Equals(other.RawEnd)
      && this.WallOffset.Equals(other.WallOffset) && this.Savings.Equals(other.Savings);
  }
  // #endregion

  // #region object Overrides
  /**
   * Returns a string that represents this instance.
   */
  toString(): string {
    return `${this.Name}: [${this.RawStart}, ${this.RawEnd}) ${this.WallOffset} (${this.Savings})`;
  }

  // #endregion // object Overrides
}
