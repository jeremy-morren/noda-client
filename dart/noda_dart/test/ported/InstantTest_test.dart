// Ported from NodaTime 6e024dde: src/NodaTime.Test/InstantTest.cs (+ InstantTest.Format.cs, InstantTest.Operators.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: DateTime is core.DateTime (microseconds, UTC or local); DateTimeOffset isn't ported.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/IslamicEpoch.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicLeapYearPattern.generated.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalInstant.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetDateTime.dart';
import 'package:noda_dart/src/Text/InvalidPatternException.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/InstantTest.generated.dart' as scenarios;

// #region InstantTest.cs (fields)
final Instant one = Instant.FromUntrustedDuration(Duration.FromNanoseconds(1));
final Instant threeMillion = Instant.FromUntrustedDuration(Duration.FromNanoseconds(3000000));
final Instant negativeFiftyMillion = Instant.FromUntrustedDuration(Duration.FromNanoseconds(-50000000));
// #endregion

// #region InstantTest.Format.cs (helpers)
void TestToStringBase(Instant value, String gvalue) {
  String actual = value.toString();
  Assert.AreEqual(gvalue, actual);
  actual = value.ToStringPattern('g', null);
  Assert.AreEqual(gvalue, actual);
  actual = value.ToStringPattern('g', NodaCultureInfo.InvariantCulture);
  Assert.AreEqual(gvalue, actual);

  actual = '$value';
  Assert.AreEqual(gvalue, actual);
  // noda_dart: C#'s $"{value:g}" (IFormattable.ToString("g", current culture)); Dart's interpolation has no format.
  actual = value.ToStringPattern('g', null);
  Assert.AreEqual(gvalue, actual);
}
// #endregion

