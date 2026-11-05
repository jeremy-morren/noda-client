// Ported from NodaTime 3.3.0: src/NodaTime/ZonedClock.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarSystem,
  DateTimeZone,
  Instant,
  LocalDate,
  LocalDateTime,
  LocalTime,
  OffsetDateTime,
  Preconditions,
  ZonedDateTime,
} from "./internal.ts";
import type { IClock } from "./internal.ts";

/**
 * A clock with an associated time zone and calendar. This is effectively a convenience
 * class decorating an {@link IClock}.
 *
 * This type is immutable reference type. See the thread safety section of the user guide for more information.
 */
export class ZonedClock implements IClock {
  private readonly _clock: IClock;
  private readonly _zone: DateTimeZone;
  private readonly _calendar: CalendarSystem;

  /** Gets the clock used to provide the current instant. */
  get Clock(): IClock {
    return this._clock;
  }

  /** Gets the time zone used when converting the current instant into a zone-sensitive value. */
  get Zone(): DateTimeZone {
    return this._zone;
  }

  /** Gets the calendar system used when converting the current instant into a calendar-sensitive value. */
  get Calendar(): CalendarSystem {
    return this._calendar;
  }

  /**
   * Creates a new {@link ZonedClock} with the given clock, time zone and calendar system.
   * @param clock Clock to use to obtain instants.
   * @param zone Time zone to adjust instants into.
   * @param calendar Calendar system to use.
   */
  constructor(clock: IClock, zone: DateTimeZone, calendar: CalendarSystem) {
    this._clock = Preconditions.CheckNotNull(clock, "clock");
    this._zone = Preconditions.CheckNotNull(zone, "zone");
    this._calendar = Preconditions.CheckNotNull(calendar, "calendar");
  }

  /**
   * Returns the current instant provided by the underlying clock.
   * @returns The current instant provided by the underlying clock.
   */
  GetCurrentInstant(): Instant {
    return this._clock.GetCurrentInstant();
  }

  /**
   * Returns the current instant provided by the underlying clock, adjusted
   * to the time zone of this object.
   * @returns The current instant provided by the underlying clock, adjusted to the
   * time zone of this object.
   */
  GetCurrentZonedDateTime(): ZonedDateTime {
    return this.GetCurrentInstant().InZone(this._zone, this._calendar);
  }

  /**
   * Returns the local date/time of the current instant provided by the underlying clock, adjusted
   * to the time zone of this object.
   * @returns The local date/time of the current instant provided by the underlying clock, adjusted to the
   * time zone of this object.
   */
  GetCurrentLocalDateTime(): LocalDateTime {
    return this.GetCurrentZonedDateTime().LocalDateTime;
  }

  /**
   * Returns the offset date/time of the current instant provided by the underlying clock, adjusted
   * to the time zone of this object.
   * @returns The offset date/time of the current instant provided by the underlying clock, adjusted to the
   * time zone of this object.
   */
  GetCurrentOffsetDateTime(): OffsetDateTime {
    return this.GetCurrentZonedDateTime().ToOffsetDateTime();
  }

  /**
   * Returns the local date of the current instant provided by the underlying clock, adjusted
   * to the time zone of this object.
   * @returns The local date of the current instant provided by the underlying clock, adjusted to the
   * time zone of this object.
   */
  GetCurrentDate(): LocalDate {
    return this.GetCurrentZonedDateTime().Date;
  }

  /**
   * Returns the local time of the current instant provided by the underlying clock, adjusted
   * to the time zone of this object.
   * @returns The local time of the current instant provided by the underlying clock, adjusted to the
   * time zone of this object.
   */
  GetCurrentTimeOfDay(): LocalTime {
    return this.GetCurrentZonedDateTime().TimeOfDay;
  }
}
