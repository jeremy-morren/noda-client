// Ported from NodaTime 3.3.7: src/NodaTime/Interval.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Duration,
  Instant,
  InstantPattern,
  Preconditions,
  ThrowValueOf,
} from "./internal.ts";
import type { IEquatable } from "./internal.ts";
import type { NodaConstants } from "./internal.ts";
import { NewArgumentException, NewArgumentOutOfRangeException, type ArgumentException, type ArgumentOutOfRangeException, type InvalidOperationException } from "./internal.ts";

/**
 * An interval between two instants in time (start and end).
 *
 * Equality is defined in a component-wise fashion: two intervals are considered equal if their start instants are
 * equal to each other and their end instants are equal to each other. Ordering between intervals is not defined.
 *
 * The interval includes the start instant and excludes the end instant. However, an interval
 * may be missing its start or end, in which case the interval is deemed to be infinite in that
 * direction.
 *
 * The end may equal the start (resulting in an empty interval), but will not be before the start.
 *
 * The default value of this type is an empty interval with a start and end of
 * {@link NodaConstants.UnixEpoch}.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 */
export class Interval implements IEquatable<Interval> {
  /** The start of the interval. */
  // noda-js: NodaTime's "start" field; renamed as it would clash with the Start property.
  private readonly _start: Instant;

  /** The end of the interval. This will never be earlier than the start. */
  // noda-js: NodaTime's "end" field; renamed as it would clash with the End property.
  private readonly _end: Instant;

  /**
   * Initializes a new instance of the {@link Interval} struct.
   * The interval includes the `start` instant and excludes the
   * `end` instant. The end may equal the start (resulting in an empty interval), but must not be before the start.
   *
   * If the start is null, the interval is deemed to stretch to the start of time. If the end is null,
   * the interval is deemed to stretch to the end of time.
   *
   * noda-js: one constructor covers NodaTime's `Interval(Instant, Instant)` and `Interval(Instant?, Instant?)`.
   * @throws {ArgumentOutOfRangeException} `end` is earlier than `start`, if they are both non-null.
   * @param start The start {@link Instant} or null.
   * @param end The end {@link Instant} or null.
   */
  constructor(start: Instant | null, end: Instant | null) {
    this._start = start ?? Instant.BeforeMinValue;
    this._end = end ?? Instant.AfterMaxValue;
    if (start !== null && end !== null && end.CompareTo(start) < 0) {
      throw NewArgumentOutOfRangeException("end", undefined, "The end parameter must be equal to or later than the start parameter");
    }
  }

  /**
   * Gets the start instant - the inclusive lower bound of the interval.
   *
   * This will never be later than {@link End}, though it may be equal to it.
   * @throws {InvalidOperationException} The interval extends to the start of time.
   * @see {@link HasStart}
   */
  get Start(): Instant {
    Preconditions.CheckState(this._start.IsValid, "Interval extends to start of time");
    return this._start;
  }

  /**
   * Returns `true` if this interval has a fixed start point, or `false` if it
   * extends to the start of time.
   */
  get HasStart(): boolean {
    return this._start.IsValid;
  }

  /**
   * Gets the end instant - the exclusive upper bound of the interval.
   * @throws {InvalidOperationException} The interval extends to the end of time.
   * @see {@link HasEnd}
   */
  get End(): Instant {
    Preconditions.CheckState(this._end.IsValid, "Interval extends to end of time");
    return this._end;
  }

  /**
   * Returns the raw end value of the interval: a normal instant or {@link Instant.AfterMaxValue}.
   * This value should never be exposed.
   * @internal
   */
  get RawEnd(): Instant {
    return this._end;
  }

  /**
   * Returns `true` if this interval has a fixed end point, or `false` if it
   * extends to the end of time.
   */
  get HasEnd(): boolean {
    return this._end.IsValid;
  }

  /**
   * Returns the duration of the interval.
   *
   * This will always be a non-negative duration, though it may be zero.
   * @throws {InvalidOperationException} The interval extends to the start or end of time.
   */
  get Duration(): Duration {
    return Instant.Subtract(this.End, this.Start);
  }

  /**
   * Returns whether or not this interval contains the given instant.
   * @param instant Instant to test.
   * @returns True if this interval contains the given instant; false otherwise.
   */
  Contains(instant: Instant): boolean {
    return instant.CompareTo(this._start) >= 0 && instant.CompareTo(this._end) < 0;
  }

  // Not ported: Deconstruct

  // #region Implementation of IEquatable<Interval>
  /**
   * Indicates whether the value of this interval is equal to the value of the specified interval.
   * See the type documentation for a description of equality semantics.
   * @param other The value to compare with this instance.
   * @returns true if `other` is an interval equal to this one; otherwise, false.
   *
   * noda-js: covers both `IEquatable<Interval>.Equals(Interval)` and `object.Equals(object)`.
   */
  Equals(other: Interval): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof Interval && this._start.Equals(other._start) && this._end.Equals(other._end);
  }
  // #endregion

  // #region object overrides
  // Not ported: GetHashCode

  /**
   * Returns a string representation of this interval, in extended ISO-8601 format: the format
   * is "start/end" where each instant uses a format of "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'".
   * If the start or end is infinite, the relevant part uses "StartOfTime" or "EndOfTime" to
   * represent this.
   * @returns A string representation of this interval.
   */
  toString(): string {
    const pattern = InstantPattern.ExtendedIso;
    return `${pattern.Format(this._start)}/${pattern.Format(this._end)}`;
  }
  // #endregion

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda-js)
  /**
   * Returns the JSON representation used by NodaTime.Serialization.SystemTextJson: an object with `start` and `end`
   * properties formatted with {@link InstantPattern.ExtendedIso}, each omitted when the interval is unbounded in that
   * direction. (noda-js writes camelCase property names, as ASP.NET Core's web defaults do.)
   */
  toJSON(): { start?: string; end?: string } {
    const pattern = InstantPattern.ExtendedIso;
    const result: { start?: string; end?: string } = {};
    if (this.HasStart) {
      result.start = pattern.Format(this._start);
    }
    if (this.HasEnd) {
      result.end = pattern.Format(this._end);
    }
    return result;
  }

  /**
   * Parses a value written by {@link toJSON}. Property names are matched case-insensitively, so both
   * `{ "start": ..., "end": ... }` and `{ "Start": ..., "End": ... }` are accepted; a missing property
   * means the interval is unbounded in that direction.
   * @throws {UnparsableValueException} An instant could not be parsed.
   * @throws {ArgumentException} `json` is not an object.
   */
  static fromJSON(json: unknown): Interval {
    if (json === null || typeof json !== "object") {
      throw NewArgumentException("Expected an object with optional start and end properties", "json");
    }
    const pattern = InstantPattern.ExtendedIso;
    let start: Instant | null = null;
    let end: Instant | null = null;
    for (const key of Object.keys(json)) {
      const value: unknown = (json as Record<string, unknown>)[key];
      const lowerKey = key.toLowerCase();
      if (lowerKey === "start") {
        start = pattern.Parse(value as string).Value;
      } else if (lowerKey === "end") {
        end = pattern.Parse(value as string).Value;
      }
    }
    return new Interval(start, end);
  }
  // #endregion

  /** Throws a TypeError: use {@link Equals} instead of relational operators. */
  valueOf(): never {
    return ThrowValueOf("Interval");
  }
}
