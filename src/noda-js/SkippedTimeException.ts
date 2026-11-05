// Ported from NodaTime 3.3.7: src/NodaTime/SkippedTimeException.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions } from "./internal.ts";
import type { DateTimeZone, LocalDateTime } from "./internal.ts";
import { NodaError } from "./internal.ts";
import type { ArgumentOutOfRangeException } from "./internal.ts";

/**
 * Exception thrown to indicate that the specified local time doesn't
 * exist in a particular time zone due to daylight saving time changes.
 *
 * This normally occurs for spring transitions, where the clock goes forward
 * (usually by an hour). For example, suppose the time zone goes forward
 * at 2am, so the second after 01:59:59 becomes 03:00:00. In that case,
 * local times such as 02:30:00 never occur.
 *
 * This exception is used to indicate such problems, as they're usually
 * not the same as other {@link ArgumentOutOfRangeException} causes,
 * such as entering "15" for a month number.
 *
 * Note that it is possible (though extremely rare) for a whole day to be skipped due to a time zone transition,
 * so this exception may also be thrown in cases where no local time is valid for a particular local date. (For
 * example, Samoa skipped December 30th 2011 entirely, transitioning from UTC-10 to UTC+14 at midnight.)
 */
export class SkippedTimeException extends NodaError<"SkippedTimeException"> {
  /** The name of the invalid parameter: null (as ArgumentOutOfRangeException's ParamName for this exception). */
  readonly ParamName: string | null = null;

  /** The argument's value: undefined (as ArgumentOutOfRangeException's ActualValue for this exception). */
  readonly ActualValue: unknown = undefined;

  private readonly _localDateTime: LocalDateTime;

  /**
   * Gets the local date/time which is invalid in the time zone, prompting this exception.
   */
  get LocalDateTime(): LocalDateTime {
    return this._localDateTime;
  }

  private readonly _zone: DateTimeZone;

  /**
   * Gets the time zone in which the local date/time is invalid.
   */
  get Zone(): DateTimeZone {
    return this._zone;
  }

  /**
   * Creates a new instance for the given local date/time and time zone.
   *
   * User code is unlikely to need to deliberately call this constructor except
   * possibly for testing.
   *
   * @param localDateTime The local date/time which is skipped in the specified time zone.
   * @param zone The time zone in which the local date/time does not exist.
   */
  constructor(localDateTime: LocalDateTime, zone: DateTimeZone) {
    super("SkippedTimeException", `Local time ${localDateTime} is invalid in time zone ${Preconditions.CheckNotNull(zone, "zone").Id}`);
    this._localDateTime = localDateTime;
    this._zone = zone;
  }
}
