// Ported from NodaTime 6e024dde: src/NodaTime.Test/LocalTimeTest.cs (+ LocalTimeTest.Construction.cs,
// LocalTimeTest.Conversion.cs, LocalTimeTest.Operators.cs, LocalTimeTest.Pseudomutators.cs)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetTime.dart';
import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/TimeAdjusters.dart';
import 'package:noda_dart/src/Utility/Int64.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/LocalTimeTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // #region LocalTimeTest.Construction.cs
    'InvalidConstructionToMinute': (args) {
      final [int hour, int minute] = args;
      Assert.Throws<RangeError>(() => LocalTime(hour, minute));
    },

    'InvalidConstructionToSecond': (args) {
      final [int hour, int minute, int second] = args;
      Assert.Throws<RangeError>(() => LocalTime(hour, minute, second));
    },

    'InvalidConstructionToMillisecond': (args) {
      final [int hour, int minute, int second, int millisecond] = args;
      Assert.Throws<RangeError>(() => LocalTime(hour, minute, second, millisecond));
    },

    'FromHourMinuteSecondMillisecondTick_Invalid': (args) {
      final [int hour, int minute, int second, int millisecond, int tick] = args;
      Assert.Throws<RangeError>(
          () => LocalTime.FromHourMinuteSecondMillisecondTick(hour, minute, second, millisecond, tick));
    },

    'FromHourMinuteSecondTick_Invalid': (args) {
      final [int hour, int minute, int second, int tick] = args;
      Assert.Throws<RangeError>(
          () => LocalTime.FromHourMinuteSecondTick(hour, minute, second, tick));
    },

    'FromHourMinuteSecondTick_Valid': (args) {
      var result = LocalTime.FromHourMinuteSecondTick(1, 2, 3, NodaConstants.TicksPerSecond - 1);
      Assert.AreEqual(1, result.Hour);
      Assert.AreEqual(2, result.Minute);
      Assert.AreEqual(3, result.Second);
      Assert.AreEqual(NodaConstants.TicksPerSecond - 1, result.TickOfSecond);
    },

    'FromHourMinuteSecondNanosecond_Invalid': (args) {
      final [int hour, int minute, int second, int nanosecond] = args;
      Assert.Throws<RangeError>(
          () => LocalTime.FromHourMinuteSecondNanosecond(hour, minute, second, nanosecond));
    },

    'FromNanosecondsSinceMidnight_Valid': (args) {
      Assert.AreEqual(LocalTime.Midnight, LocalTime.FromNanosecondsSinceMidnight(0));
      Assert.AreEqual(LocalTime.Midnight.PlusNanoseconds(-1), LocalTime.FromNanosecondsSinceMidnight(NodaConstants.NanosecondsPerDay - 1));
    },

    'FromNanosecondsSinceMidnight_RangeChecks': (args) {
      Assert.Throws<RangeError>(() => LocalTime.FromNanosecondsSinceMidnight(-1));
      Assert.Throws<RangeError>(() => LocalTime.FromNanosecondsSinceMidnight(NodaConstants.NanosecondsPerDay));
    },

    'FromTicksSinceMidnight_Valid': (args) {
      Assert.AreEqual(LocalTime.Midnight, LocalTime.FromTicksSinceMidnight(0));
      Assert.AreEqual(LocalTime.Midnight - Period.FromTicks(1), LocalTime.FromTicksSinceMidnight(NodaConstants.TicksPerDay - 1));
    },

    'FromTicksSinceMidnight_RangeChecks': (args) {
      Assert.Throws<RangeError>(() => LocalTime.FromTicksSinceMidnight(-1));
      Assert.Throws<RangeError>(() => LocalTime.FromTicksSinceMidnight(NodaConstants.TicksPerDay));
    },

    'FromMillisecondsSinceMidnight_Valid': (args) {
      Assert.AreEqual(LocalTime.Midnight, LocalTime.FromMillisecondsSinceMidnight(0));
      Assert.AreEqual(LocalTime.Midnight - Period.FromMilliseconds(1), LocalTime.FromMillisecondsSinceMidnight(NodaConstants.MillisecondsPerDay - 1));
    },

    'FromMillisecondsSinceMidnight_RangeChecks': (args) {
      Assert.Throws<RangeError>(() => LocalTime.FromMillisecondsSinceMidnight(-1));
      Assert.Throws<RangeError>(() => LocalTime.FromMillisecondsSinceMidnight(NodaConstants.MillisecondsPerDay));
    },

    'FromSecondsSinceMidnight_Valid': (args) {
      Assert.AreEqual(LocalTime.Midnight, LocalTime.FromSecondsSinceMidnight(0));
      Assert.AreEqual(LocalTime.Midnight - Period.FromSeconds(1), LocalTime.FromSecondsSinceMidnight(NodaConstants.SecondsPerDay - 1));
    },

    'FromSecondsSinceMidnight_RangeChecks': (args) {
      Assert.Throws<RangeError>(() => LocalTime.FromSecondsSinceMidnight(-1));
      Assert.Throws<RangeError>(() => LocalTime.FromSecondsSinceMidnight(NodaConstants.SecondsPerDay));
    },

    'FromMinutesSinceMidnight_Valid': (args) {
      Assert.AreEqual(LocalTime.Midnight, LocalTime.FromMinutesSinceMidnight(0));
      Assert.AreEqual(LocalTime.Midnight - Period.FromMinutes(1), LocalTime.FromMinutesSinceMidnight(NodaConstants.MinutesPerDay - 1));
    },

    'FromMinutesSinceMidnight_RangeChecks': (args) {
      Assert.Throws<RangeError>(() => LocalTime.FromMinutesSinceMidnight(-1));
      Assert.Throws<RangeError>(() => LocalTime.FromMinutesSinceMidnight(NodaConstants.MinutesPerDay));
    },

    'FromHoursSinceMidnight_Valid': (args) {
      Assert.AreEqual(LocalTime.Midnight, LocalTime.FromHoursSinceMidnight(0));
      Assert.AreEqual(LocalTime.Midnight - Period.FromHours(1), LocalTime.FromHoursSinceMidnight(NodaConstants.HoursPerDay - 1));
    },

    'FromHoursSinceMidnight_RangeChecks': (args) {
      Assert.Throws<RangeError>(() => LocalTime.FromHoursSinceMidnight(-1));
      Assert.Throws<RangeError>(() => LocalTime.FromHoursSinceMidnight(NodaConstants.HoursPerDay));
    },
    // #endregion

    // #region LocalTimeTest.cs
    'MinValueEqualToMidnight': (args) {
      Assert.AreEqual(LocalTime.Midnight, LocalTime.MinValue);
    },

    'MaxValue': (args) {
      Assert.AreEqual(NodaConstants.NanosecondsPerDay - 1, LocalTime.MaxValue.NanosecondOfDay);
    },

    'ClockHourOfHalfDay': (args) {
      Assert.AreEqual(12, LocalTime(0, 0).ClockHourOfHalfDay);
      Assert.AreEqual(1, LocalTime(1, 0).ClockHourOfHalfDay);
      Assert.AreEqual(12, LocalTime(12, 0).ClockHourOfHalfDay);
      Assert.AreEqual(1, LocalTime(13, 0).ClockHourOfHalfDay);
      Assert.AreEqual(11, LocalTime(23, 0).ClockHourOfHalfDay);
    },

    'Max': (args) {
      LocalTime x = LocalTime(5, 10);
      LocalTime y = LocalTime(6, 20);
      Assert.AreEqual(y, LocalTime.Max(x, y));
      Assert.AreEqual(y, LocalTime.Max(y, x));
      Assert.AreEqual(x, LocalTime.Max(x, LocalTime.MinValue));
      Assert.AreEqual(x, LocalTime.Max(LocalTime.MinValue, x));
      Assert.AreEqual(LocalTime.MaxValue, LocalTime.Max(LocalTime.MaxValue, x));
      Assert.AreEqual(LocalTime.MaxValue, LocalTime.Max(x, LocalTime.MaxValue));
    },

    'Min': (args) {
      LocalTime x = LocalTime(5, 10);
      LocalTime y = LocalTime(6, 20);
      Assert.AreEqual(x, LocalTime.Min(x, y));
      Assert.AreEqual(x, LocalTime.Min(y, x));
      Assert.AreEqual(LocalTime.MinValue, LocalTime.Min(x, LocalTime.MinValue));
      Assert.AreEqual(LocalTime.MinValue, LocalTime.Min(LocalTime.MinValue, x));
      Assert.AreEqual(x, LocalTime.Min(LocalTime.MaxValue, x));
      Assert.AreEqual(x, LocalTime.Min(x, LocalTime.MaxValue));
    },

    'Deconstruction': (args) {
      var value = LocalTime(15, 8, 20);
      var expectedHour = 15;
      var expectedMinute = 8;
      var expectedSecond = 20;

      var (actualHour, actualMinute, actualSecond) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(expectedHour, actualHour);
        Assert.AreEqual(expectedMinute, actualMinute);
        Assert.AreEqual(expectedSecond, actualSecond);
      });
    },

    'WithOffset': (args) {
      var time = LocalTime(3, 45, 12, 34);
      var offset = Offset.FromHours(5);
      var expected = OffsetTime(time, offset);
      Assert.AreEqual(expected, time.WithOffset(offset));
    },

    'TestToString': (args) {
      var value = LocalTime(3, 45, 12, 34).WithOffset(Offset.FromHours(5));
      Assert.AreEqual(value.ToStringPattern(null, null), value.toString());
    },
    // #endregion

    // #region LocalTimeTest.Operators.cs
    'Addition_WithPeriod': (args) {
      LocalTime start = LocalTime(3, 30);
      Period period = Period.FromHours(2) + Period.FromSeconds(1);
      LocalTime expected = LocalTime(5, 30, 1);
      Assert.AreEqual(expected, start + period);
    },

    'Addition_WrapsAtMidnight': (args) {
      LocalTime start = LocalTime(22, 0);
      Period period = Period.FromHours(3);
      LocalTime expected = LocalTime(1, 0);
      Assert.AreEqual(expected, start + period);
    },

    'Subtraction_WithPeriod': (args) {
      LocalTime start = LocalTime(5, 30, 1);
      Period period = Period.FromHours(2) + Period.FromSeconds(1);
      LocalTime expected = LocalTime(3, 30, 0);
      Assert.AreEqual(expected, start - period);
    },

    'Subtraction_WrapsAtMidnight': (args) {
      LocalTime start = LocalTime(1, 0, 0);
      Period period = Period.FromHours(3);
      LocalTime expected = LocalTime(22, 0, 0);
      Assert.AreEqual(expected, start - period);
    },

    'Addition_PeriodWithDate': (args) {
      LocalTime time = LocalTime(20, 30);
      Period period = Period.FromDays(1);
      // Use method not operator here to form a valid statement
      Assert.Throws<ArgumentError>(() => LocalTime.Add(time, period));
    },

    'Subtraction_PeriodWithTime': (args) {
      LocalTime time = LocalTime(20, 30);
      Period period = Period.FromDays(1);
      // Use method not operator here to form a valid statement
      Assert.Throws<ArgumentError>(() => LocalTime.Subtract(time, period));
    },

    'PeriodAddition_MethodEquivalents': (args) {
      LocalTime start = LocalTime(20, 30);
      Period period = Period.FromHours(3) + Period.FromMinutes(10);
      Assert.AreEqual(start + period, LocalTime.Add(start, period));
      Assert.AreEqual(start + period, start.Plus(period));
    },

    'PeriodSubtraction_MethodEquivalents': (args) {
      LocalTime start = LocalTime(20, 30);
      Period period = Period.FromHours(3) + Period.FromMinutes(10);
      LocalTime end = start + period;
      Assert.AreEqual(start - period, LocalTime.Subtract(start, period));
      Assert.AreEqual(start - period, start.Minus(period));

      // noda_dart: `end - start` and Subtract/Minus(LocalTime) are SubtractLocalTime / MinusLocalTime.
      Assert.AreEqual(period, LocalTime.SubtractLocalTime(end, start));
      Assert.AreEqual(period, LocalTime.SubtractLocalTime(end, start));
      Assert.AreEqual(period, end.MinusLocalTime(start));
    },

    'EqualityAndComparison': (args) {
      LocalTime time1 = LocalTime(10, 30, 45);
      LocalTime time2 = LocalTime(10, 30, 45);
      LocalTime time3 = LocalTime(10, 30, 50);

      TestHelper.TestNonGenericCompareTo(time1, time2, [time3]);
      TestHelper.TestCompareToStruct(time1, time2, [time3]);
      TestHelper.TestOperatorComparisonEquality(time1, time2, [time3]);
      TestHelper.TestEqualsStruct(time1, time2, [time3]);
    },

    'Comparison_IgnoresOriginalCalendar': (args) {
      LocalDateTime dateTime1 = LocalDateTime(1900, 1, 1, 10, 30, 0);
      LocalDateTime dateTime2 = dateTime1.WithCalendar(CalendarSystem.Julian);

      // Calendar information is propagated into LocalDate, but not into LocalTime
      Assert.IsFalse(dateTime1.Date == dateTime2.Date);
      Assert.IsTrue(dateTime1.TimeOfDay == dateTime2.TimeOfDay);
    },

    'CompareTo': (args) {
      LocalTime time1 = LocalTime(10, 30, 45);
      LocalTime time2 = LocalTime(10, 30, 45);
      LocalTime time3 = LocalTime(10, 30, 50);

      Assert.That(time1.compareTo(time2), Is.EqualTo(0));
      Assert.That(time1.compareTo(time3), Is.LessThan(0));
      Assert.That(time3.compareTo(time2), Is.GreaterThan(0));
    },

    /// IComparable.CompareTo returns a positive number for a null input.
    'IComparableCompareTo_Null_Positive': (args) {
      var instance = LocalTime(10, 30, 45);
      var comparable = instance;
      var result = comparable.CompareTo(null);
      Assert.That(result, Is.GreaterThan(0));
    },

    /// IComparable.CompareTo throws an ArgumentException for non-null arguments
    /// that are not a LocalTime.
    'IComparableCompareTo_WrongType_ArgumentException': (args) {
      var instance = LocalTime(10, 30, 45);
      var i_instance = instance;
      var arg = LocalDate(2012, 3, 6);
      Assert.Throws<ArgumentError>(() {
        i_instance.CompareTo(arg);
      });
    },
    // #endregion

    // #region LocalTimeTest.Pseudomutators.cs
    'PlusHours_Simple': (args) {
      LocalTime start = LocalTime(12, 15, 8);
      LocalTime expectedForward = LocalTime(14, 15, 8);
      LocalTime expectedBackward = LocalTime(10, 15, 8);
      Assert.AreEqual(expectedForward, start.PlusHours(2));
      Assert.AreEqual(expectedBackward, start.PlusHours(-2));
    },

    'PlusHours_CrossingDayBoundary': (args) {
      LocalTime start = LocalTime(12, 15, 8);
      LocalTime expected = LocalTime(8, 15, 8);
      Assert.AreEqual(expected, start.PlusHours(20));
      Assert.AreEqual(start, start.PlusHours(20).PlusHours(-20));
    },

    'PlusHours_CrossingSeveralDaysBoundary': (args) {
      // Christmas day + 10 days and 1 hour
      LocalTime start = LocalTime(12, 15, 8);
      LocalTime expected = LocalTime(13, 15, 8);
      Assert.AreEqual(expected, start.PlusHours(241));
      Assert.AreEqual(start, start.PlusHours(241).PlusHours(-241));
    },

    // Having tested that hours cross boundaries correctly, the other time unit
    // tests are straightforward
    'PlusMinutes_Simple': (args) {
      LocalTime start = LocalTime(12, 15, 8);
      LocalTime expectedForward = LocalTime(12, 17, 8);
      LocalTime expectedBackward = LocalTime(12, 13, 8);
      Assert.AreEqual(expectedForward, start.PlusMinutes(2));
      Assert.AreEqual(expectedBackward, start.PlusMinutes(-2));
    },

    'PlusSeconds_Simple': (args) {
      LocalTime start = LocalTime(12, 15, 8);
      LocalTime expectedForward = LocalTime(12, 15, 18);
      LocalTime expectedBackward = LocalTime(12, 14, 58);
      Assert.AreEqual(expectedForward, start.PlusSeconds(10));
      Assert.AreEqual(expectedBackward, start.PlusSeconds(-10));
    },

    'PlusMilliseconds_Simple': (args) {
      LocalTime start = LocalTime(12, 15, 8, 300);
      LocalTime expectedForward = LocalTime(12, 15, 8, 700);
      LocalTime expectedBackward = LocalTime(12, 15, 7, 900);
      Assert.AreEqual(expectedForward, start.PlusMilliseconds(400));
      Assert.AreEqual(expectedBackward, start.PlusMilliseconds(-400));
    },

    'PlusTicks_Simple': (args) {
      LocalTime start = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7500);
      LocalTime expectedForward = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 301, 1500);
      LocalTime expectedBackward = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 3500);
      Assert.AreEqual(expectedForward, start.PlusTicks(4000));
      Assert.AreEqual(expectedBackward, start.PlusTicks(-4000));
    },

    'PlusTicks_Long': (args) {
      Assert.IsTrue(NodaConstants.TicksPerDay > Int64.Int32MaxValue);
      LocalTime start = LocalTime(12, 15, 8);
      LocalTime expectedForward = LocalTime(12, 15, 9);
      LocalTime expectedBackward = LocalTime(12, 15, 7);
      Assert.AreEqual(expectedForward, start.PlusTicks(NodaConstants.TicksPerDay + NodaConstants.TicksPerSecond));
      Assert.AreEqual(expectedBackward, start.PlusTicks(-NodaConstants.TicksPerDay - NodaConstants.TicksPerSecond));
    },

    'With': (args) {
      LocalTime start = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 100, 1234);
      LocalTime expected = LocalTime(12, 15, 8);
      Assert.AreEqual(expected, start.With(TimeAdjusters.TruncateToSecond));
    },

    'PlusMinutes_WouldOverflowNaively': (args) {
      LocalTime start = LocalTime(12, 34, 56);
      // Very big value, which just wraps round a *lot* and adds one minute.
      // There's no way we could compute that many nanoseconds.
      int value = (NodaConstants.NanosecondsPerDay << 15) + 1;
      LocalTime expected = LocalTime(12, 35, 56);
      LocalTime actual = start.PlusMinutes(value);
      Assert.AreEqual(expected, actual);
    },
    // #endregion
  }, skip: {
    'ToTimeOnly_OnTickBoundary': SkipReasons.DateOnlyTimeOnly,
    'ToTimeOnly_RoundsDown': SkipReasons.DateOnlyTimeOnly,
    'FromTimeOnly': SkipReasons.DateOnlyTimeOnly,
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
    'Addition_WithNullPeriod_ThrowsArgumentNullException': SkipReasons.NullSafety,
    'Subtraction_WithNullPeriod_ThrowsArgumentNullException': SkipReasons.NullSafety,
    // (NanosecondsPerDay << 15) + 1 is beyond 2^53 (and << truncates to 32 bits on dart2js).
    if (isDart2js) 'PlusMinutes_WouldOverflowNaively': SkipReasons.Dart2jsInt,
  });
}
