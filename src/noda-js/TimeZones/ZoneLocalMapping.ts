// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/ZoneLocalMapping.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { AmbiguousTimeException, Preconditions, SkippedTimeException, ZonedDateTime } from "../internal.ts";
import type { DateTimeZone, LocalDateTime, ZoneInterval } from "../internal.ts";
import { NewInvalidOperationException } from "../internal.ts";

// Note: documentation that refers to the LocalDateTime type within this class must use the fully-qualified
// reference to avoid being resolved to the LocalDateTime property instead.

/**
 * The result of mapping a {@link LocalDateTime} within a time zone, i.e. finding out
 * at what "global" time the "local" time occurred.
 *
 * This class is used as the return type of {@link DateTimeZone.MapLocal}. It allows for
 * finely-grained handling of the three possible results:
 *
 * - **Unambiguous mapping**: The local time occurs exactly once in the target time zone.
 * - **Ambiguous mapping**: The local time occurs twice in the target time zone, due to the offset from UTC
 *   changing. This usually occurs for an autumnal daylight saving transition, where the clocks
 *   are put back by an hour. If the clocks change from 2am to 1am for example, then 1:30am occurs
 *   twice - once before the transition and once afterwards.
 * - **Impossible mapping**: The local time does not occur at all in the target time zone, due to the offset from UTC
 *   changing. This usually occurs for a vernal (spring-time) daylight saving transition, where the clocks
 *   are put forward by an hour. If the clocks change from 1am to 2am for example, then 1:30am is
 *   skipped entirely.
 *
 * This type is an immutable reference type. See the thread safety section of the user guide for more information.
 */
export class ZoneLocalMapping {
  private readonly _zone: DateTimeZone;

  /**
   * Gets the {@link DateTimeZone} in which this mapping was performed.
   */
  get Zone(): DateTimeZone {
    return this._zone;
  }

  private readonly _localDateTime: LocalDateTime;

  /**
   * Gets the {@link LocalDateTime} which was mapped within the time zone.
   */
  get LocalDateTime(): LocalDateTime {
    return this._localDateTime;
  }

  private readonly _earlyInterval: ZoneInterval;

  /**
   * Gets the earlier {@link ZoneInterval} within this mapping.
   *
   * For unambiguous mappings, this is the same as {@link LateInterval}; for ambiguous mappings,
   * this is the interval during which the mapped local time first occurs; for impossible
   * mappings, this is the interval before which the mapped local time occurs.
   */
  get EarlyInterval(): ZoneInterval {
    return this._earlyInterval;
  }

  private readonly _lateInterval: ZoneInterval;

  /**
   * Gets the later {@link ZoneInterval} within this mapping.
   *
   * For unambiguous
   * mappings, this is the same as {@link EarlyInterval}; for ambiguous mappings,
   * this is the interval during which the mapped local time last occurs; for impossible
   * mappings, this is the interval after which the mapped local time occurs.
   */
  get LateInterval(): ZoneInterval {
    return this._lateInterval;
  }

  private readonly _count: number;

  /**
   * Gets the number of results within this mapping: the number of distinct
   * {@link ZonedDateTime} values which map to the original {@link LocalDateTime}.
   */
  get Count(): number {
    return this._count;
  }

  private constructor(zone: DateTimeZone, localDateTime: LocalDateTime,
    earlyInterval: ZoneInterval, lateInterval: ZoneInterval, count: number) {
    Preconditions.DebugCheckNotNull(zone, "zone");
    Preconditions.DebugCheckNotNull(earlyInterval, "earlyInterval");
    Preconditions.DebugCheckNotNull(lateInterval, "lateInterval");
    Preconditions.DebugCheckArgumentRange("count", count, 0, 2);
    this._zone = zone;
    this._earlyInterval = earlyInterval;
    this._lateInterval = lateInterval;
    this._localDateTime = localDateTime;
    this._count = count;
  }

  /** @internal */
  static NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(zone: DateTimeZone, localDateTime: LocalDateTime,
    earlyInterval: ZoneInterval, lateInterval: ZoneInterval, count: number): ZoneLocalMapping {
    return new ZoneLocalMapping(zone, localDateTime, earlyInterval, lateInterval, count);
  }

  /**
   * Returns the single {@link ZonedDateTime} which maps to the original
   * {@link LocalDateTime} in the mapped {@link DateTimeZone}.
   *
   * @throws {SkippedTimeException} The local date/time was skipped in the time zone.
   * @throws {AmbiguousTimeException} The local date/time was ambiguous in the time zone.
   * @returns The unambiguous result of mapping the local date/time in the time zone.
   */
  Single(): ZonedDateTime {
    switch (this.Count) {
      case 0: throw new SkippedTimeException(this.LocalDateTime, this.Zone);
      case 1: return this.BuildZonedDateTime(this.EarlyInterval);
      case 2:
        throw new AmbiguousTimeException(
          this.BuildZonedDateTime(this.EarlyInterval),
          this.BuildZonedDateTime(this.LateInterval));
      default: throw NewInvalidOperationException("Can't happen");
    }
  }

  // TODO: Reimplement as switch expressions after fixing https://github.com/nodatime/nodatime/issues/1269

  /**
   * Returns a {@link ZonedDateTime} which maps to the original {@link LocalDateTime}
   * in the mapped {@link DateTimeZone}: either the single result if the mapping is unambiguous,
   * or the earlier result if the local date/time occurs twice in the time zone due to a time zone
   * offset change such as an autumnal daylight saving transition.
   *
   * @throws {SkippedTimeException} The local date/time was skipped in the time zone.
   * @returns The unambiguous result of mapping a local date/time in a time zone.
   */
  First(): ZonedDateTime {
    switch (this.Count) {
      case 0: throw new SkippedTimeException(this.LocalDateTime, this.Zone);
      case 1:
      case 2: return this.BuildZonedDateTime(this.EarlyInterval);
      default: throw NewInvalidOperationException("Can't happen");
    }
  }

  /**
   * Returns a {@link ZonedDateTime} which maps to the original {@link LocalDateTime}
   * in the mapped {@link DateTimeZone}: either the single result if the mapping is unambiguous,
   * or the later result if the local date/time occurs twice in the time zone due to a time zone
   * offset change such as an autumnal daylight saving transition.
   *
   * @throws {SkippedTimeException} The local date/time was skipped in the time zone.
   * @returns The unambiguous result of mapping a local date/time in a time zone.
   */
  Last(): ZonedDateTime {
    switch (this.Count) {
      case 0: throw new SkippedTimeException(this.LocalDateTime, this.Zone);
      case 1: return this.BuildZonedDateTime(this.EarlyInterval);
      case 2: return this.BuildZonedDateTime(this.LateInterval);
      default: throw NewInvalidOperationException("Can't happen");
    }
  }

  private BuildZonedDateTime(interval: ZoneInterval): ZonedDateTime {
    return ZonedDateTime.NewOffsetDateTimeZone(this.LocalDateTime.WithOffset(interval.WallOffset), this.Zone);
  }
}
