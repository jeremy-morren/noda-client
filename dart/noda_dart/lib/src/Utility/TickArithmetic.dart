// Ported from NodaTime 6e024dde: src/NodaTime/Utility/TickArithmetic.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../NodaConstants.dart';
import 'Checked.dart';
import 'Preconditions.dart';

/// `(int) (long.MinValue / TicksPerDay)`.
const int _MinDaysForLongTicks = -10675199;

/// `(int) (long.MaxValue / TicksPerDay)`.
const int _MaxDaysForLongTicks = 10675199;

/// Common operations on ticks.
@internal
abstract final class TickArithmetic {
  /// Cautiously converts a number of ticks (which can have any value) into a number of
  /// days and a tick within that day.
  ///
  /// Used by [Duration.FromTicks].
  ///
  /// Returns the number of days, and the tick within that day (C#'s `out long tickOfDay`).
  static (int days, int tickOfDay) TicksToDaysAndTickOfDay(int ticks) {
    // unchecked
    // First work out the number of days, always rounding down (so that ticks * TicksPerDay is always the
    // start of the day).
    // The shift approach here is equivalent to dividing by NodaConstants.TicksPerDay, but appears to be
    // very significantly faster under the x64 JIT (and no slower under the x86 JIT).
    // See https://stackoverflow.com/questions/22258070 for the inspiration.
    // (noda_dart: divides by TicksPerDay directly, as the web's bit operations are 32-bit.)
    if (ticks >= 0) {
      int days = ticks ~/ NodaConstants.TicksPerDay;
      int tickOfDay = ticks - days * NodaConstants.TicksPerDay;
      return (days, tickOfDay);
    } else {
      // Note: while this *could* be optimized with shifting at some point, it's probably not worth it.
      // Note that this must *not* subtract from ticks, as it could already be long.MinValue.
      int days = (ticks + 1) ~/ NodaConstants.TicksPerDay - 1;
      // We need to be careful as ticks might be close to long.MinValue, at which point
      // days * TicksPerDay would overflow. We could validate that, but it only
      // saves two additions, and introduces a branch.
      int tickOfDay = ticks - (days + 1) * NodaConstants.TicksPerDay + NodaConstants.TicksPerDay;
      // noda_dart: on dart2js beyond ±2^53, ticks + 1 can round back to ticks; normalize.
      if (tickOfDay == NodaConstants.TicksPerDay) {
        days++;
        tickOfDay = 0;
      }
      return (days, tickOfDay);
    }
  }

  /// Similar to [TicksToDaysAndTickOfDay] but
  /// trusting that the input is non-negative, which can be proved in certain cases.
  ///
  /// Used by [LocalDateTime.FromDateTime].
  ///
  /// Returns the number of days, and the tick within that day (C#'s `out long tickOfDay`).
  static (int days, int tickOfDay) NonNegativeTicksToDaysAndTickOfDay(int ticks) {
    // unchecked
    Preconditions.DebugCheckArgument(ticks >= 0, 'ticks', 'Ticks must be non-negative');
    // (noda_dart: C#'s (ticks >> 14) / 52734375L; see TicksToDaysAndTickOfDay.)
    int days = ticks ~/ NodaConstants.TicksPerDay;
    int tickOfDay = ticks - days * NodaConstants.TicksPerDay;
    return (days, tickOfDay);
  }

  /// Cautiously computes a number of ticks from day/tick-of-day value. This may overflow,
  /// but will only do so if it has to.
  ///
  /// Throws [OverflowException] if the result is outside the range of a C# `long`.
  static int DaysAndTickOfDayToTicks(int days, int tickOfDay) => days >= _MinDaysForLongTicks
      ? Checked.Add(Checked.Multiply(days, NodaConstants.TicksPerDay), tickOfDay)
      : Checked.Subtract(
          Checked.Add(Checked.Multiply(days + 1, NodaConstants.TicksPerDay), tickOfDay), NodaConstants.TicksPerDay);

  /// Computes a number of ticks from a day/tick-of-day value which is trusted not to overflow,
  /// even when computed in the simplest way. Only call this method from places where there
  /// are suitable constraints on the input.
  static int BoundedDaysAndTickOfDayToTicks(int days, int tickOfDay) {
    Preconditions.DebugCheckArgumentRange('days', days, _MinDaysForLongTicks, _MaxDaysForLongTicks);
    // unchecked
    return days * NodaConstants.TicksPerDay + tickOfDay;
  }
}
