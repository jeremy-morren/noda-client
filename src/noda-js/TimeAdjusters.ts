// Ported from NodaTime 3.3.7: src/NodaTime/TimeAdjusters.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { LocalTime } from "./internal.ts";
import type { LocalDateTime, OffsetDateTime } from "./internal.ts";

let truncateToSecond: ((time: LocalTime) => LocalTime) | undefined;
let truncateToMinute: ((time: LocalTime) => LocalTime) | undefined;
let truncateToHour: ((time: LocalTime) => LocalTime) | undefined;

/**
 * Factory class for time adjusters: functions from {@link LocalTime} to `LocalTime`,
 * which can be applied to {@link LocalTime}, {@link LocalDateTime}, and {@link OffsetDateTime}.
 */
export abstract class TimeAdjusters {
  private constructor() {}

  /** Gets a time adjuster to truncate the time to the second, discarding fractional seconds. */
  static get TruncateToSecond(): (time: LocalTime) => LocalTime {
    return (truncateToSecond ??= time => new LocalTime(time.Hour, time.Minute, time.Second));
  }

  /** Gets a time adjuster to truncate the time to the minute, discarding fractional minutes. */
  static get TruncateToMinute(): (time: LocalTime) => LocalTime {
    return (truncateToMinute ??= time => new LocalTime(time.Hour, time.Minute));
  }

  /** Get a time adjuster to truncate the time to the hour, discarding fractional hours. */
  static get TruncateToHour(): (time: LocalTime) => LocalTime {
    return (truncateToHour ??= time => new LocalTime(time.Hour, 0));
  }
}
