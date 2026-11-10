// Ported from NodaTime 6e024dde: src/NodaTime/Extensions/ClockExtensions.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../CalendarSystem.dart';
import '../DateTimeZone.dart';
import '../DateTimeZoneProviders.dart';
import '../IClock.dart';
import '../ZonedClock.dart';

/// Extension methods for [IClock].
extension ClockExtensions on IClock {
  /// Constructs a [ZonedClock] from a clock (the target of the method),
  /// a time zone, and a calendar system (the ISO calendar system if [calendar] is omitted).
  ///
  /// (C#'s `InZone(IClock, DateTimeZone)` and `InZone(IClock, DateTimeZone, CalendarSystem)`.)
  ///
  /// [zone]: Time zone to use in the returned object.
  /// [calendar]: Calendar to use in the returned object.
  ///
  /// Returns a [ZonedClock] with the given clock, time zone and calendar system.
  ZonedClock InZone(DateTimeZone zone, [CalendarSystem? calendar]) =>
      ZonedClock(this, zone, calendar ?? CalendarSystem.Iso);

  /// Constructs a [ZonedClock] from a clock (the target of the method),
  /// using the UTC time zone and ISO calendar system.
  ///
  /// Returns a [ZonedClock] with the given clock, in the UTC time zone and ISO calendar system.
  ZonedClock InUtc() => ZonedClock(this, DateTimeZone.Utc, CalendarSystem.Iso);

  /// Constructs a [ZonedClock] from a clock (the target of the method),
  /// in the TZDB mapping for the system default time zone time zone and the ISO calendar system.
  ///
  /// Returns a `ZonedClock` in the system default time zone (using TZDB) and the ISO calendar system,
  /// using the system clock.
  ///
  /// Throws [DateTimeZoneNotFoundException] if the system default time zone is not mapped by
  /// TZDB.
  ///
  /// See also [DateTimeZoneProviders.Tzdb].
  ZonedClock InTzdbSystemDefaultZone() {
    var zone = DateTimeZoneProviders.Tzdb.GetSystemDefault();
    return ZonedClock(this, zone, CalendarSystem.Iso);
  }

  // Not ported: InBclSystemDefaultZone (use InZone with the system provider's GetSystemDefault())
}
