// Ported from NodaTime 6e024dde: src/NodaTime/NodaConstants.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Instant.dart';
import 'NodaConstants.generated.dart' as generated;

/// Useful constants, mostly along the lines of "number of milliseconds in an hour".
///
/// (noda_dart: the values of the `const` fields come from NodaTime itself, in NodaConstants.generated.dart.)
abstract final class NodaConstants {
  /// A constant for the number of nanoseconds in a tick. The value of this constant is 100.
  static const int NanosecondsPerTick = generated.NanosecondsPerTick;

  /// A constant for the number of nanoseconds in a microsecond. The value of this constant is 1,000.
  static const int NanosecondsPerMicrosecond = generated.NanosecondsPerMicrosecond;

  /// A constant for the number of nanoseconds in a millisecond. The value of this constant is 1,000,000.
  static const int NanosecondsPerMillisecond = generated.NanosecondsPerMillisecond;

  /// A constant for the number of nanoseconds in a second. The value of this constant is 1,000,000,000.
  static const int NanosecondsPerSecond = generated.NanosecondsPerSecond;

  /// A constant for the number of nanoseconds in a minute. The value of this constant is 60,000,000,000.
  static const int NanosecondsPerMinute = generated.NanosecondsPerMinute;

  /// A constant for the number of nanoseconds in an hour. The value of this constant is 3,600,000,000,000.
  static const int NanosecondsPerHour = generated.NanosecondsPerHour;

  /// A constant for the number of nanoseconds in a standard 24-hour day. The value of this constant is 86,400,000,000,000.
  static const int NanosecondsPerDay = generated.NanosecondsPerDay;

  /// A constant for the number of nanoseconds in a standard week of seven 24-hour days. The value of this constant is 604,800,000,000,000.
  static const int NanosecondsPerWeek = generated.NanosecondsPerWeek;

  /// A constant for the number of ticks in a millisecond. The value of this constant is 10,000.
  static const int TicksPerMillisecond = generated.TicksPerMillisecond;

  /// A constant for the number of ticks in a second. The value of this constant is 10,000,000.
  static const int TicksPerSecond = generated.TicksPerSecond;

  /// A constant for the number of ticks in a minute. The value of this constant is 600,000,000.
  static const int TicksPerMinute = generated.TicksPerMinute;

  /// A constant for the number of ticks in an hour. The value of this constant is 36,000,000,000.
  static const int TicksPerHour = generated.TicksPerHour;

  /// A constant for the number of ticks in a standard 24-hour day.
  /// The value of this constant is 864,000,000,000.
  static const int TicksPerDay = generated.TicksPerDay;

  /// A constant for the number of ticks in a standard week of seven 24-hour days.
  /// The value of this constant is 6,048,000,000,000.
  static const int TicksPerWeek = generated.TicksPerWeek;

  /// A constant for the number of microseconds per second.
  /// The value of this constant is 1,000,000.
  static const int MicrosecondsPerSecond = generated.MicrosecondsPerSecond;

  /// A constant for the number of milliseconds per second.
  /// The value of this constant is 1000.
  static const int MillisecondsPerSecond = generated.MillisecondsPerSecond;

  /// A constant for the number of milliseconds per minute.
  /// The value of this constant is 60,000.
  static const int MillisecondsPerMinute = generated.MillisecondsPerMinute;

  /// A constant for the number of milliseconds per hour.
  /// The value of this constant is 3,600,000.
  static const int MillisecondsPerHour = generated.MillisecondsPerHour;

  /// A constant for the number of milliseconds per standard 24-hour day.
  /// The value of this constant is 86,400,000.
  static const int MillisecondsPerDay = generated.MillisecondsPerDay;

  /// A constant for the number of milliseconds per standard week of seven 24-hour days.
  /// The value of this constant is 604,800,000.
  static const int MillisecondsPerWeek = generated.MillisecondsPerWeek;

  /// A constant for the number of seconds per minute.
  /// The value of this constant is 60.
  static const int SecondsPerMinute = generated.SecondsPerMinute;

  /// A constant for the number of seconds per hour.
  /// The value of this constant is 3,600.
  static const int SecondsPerHour = generated.SecondsPerHour;

  /// A constant for the number of seconds per standard 24-hour day.
  /// The value of this constant is 86,400.
  static const int SecondsPerDay = generated.SecondsPerDay;

  /// A constant for the number of seconds per standard week of seven 24-hour days.
  /// The value of this constant is 604,800.
  static const int SecondsPerWeek = generated.SecondsPerWeek;

  /// A constant for the number of minutes per hour.
  /// The value of this constant is 60.
  static const int MinutesPerHour = generated.MinutesPerHour;

  /// A constant for the number of minutes per standard 24-hour day.
  /// The value of this constant is 1,440.
  static const int MinutesPerDay = generated.MinutesPerDay;

  /// A constant for the number of minutes per standard week of seven 24-hour days.
  /// The value of this constant is 10,080.
  static const int MinutesPerWeek = generated.MinutesPerWeek;

  /// A constant for the number of hours in a standard day. Note that the number of hours
  /// in a day can vary due to daylight saving effects.
  /// The value of this constant is 24.
  static const int HoursPerDay = generated.HoursPerDay;

  /// A constant for the number of hours in a standard week of seven 24-hour days.
  /// The value of this constant is 168.
  static const int HoursPerWeek = generated.HoursPerWeek;

  /// Number of days in a standard Gregorian week.
  /// The value of this constant is 7.
  static const int DaysPerWeek = generated.DaysPerWeek;

  /// The instant at the Unix epoch of midnight 1st January 1970 UTC.
  static final Instant UnixEpoch = Instant.FromUnixTimeTicks(0);

  /// The instant at the BCL epoch of midnight 1st January 0001 UTC.
  static final Instant BclEpoch = Instant.FromUtc(1, 1, 1, 0, 0);

  /// The instant at the Julian epoch of noon (UTC) January 1st 4713 BCE in the proleptic
  /// Julian calendar, or November 24th 4714 BCE in the proleptic Gregorian calendar.
  static final Instant JulianEpoch = Instant.FromUtc(-4713, 11, 24, 12, 0);

  // These are checked in NodaConstantsTest.
  /// The number of ticks in a BCL DateTime at the Unix epoch.
  /// (2^9 * 1213585875000000: exact on the web too.)
  @internal
  static const int BclTicksAtUnixEpoch = 621355968000000000;

  /// The number of days in a BCL DateTime at the Unix epoch.
  @internal
  static const int BclDaysAtUnixEpoch = 719162;
}
