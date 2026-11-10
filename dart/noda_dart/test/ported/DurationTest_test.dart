// Ported from NodaTime 6e024dde: src/NodaTime.Test/DurationTest.cs (+ DurationTest.Construction.cs, DurationTest.Operators.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: TimeSpan is core.Duration (microseconds); BigInteger, Int128 and decimal are BigInt.

import 'dart:core' as core;
import 'dart:core' hide Duration;
import 'dart:typed_data';

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/DurationTest.generated.dart' as scenarios;

// #region DurationTest.Construction.cs (fields)

// Test cases for factory methods. In general, we want to check the limits, very small, very large
// and medium values, with a mixture of positive and negative, "on and off" day boundaries.

final List<int> DayCases = [
  Duration.MinDays, -3000 * 365, -100, -1, 0, 1, 100, 3000 * 365, Duration.MaxDays
];

final List<int> HourCases = [
  Duration.MinDays * NodaConstants.HoursPerDay, -3000 * 365 * NodaConstants.HoursPerDay, -100, -48, -1, 0,
  1, 48, 100, 3000 * 365 * NodaConstants.HoursPerDay, ((Duration.MaxDays + 1) * NodaConstants.HoursPerDay) - 1
];

final List<int> MinuteCases = GenerateCases(NodaConstants.MinutesPerDay);

final List<int> SecondCases = GenerateCases(NodaConstants.SecondsPerDay);

final List<int> MillisecondCases = GenerateCases(NodaConstants.MillisecondsPerDay);

// Not ported: TickCases (the scenarios supply FromTicks's cases).

List<int> GenerateCases(int unitsPerDay) => [
      Duration.MinDays * unitsPerDay,
      -3000 * 365 * unitsPerDay - 1,
      -3000 * 365 * unitsPerDay,
      -5 * unitsPerDay ~/ 2,
      -2 * unitsPerDay
      -1,
      0,
      1,
      2 * unitsPerDay,
      5 * unitsPerDay ~/ 2,
      3000 * 365 * unitsPerDay,
      3000 * 365 * unitsPerDay + 1,
      ((Duration.MaxDays + 1) * unitsPerDay) - 1,
    ];

// noda_dart: both C# overloads (Func<long, Duration> and Func<int, Duration>).
void TestFactoryMethod(Duration Function(int) method, int value, int nanosecondsPerUnit) {
  Duration duration = method(value);
  BigInt expectedNanoseconds = BigInt.from(value) * BigInt.from(nanosecondsPerUnit);
  Assert.AreEqual(duration.ToBigIntegerNanoseconds(), expectedNanoseconds);
}
// #endregion

// #region DurationTest.Operators.cs (fields)
final Duration threeMillion = Duration.FromNanoseconds(3000000);
final Duration negativeFiftyMillion = Duration.FromNanoseconds(-50000000);
// #endregion

