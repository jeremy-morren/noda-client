// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/ZoneTransition.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions, ZoneInterval } from "../../internal.ts";
import type { Instant, Offset } from "../../internal.ts";

/**
 * Represents a transition two different time references.
 *
 * Normally this is between standard time and daylight savings time.
 *
 * Immutable, thread safe.
 * @internal
 */
export class ZoneTransition {
  /**
   * Initializes a new instance of the {@link ZoneTransition} class.
   * @param instant The instant that this transition occurs at.
   * @param name The name for the time at this transition e.g. PDT or PST.
   * @param standardOffset The standard offset at this transition.
   * @param savings The actual offset at this transition.
   */
  static NewInstantNameStandardOffsetSavings(instant: Instant, name: string, standardOffset: Offset, savings: Offset): ZoneTransition {
    return new ZoneTransition(instant, name, standardOffset, savings);
  }

  private constructor(instant: Instant, name: string, standardOffset: Offset, savings: Offset) {
    Preconditions.CheckNotNull(name, "name");
    this.Instant = instant;
    this.Name = name;
    this.StandardOffset = standardOffset;
    this.Savings = savings;
  }

  /**
   * The instant at which the transition occurs.
   */
  readonly Instant: Instant;

  /**
   * The name of the zone interval after this transition.
   */
  readonly Name: string;

  /**
   * The standard offset after this transition.
   */
  readonly StandardOffset: Offset;

  /**
   * The daylight savings after this transition.
   */
  readonly Savings: Offset;

  /**
   * The wall offset (savings + standard) after this transition.
   */
  get WallOffset(): Offset {
    return this.StandardOffset.Plus(this.Savings);
  }

  /**
   * Determines whether is a transition from the given transition.
   *
   * To be a transition from another the instant at which the transition occurs must be
   * greater than the given transition's and at least one aspect out of (name, standard
   * offset, wall offset) must differ. If this is not true then this transition is considered
   * to be redundant and should not be used. Note that there are a few transitions which
   * keep the same wall offset and name, but differ in how that wall offset is divided into
   * daylight saving and standard components. One notable example of this is October 27th 1968, when
   * the UK went from "British Summer Time" (BST, standard=0, daylight=1) to "British Standard Time"
   * (BST, standard=1, daylight=0).
   * @param other The {@link ZoneTransition} to compare to.
   * @returns `true` if this is a transition from the given transition; otherwise, `false`.
   */
  IsTransitionFrom(other: ZoneTransition): boolean {
    Preconditions.CheckNotNull(other, "other");
    const later = this.Instant.CompareTo(other.Instant) > 0;
    const different = this.Name !== other.Name || !this.StandardOffset.Equals(other.StandardOffset) || !this.Savings.Equals(other.Savings);
    return later && different;
  }

  /**
   * Creates a new zone interval from this transition to the given end point.
   * @param end The end of the interval.
   */
  ToZoneInterval(end: Instant): ZoneInterval {
    return ZoneInterval.NewNameStartEndWallOffsetSavings(this.Name, this.Instant, end, this.StandardOffset.Plus(this.Savings), this.Savings);
  }

  // #region Object overrides

  /**
   * Returns a string that represents this instance.
   * @returns A string that represents this instance.
   */
  toString(): string {
    return `${this.Name} at ${this.Instant.toString()} ${this.StandardOffset.toString()} [${this.Savings.toString()}]`;
  }
  // #endregion // Object overrides
}
