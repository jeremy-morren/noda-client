// Ported from NodaTime 6e024dde: src/NodaTime/ZonedClock.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'CalendarSystem.dart';
import 'DateTimeZone.dart';
import 'IClock.dart';
import 'Instant.dart';
import 'LocalDate.dart';
import 'LocalDateTime.dart';
import 'LocalTime.dart';
import 'OffsetDateTime.dart';
import 'ZonedDateTime.dart';

/// A clock with an associated time zone and calendar. This is effectively a convenience
/// class decorating an [IClock].
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class ZonedClock implements IClock {
  /// Gets the clock used to provide the current instant.
  final IClock Clock;

  /// Gets the time zone used when converting the current instant into a zone-sensitive value.
  final DateTimeZone Zone;

  /// Gets the calendar system used when converting the current instant into a calendar-sensitive value.
  final CalendarSystem Calendar;

  /// Creates a new [ZonedClock] with the given clock, time zone and calendar system.
  ///
  /// [clock]: Clock to use to obtain instants.
  /// [zone]: Time zone to adjust instants into.
  /// [calendar]: Calendar system to use.
  // Dart: null safety checks clock, zone and calendar.
  ZonedClock(IClock clock, DateTimeZone zone, CalendarSystem calendar)
      : Clock = clock,
        Zone = zone,
        Calendar = calendar;

  /// Returns the current instant provided by the underlying clock.
  ///
  /// Returns the current instant provided by the underlying clock.
  @override
  Instant GetCurrentInstant() => Clock.GetCurrentInstant();

  /// Returns the current instant provided by the underlying clock, adjusted
  /// to the time zone of this object.
  ///
  /// Returns the current instant provided by the underlying clock, adjusted to the
  /// time zone of this object.
  ZonedDateTime GetCurrentZonedDateTime() => GetCurrentInstant().InZone(Zone, Calendar);

  /// Returns the local date/time of the current instant provided by the underlying clock, adjusted
  /// to the time zone of this object.
  ///
  /// Returns the local date/time of the current instant provided by the underlying clock, adjusted to the
  /// time zone of this object.
  LocalDateTime GetCurrentLocalDateTime() => GetCurrentZonedDateTime().LocalDateTime;

  /// Returns the offset date/time of the current instant provided by the underlying clock, adjusted
  /// to the time zone of this object.
  ///
  /// Returns the offset date/time of the current instant provided by the underlying clock, adjusted to the
  /// time zone of this object.
  OffsetDateTime GetCurrentOffsetDateTime() => GetCurrentZonedDateTime().ToOffsetDateTime();

  /// Returns the local date of the current instant provided by the underlying clock, adjusted
  /// to the time zone of this object.
  ///
  /// Returns the local date of the current instant provided by the underlying clock, adjusted to the
  /// time zone of this object.
  LocalDate GetCurrentDate() => GetCurrentZonedDateTime().Date;

  /// Returns the local time of the current instant provided by the underlying clock, adjusted
  /// to the time zone of this object.
  ///
  /// Returns the local time of the current instant provided by the underlying clock, adjusted to the
  /// time zone of this object.
  LocalTime GetCurrentTimeOfDay() => GetCurrentZonedDateTime().TimeOfDay;
}