void main() {
  port(scenarios.fixture, {
    // #region DurationTest.Construction.cs
    'Zero': (args) {
      Duration test = Duration.Zero;
      Assert.AreEqual(0, test.BclCompatibleTicks);
      Assert.AreEqual(0, test.NanosecondOfFloorDay);
      Assert.AreEqual(0, test.FloorDays);
    },

    'FromDays_Int32': (args) {
      final [int days] = args;
      TestFactoryMethod(Duration.FromDays, days, NodaConstants.NanosecondsPerDay);
    },

    'FromHours_Int32': (args) {
      final [int hours] = args;
      TestFactoryMethod(Duration.FromHours, hours, NodaConstants.NanosecondsPerHour);
    },

    'FromMinutes_Int64': (args) {
      final [int minutes] = args;
      TestFactoryMethod(Duration.FromMinutes, minutes, NodaConstants.NanosecondsPerMinute);
    },

    'FromSeconds_Int64': (args) {
      final [int seconds] = args;
      TestFactoryMethod(Duration.FromSeconds, seconds, NodaConstants.NanosecondsPerSecond);
    },

    'FromMilliseconds_Int64': (args) {
      final [int milliseconds] = args;
      TestFactoryMethod(Duration.FromMilliseconds, milliseconds, NodaConstants.NanosecondsPerMillisecond);
    },

    'FromTicks': (args) {
      final [int ticks] = args;
      var nanoseconds = Duration.FromTicks(ticks);
      Assert.AreEqual(BigInt.from(ticks) * BigInt.from(NodaConstants.NanosecondsPerTick), nanoseconds.ToBigIntegerNanoseconds());

      // Just another sanity check, although Ticks is covered in more detail later.
      Assert.AreEqual(ticks, nanoseconds.BclCompatibleTicks);
    },

    'FromDays_Double': (args) {
      final [double days, int expectedDays, int expectedNanoOfDay] = args;
      var actual = Duration.FromDaysDouble(days);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, actual);
    },

    'FromHours_Double': (args) {
      final [double hours, int expectedDays, int expectedNanoOfDay] = args;
      var actual = Duration.FromHoursDouble(hours);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, actual);
    },

    'FromMinutes_Double': (args) {
      final [double minutes, int expectedDays, int expectedNanoOfDay] = args;
      var actual = Duration.FromMinutesDouble(minutes);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, actual);
    },

    'FromSeconds_Double': (args) {
      final [double seconds, int expectedDays, int expectedNanoOfDay] = args;
      var actual = Duration.FromSecondsDouble(seconds);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, actual);
    },

    'FromMilliseconds_Double': (args) {
      final [double milliseconds, int expectedDays, int expectedNanoOfDay] = args;
      var actual = Duration.FromMillisecondsDouble(milliseconds);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, actual);
    },

        // noda_dart: core.Duration counts microseconds, so a tick here is a microsecond.
    'FromAndToTimeSpan': (args) {
      core.Duration timeSpan = core.Duration(hours: 3) + core.Duration(seconds: 2) + core.Duration(microseconds: 1);
      Duration duration = Duration.FromHours(3) + Duration.FromSeconds(2) + Duration.FromTicks(10);
      Assert.AreEqual(duration, Duration.FromCoreDuration(timeSpan));
      Assert.AreEqual(timeSpan, duration.ToCoreDuration());

      // noda_dart: Int64.MaxValue / MinValue ticks aren't exact on dart2js (an int is a JavaScript number there).
      if (!Int64.IsExact) {
        return;
      }
      Duration maxDuration = Duration.FromTicks(Int64.MaxValue ~/ 10 * 10);
      core.Duration timeSpanMaxValue = core.Duration(microseconds: Int64.MaxValue ~/ 10);
      Assert.AreEqual(maxDuration, Duration.FromCoreDuration(timeSpanMaxValue));
      Assert.AreEqual(timeSpanMaxValue, maxDuration.ToCoreDuration());
      Duration minDuration = Duration.FromTicks(Int64.MinValue ~/ 10 * 10);
      core.Duration timeSpanMinValue = core.Duration(microseconds: Int64.MinValue ~/ 10);

      Assert.AreEqual(minDuration, Duration.FromCoreDuration(timeSpanMinValue));
      Assert.AreEqual(timeSpanMinValue, minDuration.ToCoreDuration());
    },

    'FromNanoseconds_Int64': (args) {
      Assert.AreEqual(Duration.OneDay - Duration.Epsilon, Duration.FromNanoseconds(NodaConstants.NanosecondsPerDay - 1));
      Assert.AreEqual(Duration.OneDay, Duration.FromNanoseconds(NodaConstants.NanosecondsPerDay));
      Assert.AreEqual(Duration.OneDay + Duration.Epsilon, Duration.FromNanoseconds(NodaConstants.NanosecondsPerDay + 1));

      Assert.AreEqual(-Duration.OneDay - Duration.Epsilon, Duration.FromNanoseconds(-NodaConstants.NanosecondsPerDay - 1));
      Assert.AreEqual(-Duration.OneDay, Duration.FromNanoseconds(-NodaConstants.NanosecondsPerDay));
      Assert.AreEqual(-Duration.OneDay + Duration.Epsilon, Duration.FromNanoseconds(-NodaConstants.NanosecondsPerDay + 1));
    },

    // noda_dart: FromNanoseconds(decimal) is FromDecimalNanoseconds(BigInt) (an integral decimal).
    'FromNanosecondsDecimal_Limits': (args) {
      Assert.AreEqual(Duration.MinValue, Duration.FromDecimalNanoseconds(Duration.MinDecimalNanoseconds));
      Assert.AreEqual(Duration.MaxValue, Duration.FromDecimalNanoseconds(Duration.MaxDecimalNanoseconds));
      Assert.Throws<RangeError>(() => Duration.FromDecimalNanoseconds(Duration.MinDecimalNanoseconds - BigInt.one));
      Assert.Throws<RangeError>(() => Duration.FromDecimalNanoseconds(Duration.MaxDecimalNanoseconds + BigInt.one));
    },

    'FromNanoseconds_BigInteger': (args) {
      final nanosecondsPerDay = BigInt.from(NodaConstants.NanosecondsPerDay);
      Assert.AreEqual(Duration.OneDay - Duration.Epsilon, Duration.FromNanosecondsBigInteger(nanosecondsPerDay - BigInt.one));
      Assert.AreEqual(Duration.OneDay, Duration.FromNanosecondsBigInteger(nanosecondsPerDay + BigInt.zero));
      Assert.AreEqual(Duration.OneDay + Duration.Epsilon, Duration.FromNanosecondsBigInteger(nanosecondsPerDay + BigInt.one));

      Assert.AreEqual(-Duration.OneDay - Duration.Epsilon, Duration.FromNanosecondsBigInteger(-nanosecondsPerDay - BigInt.one));
      Assert.AreEqual(-Duration.OneDay, Duration.FromNanosecondsBigInteger(-nanosecondsPerDay + BigInt.zero));
      Assert.AreEqual(-Duration.OneDay + Duration.Epsilon, Duration.FromNanosecondsBigInteger(-nanosecondsPerDay + BigInt.one));
    },

    // noda_dart: Dart has no Int128; FromNanoseconds(Int128) is FromNanosecondsBigInteger.
    'FromNanoseconds_Int128': (args) {
      final nanosecondsPerDay = BigInt.from(NodaConstants.NanosecondsPerDay);
      Assert.AreEqual(Duration.OneDay - Duration.Epsilon, Duration.FromNanosecondsBigInteger(nanosecondsPerDay - BigInt.one));
      Assert.AreEqual(Duration.OneDay, Duration.FromNanosecondsBigInteger(nanosecondsPerDay + BigInt.zero));
      Assert.AreEqual(Duration.OneDay + Duration.Epsilon, Duration.FromNanosecondsBigInteger(nanosecondsPerDay + BigInt.one));

      Assert.AreEqual(-Duration.OneDay - Duration.Epsilon, Duration.FromNanosecondsBigInteger(-nanosecondsPerDay - BigInt.one));
      Assert.AreEqual(-Duration.OneDay, Duration.FromNanosecondsBigInteger(-nanosecondsPerDay + BigInt.zero));
      Assert.AreEqual(-Duration.OneDay + Duration.Epsilon, Duration.FromNanosecondsBigInteger(-nanosecondsPerDay + BigInt.one));
    },

    'FromNanoseconds_Double': (args) {
      Assert.AreEqual(Duration.OneDay - Duration.Epsilon, Duration.FromNanosecondsDouble(NodaConstants.NanosecondsPerDay - 1.0));
      Assert.AreEqual(Duration.OneDay, Duration.FromNanosecondsDouble(NodaConstants.NanosecondsPerDay + 0.0));
      Assert.AreEqual(Duration.OneDay + Duration.Epsilon, Duration.FromNanosecondsDouble(NodaConstants.NanosecondsPerDay + 1.0));

      Assert.AreEqual(-Duration.OneDay - Duration.Epsilon, Duration.FromNanosecondsDouble(-NodaConstants.NanosecondsPerDay - 1.0));
      Assert.AreEqual(-Duration.OneDay, Duration.FromNanosecondsDouble(-NodaConstants.NanosecondsPerDay + 0.0));
      Assert.AreEqual(-Duration.OneDay + Duration.Epsilon, Duration.FromNanosecondsDouble(-NodaConstants.NanosecondsPerDay + 1.0));

      // Checks for values outside the range of long...
      // Find a value which is pretty big, but will definitely still convert back to a positive long.
      double largeDoubleValue = ((Int64.MaxValue ~/ 16) * 15).toDouble();
      int largeInt64Value = largeDoubleValue.toInt(); // This won't be exactly long.MaxValue
      Assert.AreEqual(Duration.FromNanoseconds(largeInt64Value) * 8, Duration.FromNanosecondsDouble(largeDoubleValue * 8.0));
    },

    'FromNanoseconds_DoubleBeyondInt64': (args) {
      // 18446744073_709551616
      double largeDouble = Int64.MaxValue * 2.0;

      var seconds = Duration.FromSeconds(18446744073);
      var nanos = Duration.FromNanoseconds(709551616);
      Assert.AreEqual(seconds + nanos, Duration.FromNanosecondsDouble(largeDouble));
      Assert.AreEqual(-seconds - nanos, Duration.FromNanosecondsDouble(-largeDouble));
    },

    'FactoryMethods_OutOfRange': (args) {
      void AssertOutOfRange<T>(Duration Function(T) factoryMethod, List<T> values) {
        for (var value in values) {
          Assert.Throws<RangeError>(() => factoryMethod(value));
        }
      }

      // noda_dart: both C# local functions (AssertLimitsInt32 and AssertLimitsInt64): Dart has one int.
      void AssertLimits(Duration Function(int) factoryMethod, List<int> allCases) =>
          AssertOutOfRange(factoryMethod, [allCases.first - 1, allCases.last + 1]);

      // Use the bitwise pattern of a double to ensure we get a different value.
      // (noda_dart: as two 32-bit halves, which dart2js supports, for a small positive change.)
      double NextDouble(double start, int change) {
        final data = ByteData(8)..setFloat64(0, start, Endian.little);
        final low = data.getUint32(0, Endian.little) + change;
        data.setUint32(0, low % 0x100000000, Endian.little);
        data.setUint32(4, data.getUint32(4, Endian.little) + low ~/ 0x100000000, Endian.little);
        return data.getFloat64(0, Endian.little);
      }

      // Each set of cases starts with the minimum and ends with the maximum, so we can test just beyond the limits easily.
      AssertLimits(Duration.FromDays, DayCases);
      AssertLimits(Duration.FromHours, HourCases);
      AssertLimits(Duration.FromMinutes, MinuteCases);
      AssertLimits(Duration.FromSeconds, SecondCases);
      AssertLimits(Duration.FromMilliseconds, MillisecondCases);
      // FromTicks(long) never throws.

      List<double> bigBadDoubles = [double.negativeInfinity, -double.maxFinite, double.maxFinite, double.infinity, double.nan];
      AssertOutOfRange(Duration.FromDaysDouble, bigBadDoubles);
      AssertOutOfRange(Duration.FromHoursDouble, bigBadDoubles);
      AssertOutOfRange(Duration.FromMinutesDouble, bigBadDoubles);
      AssertOutOfRange(Duration.FromSecondsDouble, bigBadDoubles);
      AssertOutOfRange(Duration.FromMillisecondsDouble, bigBadDoubles);
      AssertOutOfRange(Duration.FromTicksDouble, bigBadDoubles);
      AssertOutOfRange(Duration.FromNanosecondsDouble, bigBadDoubles);
      AssertOutOfRange(Duration.FromNanosecondsDouble, [
        // You might have expected -1L here, but the layout of double means
        // this really is the next value *lower* than MinNanoseconds.
        NextDouble(Duration.MinNanoseconds.toDouble(), 1),
        NextDouble(Duration.MaxNanoseconds.toDouble(), 1)
      ]);

      // No such concept as BigInteger.Min/MaxValue, so use the values we know to be just outside valid bounds.
      AssertOutOfRange(Duration.FromNanosecondsBigInteger, [Duration.MinNanoseconds - BigInt.one, Duration.MaxNanoseconds + BigInt.one]);

      // noda_dart: the Int128 checks, with BigInt (Dart has no Int128).
      AssertOutOfRange(Duration.FromNanosecondsBigInteger, [Duration.MinNanoseconds - BigInt.one, Duration.MaxNanoseconds + BigInt.one]);
      AssertOutOfRange(Duration.FromNanosecondsBigInteger, [-(BigInt.one << 127), (BigInt.one << 127) - BigInt.one]);
    },
    // #endregion

    // #region DurationTest.cs
    // Tests copied from Nanoseconds in its brief existence... there may well be some overlap between
    // this and older Duration tests.

    'Int64Conversions': (args) {
      final [int int64Nanos] = args;
      var nanoseconds = Duration.FromNanoseconds(int64Nanos);
      Assert.AreEqual(int64Nanos, nanoseconds.ToInt64Nanoseconds());
    },

    'BigIntegerConversions': (args) {
      final [int int64Nanos] = args;
      BigInt bigIntegerNanos = BigInt.from(int64Nanos);
      var nanoseconds = Duration.FromNanosecondsBigInteger(bigIntegerNanos);
      Assert.AreEqual(bigIntegerNanos, nanoseconds.ToBigIntegerNanoseconds());

      // And multiply it by 100, which proves we still work for values out of the range of Int64
      bigIntegerNanos *= BigInt.from(100);
      nanoseconds = Duration.FromNanosecondsBigInteger(bigIntegerNanos);
      Assert.AreEqual(bigIntegerNanos, nanoseconds.ToBigIntegerNanoseconds());
    },

    // noda_dart: Int128 is BigInt (FromNanosecondsBigInteger, ToBigIntegerNanoseconds).
    'Int128Conversions': (args) {
      final [int int64Nanos] = args;
      BigInt int128Nanos = BigInt.from(int64Nanos);
      var nanoseconds = Duration.FromNanosecondsBigInteger(int128Nanos);
      Assert.AreEqual(int128Nanos, nanoseconds.ToBigIntegerNanoseconds());

      // And multiply it by 100, which proves we still work for values out of the range of Int64
      int128Nanos *= BigInt.from(100);
      nanoseconds = Duration.FromNanosecondsBigInteger(int128Nanos);
      Assert.AreEqual(int128Nanos, nanoseconds.ToBigIntegerNanoseconds());
    },

    'ConstituentParts_Positive': (args) {
      var nanos = Duration.FromNanoseconds(NodaConstants.NanosecondsPerDay * 5 + 100);
      Assert.AreEqual(5, nanos.FloorDays);
      Assert.AreEqual(100, nanos.NanosecondOfFloorDay);
    },

    'ConstituentParts_Negative': (args) {
      var nanos = Duration.FromNanoseconds(NodaConstants.NanosecondsPerDay * -5 + 100);
      Assert.AreEqual(-5, nanos.FloorDays);
      Assert.AreEqual(100, nanos.NanosecondOfFloorDay);
    },

    'ConstituentParts_Large': (args) {
      // And outside the normal range of long...
      var nanos = Duration.FromNanosecondsBigInteger(BigInt.from(NodaConstants.NanosecondsPerDay) * BigInt.from(365000) + BigInt.from(500));
      Assert.AreEqual(365000, nanos.FloorDays);
      Assert.AreEqual(500, nanos.NanosecondOfFloorDay);
    },

    'Addition_Subtraction': (args) {
      final [int leftDays, int leftNanos, int rightDays, int rightNanos, int resultDays, int resultNanos] = args;
      var left = Duration.NewDaysNanoOfDay(leftDays, leftNanos);
      var right = Duration.NewDaysNanoOfDay(rightDays, rightNanos);
      var result = Duration.NewDaysNanoOfDay(resultDays, resultNanos);

      Assert.AreEqual(result, left + right);
      Assert.AreEqual(result, left.Plus(right));
      Assert.AreEqual(result, Duration.Add(left, right));

      Assert.AreEqual(left, result - right);
      Assert.AreEqual(left, result.Minus(right));
      Assert.AreEqual(left, Duration.Subtract(result, right));
    },

    'Equality': (args) {
      var equal1 = Duration.NewDaysNanoOfDay(1, NodaConstants.NanosecondsPerHour);
      var equal2 = Duration.FromTicks(NodaConstants.TicksPerHour * 25);
      var different1 = Duration.NewDaysNanoOfDay(1, 200);
      var different2 = Duration.NewDaysNanoOfDay(2, NodaConstants.TicksPerHour);

      TestHelper.TestEqualsStruct(equal1, equal2, [different1]);
      TestHelper.TestOperatorEquality(equal1, equal2, different1);

      TestHelper.TestEqualsStruct(equal1, equal2, [different2]);
      TestHelper.TestOperatorEquality(equal1, equal2, different2);
    },

    'Comparison': (args) {
      var equal1 = Duration.NewDaysNanoOfDay(1, NodaConstants.NanosecondsPerHour);
      var equal2 = Duration.FromTicks(NodaConstants.TicksPerHour * 25);
      var greater1 = Duration.NewDaysNanoOfDay(1, NodaConstants.NanosecondsPerHour + 1);
      var greater2 = Duration.NewDaysNanoOfDay(2, 0);

      TestHelper.TestCompareToStruct(equal1, equal2, [greater1]);
      TestHelper.TestNonGenericCompareTo(equal1, equal2, [greater1]);
      TestHelper.TestOperatorComparisonEquality(equal1, equal2, [greater1, greater2]);
    },

    'Multiplication': (args) {
      final [int startDays, int startNanoOfDay, int scalar, int expectedDays, int expectedNanoOfDay] = args;
      var start = Duration.NewDaysNanoOfDay(startDays, startNanoOfDay);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, start * scalar);
    },

    'UnaryNegation': (args) {
      final [int startDays, int startNanoOfDay, int expectedDays, int expectedNanoOfDay] = args;
      var start = Duration.NewDaysNanoOfDay(startDays, startNanoOfDay);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, -start);
      // Test it the other way round as well...
      Assert.AreEqual(start, -expected);
    },

    'Division': (args) {
      final [int startDays, int startNanoOfDay, int divisor, int expectedDays, int expectedNanoOfDay] = args;
      var start = Duration.NewDaysNanoOfDay(startDays, startNanoOfDay);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, start / divisor);
    },

    'BclCompatibleTick_Zero': (args) {
      Assert.AreEqual(0, Duration.FromTicks(0).BclCompatibleTicks);
      Assert.AreEqual(0, Duration.FromNanoseconds(99).BclCompatibleTicks);
      Assert.AreEqual(0, Duration.FromNanoseconds(-99).BclCompatibleTicks);
    },

    'BclCompatibleTick_Positive': (args) {
      final [int ticks] = args;
      Assert.IsTrue(ticks > 0);
      Duration start = Duration.FromTicks(ticks);
      Assert.AreEqual(ticks, start.BclCompatibleTicks);

      // We truncate towards zero... so subtracting 1 nanosecond should
      // reduce the number of ticks, and adding 99 nanoseconds should not change it
      Assert.AreEqual(ticks - 1, start.MinusSmallNanoseconds(1).BclCompatibleTicks);
      Assert.AreEqual(ticks, start.PlusSmallNanoseconds(99).BclCompatibleTicks);
    },

    'BclCompatibleTicks_Negative': (args) {
      final [int ticks] = args;
      Assert.IsTrue(ticks < 0);
      Duration start = Duration.FromTicks(ticks);
      Assert.AreEqual(ticks, start.BclCompatibleTicks);

      // We truncate towards zero... so subtracting 99 nanoseconds should
      // have no effect, and adding 1 should increase the number of ticks
      Assert.AreEqual(ticks, start.MinusSmallNanoseconds(99).BclCompatibleTicks);
      Assert.AreEqual(ticks + 1, start.PlusSmallNanoseconds(1).BclCompatibleTicks);
    },

    'BclCompatibleTicks_MinValue': (args) {
      Assert.Throws<OverflowException>(() => Duration.MinValue.BclCompatibleTicks.toString());
    },

    'Validation': (args) {
      TestHelper.AssertValid(Duration.FromDays, (1 << 24) - 1);
      TestHelper.AssertOutOfRange(Duration.FromDays, 1 << 24);
      TestHelper.AssertValid(Duration.FromDays, -(1 << 24));
      TestHelper.AssertOutOfRange(Duration.FromDays, -(1 << 24) - 1);
    },

    'BclCompatibleTicks_Overflow': (args) {
      Duration maxTicks = Duration.FromTicks(Int64.MaxValue) + Duration.FromTicks(1);
      Assert.Throws<OverflowException>(() => maxTicks.BclCompatibleTicks.toString());
    },

    'PositiveComponents': (args) {
      // Worked out with a calculator :)
      Duration duration = Duration.FromNanoseconds(1234567890123456);
      Assert.AreEqual(14, duration.Days);
      Assert.AreEqual(24967890123456, duration.NanosecondOfDay);
      Assert.AreEqual(6, duration.Hours);
      Assert.AreEqual(56, duration.Minutes);
      Assert.AreEqual(7, duration.Seconds);
      Assert.AreEqual(890, duration.Milliseconds);
      Assert.AreEqual(8901234, duration.SubsecondTicks);
      Assert.AreEqual(890123456, duration.SubsecondNanoseconds);
    },

    'NegativeComponents': (args) {
      // Worked out with a calculator :)
      Duration duration = Duration.FromNanoseconds(-1234567890123456);
      Assert.AreEqual(-14, duration.Days);
      Assert.AreEqual(-24967890123456, duration.NanosecondOfDay);
      Assert.AreEqual(-6, duration.Hours);
      Assert.AreEqual(-56, duration.Minutes);
      Assert.AreEqual(-7, duration.Seconds);
      Assert.AreEqual(-890, duration.Milliseconds);
      Assert.AreEqual(-8901234, duration.SubsecondTicks);
      Assert.AreEqual(-890123456, duration.SubsecondNanoseconds);
    },

    'PositiveTotals': (args) {
      Duration duration = Duration.FromDays(4) + Duration.FromHours(3) + Duration.FromMinutes(2) + Duration.FromSeconds(1)
          + Duration.FromNanoseconds(123456789);
      Assert.AreEqual(4.1264, duration.TotalDays, 0.0001);
      Assert.AreEqual(99.0336, duration.TotalHours, 0.0001);
      Assert.AreEqual(5942.0187, duration.TotalMinutes, 0.0001);
      Assert.AreEqual(356521.123456789, duration.TotalSeconds, 0.000000001);
      Assert.AreEqual(356521123.456789, duration.TotalMilliseconds, 0.000001);
      Assert.AreEqual(3565211234567.89, duration.TotalTicks, 0.01);
      Assert.AreEqual(356521123456789.0, duration.TotalNanoseconds, 1);
    },

    'NegativeTotals': (args) {
      Duration duration = Duration.FromDays(-4) + Duration.FromHours(-3) + Duration.FromMinutes(-2) + Duration.FromSeconds(-1)
          + Duration.FromNanoseconds(-123456789);
      Assert.AreEqual(-4.1264, duration.TotalDays, 0.0001);
      Assert.AreEqual(-99.0336, duration.TotalHours, 0.0001);
      Assert.AreEqual(-5942.0187, duration.TotalMinutes, 0.0001);
      Assert.AreEqual(-356521.123456789, duration.TotalSeconds, 0.000000001);
      Assert.AreEqual(-356521123.456789, duration.TotalMilliseconds, 0.000001);
      Assert.AreEqual(-356521123456789.0, duration.TotalNanoseconds, 1);
    },

    'MaxMinRelationship': (args) {
      // Max and Min work like they do for other signed types - basically the max value is one less than the absolute
      // of the min value.
      Assert.AreEqual(Duration.MinValue, -Duration.MaxValue - Duration.Epsilon);
    },

    'Max': (args) {
      Duration x = Duration.FromNanoseconds(100);
      Duration y = Duration.FromNanoseconds(200);
      Assert.AreEqual(y, Duration.Max(x, y));
      Assert.AreEqual(y, Duration.Max(y, x));
      Assert.AreEqual(x, Duration.Max(x, Duration.MinValue));
      Assert.AreEqual(x, Duration.Max(Duration.MinValue, x));
      Assert.AreEqual(Duration.MaxValue, Duration.Max(Duration.MaxValue, x));
      Assert.AreEqual(Duration.MaxValue, Duration.Max(x, Duration.MaxValue));
    },

    'Min': (args) {
      Duration x = Duration.FromNanoseconds(100);
      Duration y = Duration.FromNanoseconds(200);
      Assert.AreEqual(x, Duration.Min(x, y));
      Assert.AreEqual(x, Duration.Min(y, x));
      Assert.AreEqual(Duration.MinValue, Duration.Min(x, Duration.MinValue));
      Assert.AreEqual(Duration.MinValue, Duration.Min(Duration.MinValue, x));
      Assert.AreEqual(x, Duration.Min(Duration.MaxValue, x));
      Assert.AreEqual(x, Duration.Min(x, Duration.MaxValue));
    },
    // #endregion

    // #region DurationTest.Operators.cs
    // #region operator +
    'OperatorPlus_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(0, (Duration.Zero + Duration.Zero).ToInt64Nanoseconds(), '0 + 0');
      Assert.AreEqual(1, (Duration.Epsilon + Duration.Zero).ToInt64Nanoseconds(), '1 + 0');
      Assert.AreEqual(1, (Duration.Zero + Duration.Epsilon).ToInt64Nanoseconds(), '0 + 1');
    },

    'OperatorPlus_NonZero': (args) {
      Assert.AreEqual(3000001, (threeMillion + Duration.Epsilon).ToInt64Nanoseconds(), '3,000,000 + 1');
      Assert.AreEqual(0, (Duration.Epsilon + Duration.FromNanoseconds(-1)).ToInt64Nanoseconds(), '1 + (-1)');
      Assert.AreEqual(-49999999, (negativeFiftyMillion + Duration.Epsilon).ToInt64Nanoseconds(), '-50,000,000 + 1');
    },

    'OperatorPlus_MethodEquivalents': (args) {
      Duration x = Duration.FromNanoseconds(100);
      Duration y = Duration.FromNanoseconds(200);
      Assert.AreEqual(x + y, Duration.Add(x, y));
      Assert.AreEqual(x + y, x.Plus(y));
    },
    // #endregion

    // #region operator -
    'OperatorMinus_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(0, (Duration.Zero - Duration.Zero).ToInt64Nanoseconds(), '0 - 0');
      Assert.AreEqual(1, (Duration.Epsilon - Duration.Zero).ToInt64Nanoseconds(), '1 - 0');
      Assert.AreEqual(-1, (Duration.Zero - Duration.Epsilon).ToInt64Nanoseconds(), '0 - 1');
    },

    'OperatorMinus_NonZero': (args) {
      Duration negativeEpsilon = Duration.FromNanoseconds(-1);
      Assert.AreEqual(2999999, (threeMillion - Duration.Epsilon).ToInt64Nanoseconds(), '3,000,000 - 1');
      Assert.AreEqual(2, (Duration.Epsilon - negativeEpsilon).ToInt64Nanoseconds(), '1 - (-1)');
      Assert.AreEqual(-50000001, (negativeFiftyMillion - Duration.Epsilon).ToInt64Nanoseconds(), '-50,000,000 - 1');
    },

    'OperatorMinus_MethodEquivalents': (args) {
      Duration x = Duration.FromNanoseconds(100);
      Duration y = Duration.FromNanoseconds(200);
      Assert.AreEqual(x - y, Duration.Subtract(x, y));
      Assert.AreEqual(x - y, x.Minus(y));
    },
    // #endregion

    // #region operator /
    'OperatorDivision_Int64': (args) {
      final [int days, int nanoOfDay, int divisor, int expectedDays, int expectedNanoOfDay] = args;
      var duration = Duration.NewDaysNanoOfDay(days, nanoOfDay);
      var actual = duration / divisor;
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, actual);
    },

    'OperatorDivision_Double': (args) {
      final [int days, int nanoOfDay, double divisor, int expectedDays, int expectedNanoOfDay] = args;
      var duration = Duration.NewDaysNanoOfDay(days, nanoOfDay);
      var actual = Duration.DivideDouble(duration, divisor);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanoOfDay);
      Assert.AreEqual(expected, actual);
    },

    'OperatorDivision_Duration': (args) {
      final [int dividendDays, int dividendNanoOfDay, int divisorDays, int divisorNanoOfDay, double expected] = args;
      var dividend = Duration.NewDaysNanoOfDay(dividendDays, dividendNanoOfDay);
      var divisor = Duration.NewDaysNanoOfDay(divisorDays, divisorNanoOfDay);
      var actual = Duration.DivideDuration(dividend, divisor);
      Assert.AreEqual(expected, actual);
    },

    'OperatorDivision_ByZero_Throws': (args) {
      Assert.Throws<DivideByZeroException>(() => Duration.DivideDouble(threeMillion, 0.0).toString(), '3000000 / 0');
      Assert.Throws<DivideByZeroException>(() => (threeMillion / 0).toString(), '3000000 / 0');
      Assert.Throws<DivideByZeroException>(() => Duration.DivideDuration(threeMillion, Duration.Zero).toString(), '3000000 / 0');
    },

    'OperatorDivision_MethodEquivalent': (args) {
      Assert.AreEqual(threeMillion / 2000000, Duration.Divide(threeMillion, 2000000));
      // noda_dart: operator /(Duration, double) and Divide(Duration, double) are both DivideDouble.
      Assert.AreEqual(Duration.DivideDouble(threeMillion, 2000000.0), Duration.DivideDouble(threeMillion, 2000000.0));
      // noda_dart: operator /(Duration, Duration) and Divide(Duration, Duration) are both DivideDuration.
      Assert.AreEqual(Duration.DivideDuration(negativeFiftyMillion, threeMillion), Duration.DivideDuration(negativeFiftyMillion, threeMillion));
    },
    // #endregion

    // #region operator *
    'OperatorMultiplication_Int64': (args) {
      final [int days, int nanos, int rightOperand] = args;
      // Rather than expressing an expected answer, just do a "long-hand" version
      // using ToBigIntegerNanoseconds and FromNanoseconds, trusting those two operations
      // to be correct.
      var duration = Duration.FromDays(days) + Duration.FromNanoseconds(nanos);
      var actual = duration * rightOperand;

      var expected = Duration.FromNanosecondsBigInteger(duration.ToBigIntegerNanoseconds() * BigInt.from(rightOperand));
      Assert.AreEqual(expected, actual);
    },

    'OperatorMultiplication_Double': (args) {
      final [int days, int nanos, double rightOperand, int expectedDays, int expectedNanos] = args;
      var start = Duration.NewDaysNanoOfDay(days, nanos);
      var actual = Duration.MultiplyDouble(start, rightOperand);
      var expected = Duration.NewDaysNanoOfDay(expectedDays, expectedNanos);
      Assert.AreEqual(expected, actual);
      actual = Duration.MultiplyDoubleDuration(rightOperand, start);
      Assert.AreEqual(expected, actual);
    },

    'Commutation': (args) {
      Assert.AreEqual(threeMillion * 5, Duration.MultiplyInt64Duration(5, threeMillion));
      Assert.AreEqual(Duration.MultiplyDouble(threeMillion, 5.5), Duration.MultiplyDoubleDuration(5.5, threeMillion));
    },

    'OperatorMultiplication_MethodEquivalents': (args) {
      Assert.AreEqual(Duration.FromNanoseconds(-50000) * 1000, Duration.Multiply(Duration.FromNanoseconds(-50000), 1000));
      // noda_dart: operator *(long, Duration) and Multiply(long, Duration) are both MultiplyInt64Duration.
      Assert.AreEqual(Duration.MultiplyInt64Duration(1000, Duration.FromNanoseconds(-50000)), Duration.MultiplyInt64Duration(1000, Duration.FromNanoseconds(-50000)));
      // noda_dart: operator *(Duration, double) and Multiply(Duration, double) are both MultiplyDouble.
      Assert.AreEqual(Duration.MultiplyDouble(Duration.FromNanoseconds(-50000), 1000.0), Duration.MultiplyDouble(Duration.FromNanoseconds(-50000), 1000.0));
      // noda_dart: operator *(double, Duration) and Multiply(double, Duration) are both MultiplyDoubleDuration.
      Assert.AreEqual(Duration.MultiplyDoubleDuration(1000.0, Duration.FromNanoseconds(-50000)), Duration.MultiplyDoubleDuration(1000.0, Duration.FromNanoseconds(-50000)));
    },
    // #endregion

    'UnaryMinusAndNegate': (args) {
      var start = Duration.FromNanoseconds(5000);
      var expected = Duration.FromNanoseconds(-5000);
      Assert.AreEqual(expected, -start);
      Assert.AreEqual(expected, Duration.Negate(start));
    },
    // #endregion
  }, skip: {
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
    'UnaryAddition': SkipReasons.UnaryPlus,
  });
}