void main() {
  port(scenarios.fixture, {
    // #region InstantTest.cs
    'JulianDateConversions': (args) {
      final [double julianDate, int year, int month, int day, int hour, int minute, int second] = args;
      // When dealing with floating point binary data, if we're accurate to 50 milliseconds, that's fine...
      // (0.000001 days = ~86ms, as a guide to the scale involved...)
      Instant actual = Instant.FromJulianDate(julianDate);
      Instant expected =
          LocalDateTime.YearMonthDayHourMinuteSecondCalendar(year, month, day, hour, minute, second, CalendarSystem.Julian).InUtc().ToInstant();
      Assert.AreEqual(expected.ToUnixTimeMilliseconds(), actual.ToUnixTimeMilliseconds(), 50, 'Expected $expected, was $actual');
      Assert.AreEqual(julianDate, expected.ToJulianDate(), 0.000001);
    },

    'FromUtcNoSeconds': (args) {
      Instant viaUtc = DateTimeZone.Utc.AtStrictly(LocalDateTime(2008, 4, 3, 10, 35, 0)).ToInstant();
      Assert.AreEqual(viaUtc, Instant.FromUtc(2008, 4, 3, 10, 35));
    },

    'FromUtcWithSeconds': (args) {
      Instant viaUtc = DateTimeZone.Utc.AtStrictly(LocalDateTime(2008, 4, 3, 10, 35, 23)).ToInstant();
      Assert.AreEqual(viaUtc, Instant.FromUtc(2008, 4, 3, 10, 35, 23));
    },

    'InUtc': (args) {
      ZonedDateTime viaInstant = Instant.FromUtc(2008, 4, 3, 10, 35, 23).InUtc();
      ZonedDateTime expected = DateTimeZone.Utc.AtStrictly(LocalDateTime(2008, 4, 3, 10, 35, 23));
      Assert.AreEqual(expected, viaInstant);
    },

    'InZone': (args) {
      DateTimeZone london = DateTimeZoneProviders.Tzdb['Europe/London'];
      ZonedDateTime viaInstant = Instant.FromUtc(2008, 6, 10, 13, 16, 17).InZone(london);

      // London is UTC+1 in the Summer, so the above is 14:16:17 local.
      LocalDateTime local = LocalDateTime(2008, 6, 10, 14, 16, 17);
      ZonedDateTime expected = london.AtStrictly(local);

      Assert.AreEqual(expected, viaInstant);
    },

    'WithOffset': (args) {
      // Jon talks about Noda Time at Leetspeak in Sweden on October 12th 2013, at 13:15 UTC+2
      Instant instant = Instant.FromUtc(2013, 10, 12, 11, 15);
      Offset offset = Offset.FromHours(2);
      OffsetDateTime actual = instant.WithOffset(offset);
      OffsetDateTime expected = OffsetDateTime(LocalDateTime(2013, 10, 12, 13, 15), offset);
      Assert.AreEqual(expected, actual);
    },

    'WithOffset_NonIsoCalendar': (args) {
      // October 12th 2013 ISO is 1434-12-07 Islamic
      CalendarSystem calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
      Instant instant = Instant.FromUtc(2013, 10, 12, 11, 15);
      Offset offset = Offset.FromHours(2);
      OffsetDateTime actual = instant.WithOffset(offset, calendar);
      OffsetDateTime expected = OffsetDateTime(LocalDateTime.YearMonthDayHourMinuteCalendar(1434, 12, 7, 13, 15, calendar), offset);
      Assert.AreEqual(expected, actual);
    },

    'FromTicksSinceUnixEpoch': (args) {
      Instant instant = Instant.FromUnixTimeTicks(12345);
      Assert.AreEqual(12345, instant.ToUnixTimeTicks());
    },

    'FromUnixTimeMilliseconds_Valid': (args) {
      Instant actual = Instant.FromUnixTimeMilliseconds(12345);
      Instant expected = Instant.FromUnixTimeTicks(12345 * NodaConstants.TicksPerMillisecond);
      Assert.AreEqual(expected, actual);
    },

    'FromUnixTimeMilliseconds_TooLarge': (args) {
      Assert.Throws<RangeError>(() => Instant.FromUnixTimeMilliseconds(Int64.MaxValue ~/ 100));
    },

    'FromUnixTimeMilliseconds_TooSmall': (args) {
      Assert.Throws<RangeError>(() => Instant.FromUnixTimeMilliseconds(Int64.MinValue ~/ 100));
    },

    'FromUnixTimeSeconds_Valid': (args) {
      Instant actual = Instant.FromUnixTimeSeconds(12345);
      Instant expected = Instant.FromUnixTimeTicks(12345 * NodaConstants.TicksPerSecond);
      Assert.AreEqual(expected, actual);
    },

    'FromUnixTimeSeconds_TooLarge': (args) {
      Assert.Throws<RangeError>(() => Instant.FromUnixTimeSeconds(Int64.MaxValue ~/ 1000000));
    },

    'FromUnixTimeSeconds_TooSmall': (args) {
      Assert.Throws<RangeError>(() => Instant.FromUnixTimeSeconds(Int64.MinValue ~/ 1000000));
    },

    'ToUnixTimeSeconds': (args) {
      final [int milliseconds, int expectedSeconds] = args;
      var instant = Instant.FromUnixTimeMilliseconds(milliseconds);
      Assert.AreEqual(expectedSeconds, instant.ToUnixTimeSeconds());
    },

    // The fact that all the expected nanosecond values are multiples of
    // a million is slightly unfortunate, but the logic is so simple that
    // it's not worth going to extreme lengths to test more fine-grained values.
    'ToUnixTimeSecondsAndNanoseconds': (args) {
      final [int milliseconds, int expectedSeconds, int expectedNanoseconds] = args;
      var instant = Instant.FromUnixTimeMilliseconds(milliseconds);
      var (seconds: actualSeconds, nanoseconds: actualNanoseconds) = instant.ToUnixTimeSecondsAndNanoseconds();
      Assert.AreEqual(expectedSeconds, actualSeconds);
      Assert.AreEqual(expectedNanoseconds, actualNanoseconds);
    },

    'ToUnixTimeMilliseconds': (args) {
      final [int ticks, int expectedMilliseconds] = args;
      var instant = Instant.FromUnixTimeTicks(ticks);
      Assert.AreEqual(expectedMilliseconds, instant.ToUnixTimeMilliseconds());
    },

    'UnixConversions_ExtremeValues': (args) {
      // Round down to a whole second to make round-tripping work.
      var max = Instant.MaxValue.MinusDuration(Duration.FromSeconds(1)) + Duration.Epsilon;
      Assert.AreEqual(max, Instant.FromUnixTimeSeconds(max.ToUnixTimeSeconds()));
      Assert.AreEqual(max, Instant.FromUnixTimeMilliseconds(max.ToUnixTimeMilliseconds()));
      Assert.AreEqual(max, Instant.FromUnixTimeTicks(max.ToUnixTimeTicks()));

      var min = Instant.MinValue;
      Assert.AreEqual(min, Instant.FromUnixTimeSeconds(min.ToUnixTimeSeconds()));
      Assert.AreEqual(min, Instant.FromUnixTimeMilliseconds(min.ToUnixTimeMilliseconds()));
      Assert.AreEqual(min, Instant.FromUnixTimeTicks(min.ToUnixTimeTicks()));
    },

    'InZoneWithCalendar': (args) {
      CalendarSystem copticCalendar = CalendarSystem.Coptic;
      DateTimeZone london = DateTimeZoneProviders.Tzdb['Europe/London'];
      ZonedDateTime viaInstant = Instant.FromUtc(2004, 6, 9, 11, 10).InZone(london, copticCalendar);

      // Date taken from CopticCalendarSystemTest. Time will be 12:10 (London is UTC+1 in Summer)
      LocalDateTime local = LocalDateTime.YearMonthDayHourMinuteSecondCalendar(1720, 10, 2, 12, 10, 0, copticCalendar);
      ZonedDateTime expected = london.AtStrictly(local);
      Assert.AreEqual(expected, viaInstant);
    },

    'Max': (args) {
      Instant x = Instant.FromUnixTimeTicks(100);
      Instant y = Instant.FromUnixTimeTicks(200);
      Assert.AreEqual(y, Instant.Max(x, y));
      Assert.AreEqual(y, Instant.Max(y, x));
      Assert.AreEqual(x, Instant.Max(x, Instant.MinValue));
      Assert.AreEqual(x, Instant.Max(Instant.MinValue, x));
      Assert.AreEqual(Instant.MaxValue, Instant.Max(Instant.MaxValue, x));
      Assert.AreEqual(Instant.MaxValue, Instant.Max(x, Instant.MaxValue));
    },

    'Min': (args) {
      Instant x = Instant.FromUnixTimeTicks(100);
      Instant y = Instant.FromUnixTimeTicks(200);
      Assert.AreEqual(x, Instant.Min(x, y));
      Assert.AreEqual(x, Instant.Min(y, x));
      Assert.AreEqual(Instant.MinValue, Instant.Min(x, Instant.MinValue));
      Assert.AreEqual(Instant.MinValue, Instant.Min(Instant.MinValue, x));
      Assert.AreEqual(x, Instant.Min(Instant.MaxValue, x));
      Assert.AreEqual(x, Instant.Min(x, Instant.MaxValue));
    },

    'ToDateTimeUtc': (args) {
      Instant x = Instant.FromUtc(2011, 08, 18, 20, 53);
      core.DateTime expected = core.DateTime.utc(2011, 08, 18, 20, 53, 0);
      core.DateTime actual = x.ToDateTimeUtc();
      Assert.AreEqual(expected, actual);

      // Kind isn't checked by Equals...
      // (noda_dart: DateTimeKind.Utc is isUtc, which Dart's == does check.)
      Assert.AreEqual(true, actual.isUtc);
    },

    // See issue 269, but now we throw a nicer exception.
    'ToBclTypes_DateOutOfRange': (args) {
      var instant = Instant.FromUtc(1, 1, 1, 0, 0).PlusNanoseconds(-1);
      Assert.Throws<StateError>(() => instant.ToDateTimeUtc());
      // Not ported: ToDateTimeOffset (Dart has no DateTimeOffset).
    },

    'ToBclTypes_TruncateNanosTowardStartOfTime': (args) {
      final [int year] = args;
      var instant = Instant.FromUtc(year, 1, 1, 13, 15, 55).PlusNanoseconds(NodaConstants.NanosecondsPerSecond - 1);
      // noda_dart: a Dart DateTime has microseconds rather than ticks, so the truncation is to the last microsecond.
      var expectedDateTimeUtc = core.DateTime.utc(year, 1, 1, 13, 15, 55)
          .add(core.Duration(microseconds: core.Duration.microsecondsPerSecond - 1));
      var actualDateTimeUtc = instant.ToDateTimeUtc();
      Assert.AreEqual(expectedDateTimeUtc, actualDateTimeUtc);
      // Not ported: the DateTimeOffset half (Dart has no DateTimeOffset).
    },

    'FromDateTimeUtc_Invalid': (args) {
      Assert.Throws<ArgumentError>(() => Instant.FromDateTimeUtc(core.DateTime(2011, 08, 18, 20, 53, 0)));
      // Not ported: DateTimeKind.Unspecified (a Dart DateTime is either UTC or local, which is checked above).
    },

    'FromDateTimeUtc_Valid': (args) {
      core.DateTime x = core.DateTime.utc(2011, 08, 18, 20, 53, 0);
      Instant expected = Instant.FromUtc(2011, 08, 18, 20, 53);
      Assert.AreEqual(expected, Instant.FromDateTimeUtc(x));
    },

    'TicksTruncatesDown': (args) {
      final [int nanoseconds, int expectedTicks] = args;
      Duration nanos = Duration.FromNanoseconds(nanoseconds);
      Instant instant = Instant.FromUntrustedDuration(nanos);
      Assert.AreEqual(expectedTicks, instant.ToUnixTimeTicks());
    },

    'IsValid': (args) {
      Assert.IsFalse(Instant.BeforeMinValue.IsValid);
      Assert.IsTrue(Instant.MinValue.IsValid);
      Assert.IsTrue(Instant.MaxValue.IsValid);
      Assert.IsFalse(Instant.AfterMaxValue.IsValid);
    },

    'InvalidValues': (args) {
      Assert.Greater(Instant.AfterMaxValue, Instant.MaxValue);
      Assert.Less(Instant.BeforeMinValue, Instant.MinValue);
    },

    'PlusDuration_Overflow': (args) {
      TestHelper.AssertOverflow(Instant.MinValue.Plus, -Duration.Epsilon);
      TestHelper.AssertOverflow(Instant.MaxValue.Plus, Duration.Epsilon);
    },

    'ExtremeArithmetic': (args) {
      Duration hugeAndPositive = Instant.MaxValue - Instant.MinValue;
      Duration hugeAndNegative = Instant.MinValue - Instant.MaxValue;
      Assert.AreEqual(hugeAndNegative, -hugeAndPositive);
      Assert.AreEqual(Instant.MaxValue, Instant.MinValue.MinusDuration(hugeAndNegative));
      Assert.AreEqual(Instant.MaxValue, Instant.MinValue + hugeAndPositive);
      Assert.AreEqual(Instant.MinValue, Instant.MaxValue + hugeAndNegative);
      Assert.AreEqual(Instant.MinValue, Instant.MaxValue.MinusDuration(hugeAndPositive));
    },

    'PlusOffset_Overflow': (args) {
      TestHelper.AssertOverflow(Instant.MinValue.PlusOffset, Offset.FromSeconds(-1));
      TestHelper.AssertOverflow(Instant.MaxValue.PlusOffset, Offset.FromSeconds(1));
    },

    'FromUnixTimeMilliseconds_Range': (args) {
      int smallestValid = Instant.MinValue.ToUnixTimeTicks() ~/ NodaConstants.TicksPerMillisecond;
      int largestValid = Instant.MaxValue.ToUnixTimeTicks() ~/ NodaConstants.TicksPerMillisecond;
      TestHelper.AssertValid(Instant.FromUnixTimeMilliseconds, smallestValid);
      TestHelper.AssertOutOfRange(Instant.FromUnixTimeMilliseconds, smallestValid - 1);
      TestHelper.AssertValid(Instant.FromUnixTimeMilliseconds, largestValid);
      TestHelper.AssertOutOfRange(Instant.FromUnixTimeMilliseconds, largestValid + 1);
    },

    'FromUnixTimeSeconds_Range': (args) {
      int smallestValid = Instant.MinValue.ToUnixTimeTicks() ~/ NodaConstants.TicksPerSecond;
      int largestValid = Instant.MaxValue.ToUnixTimeTicks() ~/ NodaConstants.TicksPerSecond;
      TestHelper.AssertValid(Instant.FromUnixTimeSeconds, smallestValid);
      TestHelper.AssertOutOfRange(Instant.FromUnixTimeSeconds, smallestValid - 1);
      TestHelper.AssertValid(Instant.FromUnixTimeSeconds, largestValid);
      TestHelper.AssertOutOfRange(Instant.FromUnixTimeSeconds, largestValid + 1);
    },

    'FromTicksSinceUnixEpoch_Range': (args) {
      int smallestValid = Instant.MinValue.ToUnixTimeTicks();
      int largestValid = Instant.MaxValue.ToUnixTimeTicks();
      TestHelper.AssertValid(Instant.FromUnixTimeTicks, smallestValid);
      TestHelper.AssertOutOfRange(Instant.FromUnixTimeTicks, smallestValid - 1);
      TestHelper.AssertValid(Instant.FromUnixTimeTicks, largestValid);
      TestHelper.AssertOutOfRange(Instant.FromUnixTimeTicks, largestValid + 1);
    },

    'PlusOffset': (args) {
      var localInstant = NodaConstants.UnixEpoch.PlusOffset(Offset.FromHours(1));
      Assert.AreEqual(Duration.FromHours(1), localInstant.TimeSinceLocalEpoch);
    },

    'SafePlus_NormalTime': (args) {
      var localInstant = NodaConstants.UnixEpoch.SafePlus(Offset.FromHours(1));
      Assert.AreEqual(Duration.FromHours(1), localInstant.TimeSinceLocalEpoch);
    },

    'SafePlus_NearStartOfTime': (args) {
      final [int? initialOffset, int offsetToAdd, int? finalOffset] = args;
      var start = initialOffset == null
          ? Instant.BeforeMinValue
          : Instant.MinValue + Duration.FromHours(initialOffset);
      var expected = finalOffset == null
          ? LocalInstant.BeforeMinValue
          : Instant.MinValue.PlusOffset(Offset.FromHours(finalOffset));
      var actual = start.SafePlus(Offset.FromHours(offsetToAdd));
      Assert.AreEqual(expected, actual);
    },

    // A null offset indicates "AfterMaxValue". Otherwise, MaxValue.Plus(offset)
    'SafePlus_NearEndOfTime': (args) {
      final [int? initialOffset, int offsetToAdd, int? finalOffset] = args;
      var start = initialOffset == null
          ? Instant.AfterMaxValue
          : Instant.MaxValue + Duration.FromHours(initialOffset);
      var expected = finalOffset == null
          ? LocalInstant.AfterMaxValue
          : Instant.MaxValue.PlusOffset(Offset.FromHours(finalOffset));
      var actual = start.SafePlus(Offset.FromHours(offsetToAdd));
      Assert.AreEqual(expected, actual);
    },
    // #endregion

    // #region InstantTest.Format.cs
    'TestToString_InvalidFormat': (args) {
      Assert.Throws<InvalidPatternException>(() => NodaConstants.UnixEpoch.ToStringPattern('A', null));
    },

    'TestToString_MinValue': (args) {
      TestToStringBase(Instant.MinValue, '-9998-01-01T00:00:00Z');
    },

    'TestToString_MaxValue': (args) {
      TestToStringBase(Instant.MaxValue, '9999-12-31T23:59:59Z');
    },

    'TestToString_UnixEpoch': (args) {
      TestToStringBase(NodaConstants.UnixEpoch, '1970-01-01T00:00:00Z');
    },

    'TestToString_Padding': (args) {
      TestToStringBase(Instant.FromUtc(1, 1, 1, 12, 34, 56), '0001-01-01T12:34:56Z');
    },
    // #endregion

    // #region InstantTest.Operators.cs
    'Equality': (args) {
      Instant equal = Instant.NewDaysNanoOfDay(1, 100);
      Instant different1 = Instant.NewDaysNanoOfDay(1, 200);
      Instant different2 = Instant.NewDaysNanoOfDay(2, 100);

      TestHelper.TestEqualsStruct(equal, equal, [different1]);
      TestHelper.TestOperatorEquality(equal, equal, different1);

      TestHelper.TestEqualsStruct(equal, equal, [different2]);
      TestHelper.TestOperatorEquality(equal, equal, different2);
    },

    'Comparison': (args) {
      Instant equal = Instant.NewDaysNanoOfDay(1, 100);
      Instant greater1 = Instant.NewDaysNanoOfDay(1, 101);
      Instant greater2 = Instant.NewDaysNanoOfDay(2, 0);

      TestHelper.TestCompareToStruct(equal, equal, [greater1]);
      TestHelper.TestNonGenericCompareTo(equal, Instant.NewDaysNanoOfDay(1, 100), [greater1]);
      TestHelper.TestOperatorComparisonEquality(equal, Instant.NewDaysNanoOfDay(1, 100), [greater1, greater2]);
    },

    // #region operator +
    'PlusTicks': (args) {
      Instant instant = Instant.FromUnixTimeTicks(5);
      Assert.AreEqual(Instant.FromUnixTimeTicks(8), instant.PlusTicks(3));
    },

    'PlusNanoseconds': (args) {
      Instant instant = Instant.FromUnixTimeTicks(5);
      Assert.AreEqual(Instant.FromUnixTimeTicks(8), instant.PlusNanoseconds(300));
    },

    'OperatorPlusDuration_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(NodaConstants.UnixEpoch, NodaConstants.UnixEpoch + Duration.Zero, 'UnixEpoch + Duration.Zero');
      Assert.AreEqual(one, one + Duration.Zero, 'Instant(1) + Duration.Zero');
      Assert.AreEqual(one, NodaConstants.UnixEpoch + Duration.Epsilon, 'UnixEpoch + Duration.Epsilon');
    },

    'OperatorPlusDuration_NonZero': (args) {
      Assert.AreEqual(3000001, (threeMillion + Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), '3,000,000 + 1');
      Assert.AreEqual(0, (one + -Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), '1 + (-1)');
      Assert.AreEqual(-49999999, (negativeFiftyMillion + Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), '-50,000,000 + 1');
    },

    // Smoke tests for methods which simply delegate to the + operator.
    'OperatorPlus_Equivalents': (args) {
      Assert.AreEqual(threeMillion + Duration.Epsilon, threeMillion.Plus(Duration.Epsilon));
      Assert.AreEqual(threeMillion + Duration.Epsilon, Instant.Add(threeMillion, Duration.Epsilon));
    },

    // The Plus(Offset) method *would* be an operator, but can't be as LocalInstant is internal.
    'OperatorPlusOffset_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(LocalInstant.NewDaysNanoOfDay(0, 0), NodaConstants.UnixEpoch.PlusOffset(Offset.Zero), 'UnixEpoch + Offset.Zero');
      Assert.AreEqual(LocalInstant.NewDaysNanoOfDay(0, 1), one.PlusOffset(Offset.Zero), 'Instant(1) + Offset.Zero');
      Assert.AreEqual(LocalInstant.NewDaysNanoOfDay(0, NodaConstants.NanosecondsPerHour), NodaConstants.UnixEpoch.PlusOffset(Offset.FromHours(1)), 'UnixEpoch + offsetOneHour');
    },

    'OperatorPlus_OutOfRange': (args) {
      Assert.Throws<OverflowException>(() => (Instant.MaxValue + Duration.Epsilon).hashCode);
    },
    // #endregion

    // #region operator - (duration)
    'OperatorMinusDuration': (args) {
      Assert.AreEqual(threeMillion, threeMillion.MinusDuration(Duration.Zero));
      Assert.AreEqual(2999999, threeMillion.MinusDuration(Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), '3,000,000 - 1');
      Assert.AreEqual(2, one.MinusDuration(Duration.FromNanoseconds(-1)).TimeSinceEpoch.ToInt64Nanoseconds(), '1 - (-1)');
      Assert.AreEqual(-50000001, negativeFiftyMillion.MinusDuration(Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), '-50,000,000 - 1');
    },

    // Smoke tests for methods which simply delegate to the - operator.
    'OperatorMinus_Duration_Equivalents': (args) {
      Assert.AreEqual(threeMillion.MinusDuration(Duration.Epsilon), threeMillion.MinusDuration(Duration.Epsilon));
      Assert.AreEqual(threeMillion.MinusDuration(Duration.Epsilon), Instant.SubtractDuration(threeMillion, Duration.Epsilon));
    },

    'OperatorMinus_OutOfRange': (args) {
      Assert.Throws<OverflowException>(() => Instant.MinValue.MinusDuration(Duration.Epsilon).hashCode);
    },
    // #endregion

    // #region operator - (instant)
    'OperatorMinusInstant_NonZero': (args) {
      Assert.AreEqual(2999999, (threeMillion - one).ToInt64Nanoseconds(), '3,000,000 - 1');
      Assert.AreEqual(2, (one - Instant.FromUntrustedDuration(Duration.FromNanoseconds(-1))).ToInt64Nanoseconds(), '1 - (-1)');
      Assert.AreEqual(-50000001, (negativeFiftyMillion - one).ToInt64Nanoseconds(), '-50,000,000 - 1');
    },

    'OperatorMinusInstant_UnixEpoch_IsNeutralElement': (args) {
      Assert.AreEqual(0, (NodaConstants.UnixEpoch - NodaConstants.UnixEpoch).ToInt64Nanoseconds(), '0 - 0');
      Assert.AreEqual(1, (one - NodaConstants.UnixEpoch).ToInt64Nanoseconds(), '1 - 0');
      Assert.AreEqual(-1, (NodaConstants.UnixEpoch - one).ToInt64Nanoseconds(), '0 - 1');
    },

    // Smoke tests for methods which simply delegate to the - operator.
    'OperatorMinus_Instant_Equivalents': (args) {
      Assert.AreEqual(threeMillion - one, threeMillion.Minus(one));
      Assert.AreEqual(threeMillion - one, Instant.Subtract(threeMillion, one));
    },
    // #endregion
    // #endregion
  }, skip: {
    'ToDateTimeOffset': SkipReasons.DateTimeOffset,
    'FromDateTimeOffset': SkipReasons.DateTimeOffset,
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
    if (isDart2js) 'UnixConversions_ExtremeValues': SkipReasons.Dart2jsInt,
    if (isDart2js) 'FromUnixTimeMilliseconds_Range': SkipReasons.Dart2jsInt,
    if (isDart2js) 'FromUnixTimeSeconds_Range': SkipReasons.Dart2jsInt,
    if (isDart2js) 'FromTicksSinceUnixEpoch_Range': SkipReasons.Dart2jsInt,
  });
}
