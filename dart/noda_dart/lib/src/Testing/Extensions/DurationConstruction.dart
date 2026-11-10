// Ported from NodaTime 6e024dde: src/NodaTime.Testing/Extensions/DurationConstruction.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../../Duration.dart';

// noda_dart: two extensions, on int and on double (DurationConstructionDouble): `5.Days()`, `1.5.Hours()`.

/// Extension methods for constructing [Duration] values.
extension DurationConstruction on int {
  /// Constructs a duration with the specified number of days.
  ///
  /// [days]: The desired number of days (this value).
  ///
  /// Returns a duration with the specified number of days.
  Duration Days() => Duration.FromDays(this);

  /// Constructs a duration with the specified number of hours.
  ///
  /// [hours]: The desired number of hours (this value).
  ///
  /// Returns a duration with the specified number of hours.
  Duration Hours() => Duration.FromHours(this);

  /// Constructs a duration with the specified number of minutes.
  ///
  /// [minutes]: The desired number of minutes (this value).
  ///
  /// Returns a duration with the specified number of minutes.
  Duration Minutes() => Duration.FromMinutes(this);

  /// Constructs a duration with the specified number of seconds.
  ///
  /// [seconds]: The desired number of seconds (this value).
  ///
  /// Returns a duration with the specified number of seconds.
  Duration Seconds() => Duration.FromSeconds(this);

  /// Constructs a duration with the specified number of milliseconds.
  ///
  /// [milliseconds]: The desired number of milliseconds (this value).
  ///
  /// Returns a duration with the specified number of milliseconds.
  Duration Milliseconds() => Duration.FromMilliseconds(this);

  /// Constructs a duration with the specified number of ticks.
  ///
  /// [ticks]: The desired number of ticks (this value).
  ///
  /// Returns a duration with the specified number of ticks.
  Duration Ticks() => Duration.FromTicks(this);

  /// Constructs a duration with the specified number of nanoseconds.
  ///
  /// [nanoseconds]: The desired number of nanoseconds (this value).
  ///
  /// Returns a duration with the specified number of nanoseconds.
  Duration Nanoseconds() => Duration.FromNanoseconds(this);
}

/// Extension methods for constructing [Duration] values: NodaTime's `double` overloads.
extension DurationConstructionDouble on double {
  /// Constructs a duration with the specified number of days.
  ///
  /// [days]: The desired number of days (this value).
  ///
  /// Returns a duration with the specified number of days.
  Duration Days() => Duration.FromDaysDouble(this);

  /// Constructs a duration with the specified number of hours.
  ///
  /// [hours]: The desired number of hours (this value).
  ///
  /// Returns a duration with the specified number of hours.
  Duration Hours() => Duration.FromHoursDouble(this);

  /// Constructs a duration with the specified number of minutes.
  ///
  /// [minutes]: The desired number of minutes (this value).
  ///
  /// Returns a duration with the specified number of minutes.
  Duration Minutes() => Duration.FromMinutesDouble(this);

  /// Constructs a duration with the specified number of seconds.
  ///
  /// [seconds]: The desired number of seconds (this value).
  ///
  /// Returns a duration with the specified number of seconds.
  Duration Seconds() => Duration.FromSecondsDouble(this);

  /// Constructs a duration with the specified number of milliseconds.
  ///
  /// [milliseconds]: The desired number of milliseconds (this value).
  ///
  /// Returns a duration with the specified number of milliseconds.
  Duration Milliseconds() => Duration.FromMillisecondsDouble(this);

  /// Constructs a duration with the specified number of ticks.
  ///
  /// [ticks]: The desired number of ticks (this value).
  ///
  /// Returns a duration with the specified number of ticks.
  Duration Ticks() => Duration.FromTicksDouble(this);

  /// Constructs a duration with the specified number of nanoseconds.
  ///
  /// [nanoseconds]: The desired number of nanoseconds (this value).
  ///
  /// Returns a duration with the specified number of nanoseconds.
  Duration Nanoseconds() => Duration.FromNanosecondsDouble(this);
}
