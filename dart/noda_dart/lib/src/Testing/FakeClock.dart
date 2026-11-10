// Ported from NodaTime 6e024dde: src/NodaTime.Testing/FakeClock.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../Duration.dart';
import '../IClock.dart';
import '../Instant.dart';

/// Clock which can be constructed with an initial instant, and then advanced programmatically (and optionally,
/// automatically advanced on each read).
/// This class is designed to be used when testing classes which take an [IClock] as a dependency.
///
/// This class is somewhere between a fake and a stub, depending on how it's used - if it's set to
/// [AutoAdvance] then time will pass, but in a pretty odd way (i.e. dependent on how
/// often it's consulted).
///
/// This type is thread-safe, primarily in order to allow [IClock] to be documented as
/// "thread safe in all built-in implementations".
final class FakeClock implements IClock {
  // Dart: isolates don't share memory (NodaTime's lock object isn't needed).
  Instant _now;
  Duration _autoAdvance;

  /// Creates a fake clock initially set to the given instant. The clock will advance by the given duration on
  /// each read.
  ///
  /// (NodaTime's `FakeClock(Instant initial)`, with no auto-advance, and `FakeClock(Instant initial, Duration
  /// autoAdvance)`, as one constructor: [autoAdvance] defaults to [Duration.Zero].)
  ///
  /// [initial]: The initial instant.
  /// [autoAdvance]: The duration to advance the clock on each read.
  ///
  /// See also [AutoAdvance].
  FakeClock(Instant initial, [Duration? autoAdvance])
      : _now = initial,
        _autoAdvance = autoAdvance ?? Duration.Zero;

  /// Returns a fake clock initially set to the given year/month/day/time in UTC in the ISO calendar.
  /// The value of the [AutoAdvance] property will be initialised to zero.
  ///
  /// (NodaTime's `FromUtc(int year, int monthOfYear, int dayOfMonth)`, at midnight, and `FromUtc(int year, int
  /// monthOfYear, int dayOfMonth, int hourOfDay, int minuteOfHour, int secondOfMinute)`, as one method: the time of
  /// day defaults to midnight.)
  ///
  /// [year]: The year. This is the "absolute year",
  /// so a value of 0 means 1 BC, for example.
  /// [monthOfYear]: The month of year.
  /// [dayOfMonth]: The day of month.
  /// [hourOfDay]: The hour.
  /// [minuteOfHour]: The minute.
  /// [secondOfMinute]: The second.
  ///
  /// Returns a [FakeClock] initialised to the given instant, with no auto-advance.
  static FakeClock FromUtc(int year, int monthOfYear, int dayOfMonth,
      [int hourOfDay = 0, int minuteOfHour = 0, int secondOfMinute = 0]) {
    return FakeClock(Instant.FromUtc(year, monthOfYear, dayOfMonth, hourOfDay, minuteOfHour, secondOfMinute));
  }

  /// Advances the clock by the given duration.
  ///
  /// [duration]: The duration to advance the clock by (or if negative, the duration to move it back
  /// by).
  void Advance(Duration duration) {
    // Dart: isolates don't share memory (lock (mutex)).
    _now += duration;
  }

  /// Advances the clock by the given number of nanoseconds.
  ///
  /// [nanoseconds]: The number of nanoseconds to advance the clock by (or if negative, the number to move it back
  /// by).
  void AdvanceNanoseconds(int nanoseconds) => Advance(Duration.FromNanoseconds(nanoseconds));

  /// Advances the clock by the given number of ticks.
  ///
  /// [ticks]: The number of ticks to advance the clock by (or if negative, the number to move it back
  /// by).
  void AdvanceTicks(int ticks) => Advance(Duration.FromTicks(ticks));

  /// Advances the clock by the given number of milliseconds.
  ///
  /// [milliseconds]: The number of milliseconds to advance the clock by (or if negative, the number
  /// to move it back by).
  void AdvanceMilliseconds(int milliseconds) => Advance(Duration.FromMilliseconds(milliseconds));

  /// Advances the clock by the given number of seconds.
  ///
  /// [seconds]: The number of seconds to advance the clock by (or if negative, the number to move it
  /// back by).
  void AdvanceSeconds(int seconds) => Advance(Duration.FromSeconds(seconds));

  /// Advances the clock by the given number of minutes.
  ///
  /// [minutes]: The number of minutes to advance the clock by (or if negative, the number to move it
  /// back by).
  void AdvanceMinutes(int minutes) => Advance(Duration.FromMinutes(minutes));

  /// Advances the clock by the given number of hours.
  ///
  /// [hours]: The number of hours to advance the clock by (or if negative, the number to move it
  /// back by).
  void AdvanceHours(int hours) => Advance(Duration.FromHours(hours));

  /// Advances the clock by the given number of standard (24-hour) days.
  ///
  /// [days]: The number of days to advance the clock by (or if negative, the number to move it
  /// back by).
  void AdvanceDays(int days) => Advance(Duration.FromDays(days));

  /// Resets the clock to the given instant.
  /// The value of the [AutoAdvance] property will be unchanged.
  ///
  /// [instant]: The instant to set the clock to.
  void Reset(Instant instant) {
    // Dart: isolates don't share memory (lock (mutex)).
    _now = instant;
  }

  /// Returns the "current time" for this clock. Unlike a normal clock, this
  /// property may return the same value from repeated calls until one of the methods
  /// to change the time is called.
  ///
  /// If the value of the [AutoAdvance] property is non-zero, then every
  /// call to this method will advance the current time by that value.
  ///
  /// Returns the "current time" from this (fake) clock.
  @override
  Instant GetCurrentInstant() {
    // Dart: isolates don't share memory (lock (mutex)).
    final then = _now;
    _now += _autoAdvance;
    return then;
  }

  /// Gets the amount of time to advance the clock by on each call to read the current time.
  ///
  /// This defaults to zero, with the exception of the [FakeClock.new] constructor with an `autoAdvance` argument,
  /// which takes the initial value directly.  If this is zero, the current time as reported by this clock will
  /// not change other than by calls to [Reset] or to one of the [Advance] methods.
  ///
  /// The value could even be negative, to simulate particularly odd system clock effects.
  ///
  /// See also [GetCurrentInstant].
  ///
  /// The amount of time to advance the clock by on each call to read the current time.
  // (A property with a backing field, as in NodaTime, whose accessors lock.)
  // ignore: unnecessary_getters_setters
  Duration get AutoAdvance => _autoAdvance;

  set AutoAdvance(Duration value) {
    _autoAdvance = value;
  }
}
