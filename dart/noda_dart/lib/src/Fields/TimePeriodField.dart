// Ported from NodaTime 6e024dde: src/NodaTime/Fields/TimePeriodField.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Duration.dart';
import '../LocalDate.dart';
import '../LocalDateTime.dart';
import '../LocalInstant.dart';
import '../LocalTime.dart';
import '../NodaConstants.dart';
import '../Utility/Checked.dart';
import '../Utility/Int64.dart';
import '../Utility/SystemExceptions.dart';

/// Period field class representing a field with a fixed duration regardless of when it occurs.
///
/// 2014-06-29: Tried optimizing time period calculations by making these static methods accepting
/// the number of ticks. I'd expected that to be really significant, given that it would avoid
/// finding the object etc. It turned out to make about 10% difference, at the cost of quite a bit
/// of code elegance.
@internal
final class TimePeriodField {
  static final TimePeriodField Nanoseconds = TimePeriodField._NewUnitNanoseconds(1);
  static final TimePeriodField Ticks = TimePeriodField._NewUnitNanoseconds(NodaConstants.NanosecondsPerTick);
  static final TimePeriodField Milliseconds = TimePeriodField._NewUnitNanoseconds(NodaConstants.NanosecondsPerMillisecond);
  static final TimePeriodField Seconds = TimePeriodField._NewUnitNanoseconds(NodaConstants.NanosecondsPerSecond);
  static final TimePeriodField Minutes = TimePeriodField._NewUnitNanoseconds(NodaConstants.NanosecondsPerMinute);
  static final TimePeriodField Hours = TimePeriodField._NewUnitNanoseconds(NodaConstants.NanosecondsPerHour);

  final int _unitNanoseconds;
  // The largest number of units (positive or negative) we can multiply unitNanoseconds by without overflowing a long.
  final int _maxLongUnits;
  final int _unitsPerDay;

  TimePeriodField._NewUnitNanoseconds(int unitNanoseconds)
      : _unitNanoseconds = unitNanoseconds,
        _maxLongUnits = Int64.MaxValue ~/ unitNanoseconds,
        _unitsPerDay = NodaConstants.NanosecondsPerDay ~/ unitNanoseconds;

  LocalDateTime Add(LocalDateTime start, int units) {
    int extraDays = 0;
    LocalTime time;
    (time, extraDays) = AddLocalTimeExtraDays(start.TimeOfDay, units, extraDays);
    // Even though PlusDays optimizes for "value == 0", it's still quicker not to call it.
    LocalDate date = extraDays == 0 ? start.Date : start.Date.PlusDays(extraDays);
    return LocalDateTime.NewDateTime(date, time);
  }

  /// (C#: the `Add(LocalTime localTime, long value)` overload.)
  LocalTime AddLocalTime(LocalTime localTime, int value) {
    // unchecked
    // Arithmetic with a LocalTime wraps round, and every unit divides exactly
    // into a day, so we can make sure we add a value which is less than a day.
    if (value >= 0) {
      if (value >= _unitsPerDay) {
        value = value.remainder(_unitsPerDay);
      }
      int nanosToAdd = value * _unitNanoseconds;
      int newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos >= NodaConstants.NanosecondsPerDay) {
        newNanos -= NodaConstants.NanosecondsPerDay;
      }
      return LocalTime.NewNanoseconds(newNanos);
    } else {
      if (value <= -_unitsPerDay) {
        value = value.remainder(_unitsPerDay);
      }
      int nanosToAdd = value * _unitNanoseconds;
      int newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos < 0) {
        newNanos += NodaConstants.NanosecondsPerDay;
      }
      return LocalTime.NewNanoseconds(newNanos);
    }
  }

  /// (C#: the `Add(LocalTime, long, ref int extraDays)` overload; returns the new extraDays too.)
  (LocalTime, int) AddLocalTimeExtraDays(LocalTime localTime, int value, int extraDays) {
    // unchecked
    if (value == 0) {
      return (localTime, extraDays);
    }
    int days = 0;
    // It's possible that there are better ways to do this, but this at least feels simple.
    if (value >= 0) {
      if (value >= _unitsPerDay) {
        int longDays = value ~/ _unitsPerDay;
        // If this overflows, that's fine. (An OverflowException is a reasonable outcome.)
        days = Checked.ToInt32(longDays);
        value = value.remainder(_unitsPerDay);
      }
      int nanosToAdd = value * _unitNanoseconds;
      int newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos >= NodaConstants.NanosecondsPerDay) {
        newNanos -= NodaConstants.NanosecondsPerDay;
        days = Checked.AddInt32(days, 1);
      }
      extraDays = Checked.AddInt32(extraDays, days);
      return (LocalTime.NewNanoseconds(newNanos), extraDays);
    } else {
      if (value <= -_unitsPerDay) {
        int longDays = value ~/ _unitsPerDay;
        // If this overflows, that's fine. (An OverflowException is a reasonable outcome.)
        days = Checked.ToInt32(longDays);
        value = value.remainder(_unitsPerDay);
      }
      int nanosToAdd = value * _unitNanoseconds;
      int newNanos = localTime.NanosecondOfDay + nanosToAdd;
      if (newNanos < 0) {
        newNanos += NodaConstants.NanosecondsPerDay;
        days = Checked.SubtractInt32(days, 1);
      }
      extraDays = Checked.AddInt32(days, extraDays);
      return (LocalTime.NewNanoseconds(newNanos), extraDays);
    }
  }

  int UnitsBetween(LocalDateTime start, LocalDateTime end) {
    LocalInstant startLocalInstant = start.ToLocalInstant();
    LocalInstant endLocalInstant = end.ToLocalInstant();
    Duration duration = endLocalInstant.TimeSinceLocalEpoch - startLocalInstant.TimeSinceLocalEpoch;
    return GetUnitsInDuration(duration);
  }

  /// Returns the number of units in the given duration, rounding towards zero.
  ///
  /// noda_dart: C#'s decimal arithmetic is done with [BigInt].
  int GetUnitsInDuration(Duration duration) => duration.IsInt64Representable
      ? duration.ToInt64Nanoseconds() ~/ _unitNanoseconds
      : _BigIntToInt64(duration.ToBigIntegerNanoseconds() ~/ BigInt.from(_unitNanoseconds));

  /// Returns a [Duration] representing the given number of units.
  ///
  /// noda_dart: C#'s decimal arithmetic is done with [BigInt], overflowing beyond 96 bits as decimal does.
  Duration ToDuration(int units) => units >= -_maxLongUnits && units <= _maxLongUnits
      ? Duration.FromNanoseconds(units * _unitNanoseconds)
      : Duration.FromNanosecondsBigInteger(_CheckDecimalRange(BigInt.from(units) * BigInt.from(_unitNanoseconds)));

  // noda_dart: new code. C#'s checked (long) conversion of a decimal.
  static int _BigIntToInt64(BigInt value) {
    if (value < _Int64MinValue || value > _Int64MaxValue) {
      throw OverflowException('Value was either too large or too small for an Int64.');
    }
    return value.toInt();
  }

  // noda_dart: new code. C#'s decimal range (96 bits).
  static BigInt _CheckDecimalRange(BigInt value) {
    if (value.abs() >= _DecimalLimit) {
      throw OverflowException('Value was either too large or too small for a Decimal.');
    }
    return value;
  }

  static final BigInt _Int64MinValue = BigInt.parse('-9223372036854775808');
  static final BigInt _Int64MaxValue = BigInt.parse('9223372036854775807');
  static final BigInt _DecimalLimit = BigInt.one << 96;
}
