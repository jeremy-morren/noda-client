// Ported from NodaTime 3.3.0: src/NodaTime/AmbiguousTimeException.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ArgumentOutOfRangeError, Preconditions } from "./internal.ts";
import type { DateTimeZone, LocalDateTime, ZonedDateTime } from "./internal.ts";

/**
 * Exception thrown to indicate that the specified local date/time occurs twice
 * in a particular time zone due to daylight saving time changes.
 *
 * This occurs for transitions where the clock goes backward (usually by
 * an hour). For example, suppose the time zone goes backward
 * at 2am, so the second after 01:59:59 becomes 01:00:00. In that case,
 * times such as 01:30:00 occur twice.
 *
 * This exception is used to indicate such problems, as they're usually
 * not the same as other {@link ArgumentOutOfRangeError} causes,
 * such as entering "15" for a month number.
 *
 * In theory this isn't calendar-specific; the local value will be ambiguous in
 * this time zone regardless of the calendar used. However, this exception is
 * always created in conjunction with a specific calendar, which leads to a more
 * natural way of examining its information and constructing an error message.
 */
export class AmbiguousTimeError extends ArgumentOutOfRangeError {
  override name = "AmbiguousTimeError";

  /**
   * Get the local date and time which is ambiguous in the time zone.
   * @internal
   */
  get LocalDateTime(): LocalDateTime {
    return this.EarlierMapping.LocalDateTime;
  }

  /**
   * The time zone in which the local date and time is ambiguous.
   */
  get Zone(): DateTimeZone {
    return this.EarlierMapping.Zone;
  }

  private readonly _earlierMapping: ZonedDateTime;

  /**
   * Gets the earlier of the two occurrences of the local date and time within the time zone.
   */
  get EarlierMapping(): ZonedDateTime {
    return this._earlierMapping;
  }

  private readonly _laterMapping: ZonedDateTime;

  /**
   * Gets the later of the two occurrences of the local date and time within the time zone.
   */
  get LaterMapping(): ZonedDateTime {
    return this._laterMapping;
  }

  /**
   * Constructs an instance from the given information.
   *
   * User code is unlikely to need to deliberately call this constructor except
   * possibly for testing.
   *
   * The two mappings must have the same local time and time zone.
   *
   * @param earlierMapping The earlier possible mapping
   * @param laterMapping The later possible mapping
   */
  constructor(earlierMapping: ZonedDateTime, laterMapping: ZonedDateTime) {
    super(null, undefined, `Local time ${earlierMapping.LocalDateTime} is ambiguous in time zone ${earlierMapping.Zone.Id}`);
    this._earlierMapping = earlierMapping;
    this._laterMapping = laterMapping;
    Preconditions.CheckArgument(earlierMapping.Zone === laterMapping.Zone, "laterMapping",
      "Ambiguous possible values must use the same time zone");
    Preconditions.CheckArgument(earlierMapping.LocalDateTime.Equals(laterMapping.LocalDateTime), "laterMapping",
      "Ambiguous possible values must have the same local date/time");
  }
}
