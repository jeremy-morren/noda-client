// Ported from NodaTime 3.3.0: src/NodaTime.Testing/TimeZones/SingleTransitionDateTimeZone.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZone, Offset, ZoneInterval } from "../../internal.ts";
import type { Instant } from "../../internal.ts";

/**
 * Time zone with a single transition between two offsets. This provides a simple way to test behaviour across a transition.
 */
export class SingleTransitionDateTimeZone extends DateTimeZone {
  /**
   * Gets the {@link ZoneInterval} for the period before the transition, starting at the beginning of time.
   */
  readonly EarlyInterval: ZoneInterval;

  /**
   * Gets the {@link ZoneInterval} for the period after the transition, ending at the end of time.
   */
  readonly LateInterval: ZoneInterval;

  /**
   * Gets the transition instant of the zone.
   */
  get Transition(): Instant {
    return this.EarlyInterval.End;
  }

  /**
   * Creates a zone with a single transition between two offsets.
   * @param transitionPoint The transition point as an {@link Instant}.
   * @param offsetBeforeHours The offset of local time from UTC, in hours, before the transition.
   * @param offsetAfterHours The offset of local time from UTC, in hours, before the transition.
   */
  constructor(transitionPoint: Instant, offsetBeforeHours: number, offsetAfterHours: number);
  /**
   * Creates a zone with a single transition between two offsets.
   * @param transitionPoint The transition point as an {@link Instant}.
   * @param offsetBefore The offset of local time from UTC before the transition.
   * @param offsetAfter The offset of local time from UTC before the transition.
   */
  constructor(transitionPoint: Instant, offsetBefore: Offset, offsetAfter: Offset);
  /**
   * Creates a zone with a single transition between two offsets.
   * @param transitionPoint The transition point as an {@link Instant}.
   * @param offsetBefore The offset of local time from UTC before the transition.
   * @param offsetAfter The offset of local time from UTC before the transition.
   * @param id ID for the newly created time zone.
   */
  constructor(transitionPoint: Instant, offsetBefore: Offset, offsetAfter: Offset, id: string);
  constructor(transitionPoint: Instant, before: Offset | number, after: Offset | number, id: string = "Single") {
    const offsetBefore = typeof before === "number" ? Offset.FromHours(before) : before;
    const offsetAfter = typeof after === "number" ? Offset.FromHours(after) : after;
    super(id, false, Offset.Min(offsetBefore, offsetAfter), Offset.Max(offsetBefore, offsetAfter));
    this.EarlyInterval = new ZoneInterval(id + "-Early", null, transitionPoint, offsetBefore, Offset.Zero);
    this.LateInterval = new ZoneInterval(id + "-Late", transitionPoint, null, offsetAfter, Offset.Zero);
  }

  /** @inheritdoc */
  override GetZoneInterval(instant: Instant): ZoneInterval {
    return this.EarlyInterval.Contains(instant) ? this.EarlyInterval : this.LateInterval;
  }
}
