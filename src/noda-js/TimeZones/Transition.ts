// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/Transition.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ThrowValueOf } from "../internal.ts";
import type { IEquatable, Instant, Offset } from "../internal.ts";

/**
 * A transition between two offsets, usually for daylight saving reasons. This type only knows about
 * the new offset, and the transition point.
 *
 * This type is an immutable value type. See the thread safety section of the user guide for more information.
 * @internal
 */
export class Transition implements IEquatable<Transition> {
  readonly Instant: Instant;

  /**
   * The offset from the time when this transition occurs until the next transition.
   */
  readonly NewOffset: Offset;

  // noda-js: the C# constructor is internal; the type itself is internal, so the constructor is kept
  // alongside the mechanical factory.
  constructor(instant: Instant, newOffset: Offset) {
    this.Instant = instant;
    this.NewOffset = newOffset;
  }

  /** @internal */
  static NewInstantNewOffset(instant: Instant, newOffset: Offset): Transition {
    return new Transition(instant, newOffset);
  }

  /**
   * Determines whether the specified value is equal to this instance.
   * (Merges NodaTime's Equals(Transition), Equals(object) and operator ==.)
   */
  Equals(other: Transition): boolean;
  /** @inheritDoc */
  Equals(other: unknown): boolean;
  Equals(other: unknown): boolean {
    return other instanceof Transition && this.Instant.Equals(other.Instant) && this.NewOffset.Equals(other.NewOffset);
  }

  // #region Object overrides
  /**
   * Returns a string that represents this instance.
   */
  toString(): string {
    return `Transition to ${this.NewOffset} at ${this.Instant}`;
  }
  // #endregion  // Object overrides

  valueOf(): never {
    ThrowValueOf("Transition");
  }
}
