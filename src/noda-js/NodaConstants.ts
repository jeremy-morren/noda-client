// Ported from NodaTime 3.3.0: src/NodaTime/NodaConstants.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// Leaf module: imported directly (not via the barrel) because the values are used at evaluation time.
import * as C from "./NodaConstants.generated.ts";
import { Instant } from "./internal.ts";

let unixEpoch: Instant | undefined;
let bclEpoch: Instant | undefined;
let julianEpoch: Instant | undefined;

/**
 * Useful constants, mostly along the lines of "number of milliseconds in an hour".
 */
export class NodaConstants {
  private constructor() {}

  /** A constant for the number of nanoseconds in a tick. The value of this constant is 100. */
  static readonly NanosecondsPerTick: number = C.NanosecondsPerTick;

  /** A constant for the number of nanoseconds in a microsecond. The value of this constant is 1,000. */
  static readonly NanosecondsPerMicrosecond: number = C.NanosecondsPerMicrosecond;

  /** A constant for the number of nanoseconds in a millisecond. The value of this constant is 1,000,000. */
  static readonly NanosecondsPerMillisecond: number = C.NanosecondsPerMillisecond;

  /** A constant for the number of nanoseconds in a second. The value of this constant is 1,000,000,000. */
  static readonly NanosecondsPerSecond: number = C.NanosecondsPerSecond;

  /** A constant for the number of nanoseconds in a minute. The value of this constant is 60,000,000,000. */
  static readonly NanosecondsPerMinute: number = C.NanosecondsPerMinute;

  /** A constant for the number of nanoseconds in an hour. The value of this constant is 3,600,000,000,000. */
  static readonly NanosecondsPerHour: number = C.NanosecondsPerHour;

  /** A constant for the number of nanoseconds in a standard 24-hour day. The value of this constant is 86,400,000,000,000. */
  static readonly NanosecondsPerDay: number = C.NanosecondsPerDay;

  /** A constant for the number of nanoseconds in a standard week of seven 24-hour days. The value of this constant is 604,800,000,000,000. */
  static readonly NanosecondsPerWeek: number = C.NanosecondsPerWeek;

  /** A constant for the number of ticks in a millisecond. The value of this constant is 10,000. */
  static readonly TicksPerMillisecond: number = C.TicksPerMillisecond;
  /** A constant for the number of ticks in a second. The value of this constant is 10,000,000. */
  static readonly TicksPerSecond: number = C.TicksPerSecond;
  /** A constant for the number of ticks in a minute. The value of this constant is 600,000,000. */
  static readonly TicksPerMinute: number = C.TicksPerMinute;
  /** A constant for the number of ticks in an hour. The value of this constant is 36,000,000,000. */
  static readonly TicksPerHour: number = C.TicksPerHour;

  /**
   * A constant for the number of ticks in a standard 24-hour day.
   * The value of this constant is 864,000,000,000.
   */
  static readonly TicksPerDay: number = C.TicksPerDay;

  /**
   * A constant for the number of ticks in a standard week of seven 24-hour days.
   * The value of this constant is 6,048,000,000,000.
   */
  static readonly TicksPerWeek: number = C.TicksPerWeek;

  /**
   * A constant for the number of microseconds per second.
   * The value of this constant is 1,000,000.
   */
  static readonly MicrosecondsPerSecond: number = C.MicrosecondsPerSecond;

  /**
   * A constant for the number of milliseconds per second.
   * The value of this constant is 1000.
   */
  static readonly MillisecondsPerSecond: number = C.MillisecondsPerSecond;
  /**
   * A constant for the number of milliseconds per minute.
   * The value of this constant is 60,000.
   */
  static readonly MillisecondsPerMinute: number = C.MillisecondsPerMinute;
  /**
   * A constant for the number of milliseconds per hour.
   * The value of this constant is 3,600,000.
   */
  static readonly MillisecondsPerHour: number = C.MillisecondsPerHour;
  /**
   * A constant for the number of milliseconds per standard 24-hour day.
   * The value of this constant is 86,400,000.
   */
  static readonly MillisecondsPerDay: number = C.MillisecondsPerDay;
  /**
   * A constant for the number of milliseconds per standard week of seven 24-hour days.
   * The value of this constant is 604,800,000.
   */
  static readonly MillisecondsPerWeek: number = C.MillisecondsPerWeek;

  /**
   * A constant for the number of seconds per minute.
   * The value of this constant is 60.
   */
  static readonly SecondsPerMinute: number = C.SecondsPerMinute;
  /**
   * A constant for the number of seconds per hour.
   * The value of this constant is 3,600.
   */
  static readonly SecondsPerHour: number = C.SecondsPerHour;
  /**
   * A constant for the number of seconds per standard 24-hour day.
   * The value of this constant is 86,400.
   */
  static readonly SecondsPerDay: number = C.SecondsPerDay;
  /**
   * A constant for the number of seconds per standard week of seven 24-hour days.
   * The value of this constant is 604,800.
   */
  static readonly SecondsPerWeek: number = C.SecondsPerWeek;

  /**
   * A constant for the number of minutes per hour.
   * The value of this constant is 60.
   */
  static readonly MinutesPerHour: number = C.MinutesPerHour;
  /**
   * A constant for the number of minutes per standard 24-hour day.
   * The value of this constant is 1,440.
   */
  static readonly MinutesPerDay: number = C.MinutesPerDay;
  /**
   * A constant for the number of minutes per standard week of seven 24-hour days.
   * The value of this constant is 10,080.
   */
  static readonly MinutesPerWeek: number = C.MinutesPerWeek;

  /**
   * A constant for the number of hours in a standard day. Note that the number of hours
   * in a day can vary due to daylight saving effects.
   * The value of this constant is 24.
   */
  static readonly HoursPerDay: number = C.HoursPerDay;
  /**
   * A constant for the number of hours in a standard week of seven 24-hour days.
   * The value of this constant is 168.
   */
  static readonly HoursPerWeek: number = C.HoursPerWeek;

  /**
   * Number of days in a standard Gregorian week.
   * The value of this constant is 7.
   */
  static readonly DaysPerWeek: number = C.DaysPerWeek;

  /**
   * The instant at the Unix epoch of midnight 1st January 1970 UTC.
   */
  static get UnixEpoch(): Instant {
    return (unixEpoch ??= Instant.FromUnixTimeTicks(0));
  }

  /**
   * The instant at the BCL epoch of midnight 1st January 0001 UTC.
   */
  static get BclEpoch(): Instant {
    return (bclEpoch ??= Instant.FromUtc(1, 1, 1, 0, 0));
  }

  /**
   * The instant at the Julian epoch of noon (UTC) January 1st 4713 BCE in the proleptic
   * Julian calendar, or November 24th 4714 BCE in the proleptic Gregorian calendar.
   */
  static get JulianEpoch(): Instant {
    return (julianEpoch ??= Instant.FromUtc(-4713, 11, 24, 12, 0));
  }

  // These are checked in NodaConstantsTest.
  /**
   * The number of ticks in a BCL DateTime at the Unix epoch.
   * (noda-js: this exceeds 2^53, but is exactly representable as a number.)
   * @internal
   */
  static readonly BclTicksAtUnixEpoch: number = 621355968000000000;

  /**
   * The number of days in a BCL DateTime at the Unix epoch.
   * @internal
   */
  static readonly BclDaysAtUnixEpoch: number = 719162;
}
