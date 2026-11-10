// Ported from NodaTime 6e024dde: src/NodaTime.Test/ZonedDateTimeTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: DateTime is core.DateTime (microseconds); DateTimeOffset isn't ported.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/Resolvers.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/ZonedDateTimeTest.generated.dart' as scenarios;

/// Changes from UTC+3 to UTC+4 at 1am local time on June 13th 2011.
final SingleTransitionDateTimeZone SampleZone = SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 3, 4);

void main() {
  port(scenarios.fixture, {
    'SimpleProperties': (args) {
      var value = SampleZone.AtStrictly(LocalDateTime(2012, 2, 10, 8, 9, 10).PlusNanoseconds(123456789));
      Assert.AreEqual(LocalDate(2012, 2, 10), value.Date);
      Assert.AreEqual(LocalTime.FromHourMinuteSecondNanosecond(8, 9, 10, 123456789), value.TimeOfDay);
      Assert.AreEqual(Era.Common, value.Era);
      Assert.AreEqual(2012, value.Year);
      Assert.AreEqual(2012, value.YearOfEra);
      Assert.AreEqual(2, value.Month);
      Assert.AreEqual(10, value.Day);
      Assert.AreEqual(IsoDayOfWeek.Friday, value.DayOfWeek);
      Assert.AreEqual(41, value.DayOfYear);
      Assert.AreEqual(8, value.ClockHourOfHalfDay);
      Assert.AreEqual(8, value.Hour);
      Assert.AreEqual(9, value.Minute);
      Assert.AreEqual(10, value.Second);
      Assert.AreEqual(123, value.Millisecond);
      Assert.AreEqual(1234567, value.TickOfSecond);
      Assert.AreEqual(
          8 * NodaConstants.TicksPerHour +
              9 * NodaConstants.TicksPerMinute +
              10 * NodaConstants.TicksPerSecond +
              1234567,
          value.TickOfDay);
      Assert.AreEqual(
          8 * NodaConstants.NanosecondsPerHour +
              9 * NodaConstants.NanosecondsPerMinute +
              10 * NodaConstants.NanosecondsPerSecond +
              123456789,
          value.NanosecondOfDay);
    },
    'Add_AroundTimeZoneTransition': (args) {
      // Before the transition at 3pm...
      ZonedDateTime before = SampleZone.AtStrictly(LocalDateTime(2011, 6, 12, 15, 0));
      // 24 hours elapsed, and it's 4pm
      ZonedDateTime afterExpected = SampleZone.AtStrictly(LocalDateTime(2011, 6, 13, 16, 0));
      ZonedDateTime afterAdd = ZonedDateTime.Add(before, Duration.OneDay);
      ZonedDateTime afterOperator = before + Duration.OneDay;

      Assert.AreEqual(afterExpected, afterAdd);
      Assert.AreEqual(afterExpected, afterOperator);
    },
    'Add_MethodEquivalents': (args) {
      const int minutes = 23;
      const int hours = 3;
      const int milliseconds = 40000;
      const int seconds = 321;
      const int nanoseconds = 12345;
      const int ticks = 5432112345;

      ZonedDateTime before = SampleZone.AtStrictly(LocalDateTime(2011, 6, 12, 15, 0));
      Assert.AreEqual(before + Duration.OneDay, ZonedDateTime.Add(before, Duration.OneDay));
      Assert.AreEqual(before + Duration.OneDay, before.Plus(Duration.OneDay));

      Assert.AreEqual(before + Duration.FromHours(hours), before.PlusHours(hours));
      Assert.AreEqual(before + Duration.FromHours(-hours), before.PlusHours(-hours));

      Assert.AreEqual(before + Duration.FromMinutes(minutes), before.PlusMinutes(minutes));
      Assert.AreEqual(before + Duration.FromMinutes(-minutes), before.PlusMinutes(-minutes));

      Assert.AreEqual(before + Duration.FromSeconds(seconds), before.PlusSeconds(seconds));
      Assert.AreEqual(before + Duration.FromSeconds(-seconds), before.PlusSeconds(-seconds));

      Assert.AreEqual(before + Duration.FromMilliseconds(milliseconds), before.PlusMilliseconds(milliseconds));
      Assert.AreEqual(before + Duration.FromMilliseconds(-milliseconds), before.PlusMilliseconds(-milliseconds));

      Assert.AreEqual(before + Duration.FromTicks(ticks), before.PlusTicks(ticks));
      Assert.AreEqual(before + Duration.FromTicks(-ticks), before.PlusTicks(-ticks));

      Assert.AreEqual(before + Duration.FromNanoseconds(nanoseconds), before.PlusNanoseconds(nanoseconds));
      Assert.AreEqual(before + Duration.FromNanoseconds(-nanoseconds), before.PlusNanoseconds(-nanoseconds));
    },
    'Subtract_AroundTimeZoneTransition': (args) {
      // After the transition at 4pm...
      ZonedDateTime after = SampleZone.AtStrictly(LocalDateTime(2011, 6, 13, 16, 0));
      // 24 hours earlier, and it's 3pm
      ZonedDateTime beforeExpected = SampleZone.AtStrictly(LocalDateTime(2011, 6, 12, 15, 0));
      ZonedDateTime beforeSubtract = ZonedDateTime.Subtract(after, Duration.OneDay);
      ZonedDateTime beforeOperator = after - Duration.OneDay;

      Assert.AreEqual(beforeExpected, beforeSubtract);
      Assert.AreEqual(beforeExpected, beforeOperator);
    },
    'SubtractDuration_MethodEquivalents': (args) {
      ZonedDateTime after = SampleZone.AtStrictly(LocalDateTime(2011, 6, 13, 16, 0));
      Assert.AreEqual(after - Duration.OneDay, ZonedDateTime.Subtract(after, Duration.OneDay));
      Assert.AreEqual(after - Duration.OneDay, after.Minus(Duration.OneDay));
    },
    'Subtraction_ZonedDateTime': (args) {
      // Test all three approaches... not bothering to check a different calendar,
      // but we'll use two different time zones.
      ZonedDateTime start = LocalDateTime(2014, 08, 14, 5, 51).InUtc();
      // Sample zone is UTC+4 at this point, so this is 14:00Z.
      ZonedDateTime end = SampleZone.AtStrictly(LocalDateTime(2014, 08, 14, 18, 0));
      Duration expected = Duration.FromHours(8) + Duration.FromMinutes(9);
      // noda_dart: end - start (C#'s operator) is MinusZonedDateTime.
      Assert.AreEqual(expected, end.MinusZonedDateTime(start));
      Assert.AreEqual(expected, end.MinusZonedDateTime(start));
      Assert.AreEqual(expected, ZonedDateTime.SubtractZonedDateTime(end, start));
    },
    'WithZone': (args) {
      Instant instant = Instant.FromUtc(2012, 2, 4, 12, 35);
      ZonedDateTime zoned = ZonedDateTime(instant, SampleZone);
      Assert.AreEqual(LocalDateTime(2012, 2, 4, 16, 35, 0), zoned.LocalDateTime);

      // Will be UTC-8 for our instant.
      DateTimeZone newZone = SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), -7, -8);
      ZonedDateTime converted = zoned.WithZone(newZone);
      Assert.AreEqual(LocalDateTime(2012, 2, 4, 4, 35, 0), converted.LocalDateTime);
      Assert.AreEqual(converted.ToInstant(), instant);
    },
    'IsDaylightSavings': (args) {
      // Use a real time zone rather than a single-transition zone, so that we can get
      // a savings offset.
      var zone = DateTimeZoneProviders.Tzdb['Europe/London'];
      var winterSummerTransition = Instant.FromUtc(2014, 3, 30, 1, 0);
      var winter = (winterSummerTransition.MinusDuration(Duration.Epsilon)).InZone(zone);
      var summer = winterSummerTransition.InZone(zone);
      Assert.IsFalse(winter.IsDaylightSavingTime());
      Assert.IsTrue(summer.IsDaylightSavingTime());
    },
    'ToBclTypes_DateOutOfRange': (args) {
      // One day before 1st January, 1AD (which is DateTime.MinValue)
      var offset = Offset.FromHours(1);
      var zone = DateTimeZone.ForOffset(offset);
      var odt = LocalDate(1, 1, 1).PlusDays(-1).AtMidnight().InZoneStrictly(zone);
      // Not ported: Assert.Throws<InvalidOperationException>(() => odt.ToDateTimeOffset()) (Dart has no DateTimeOffset).
      Assert.Throws<StateError>(() => odt.ToDateTimeUnspecified());
      Assert.Throws<StateError>(() => odt.ToDateTimeUtc());
    },
    'ToBclTypes_TruncateNanosTowardStartOfTime': (args) {
      final [int year] = args;
      var zone = DateTimeZone.ForOffset(Offset.FromHours(1));
      var zdt = LocalDateTime(year, 1, 1, 13, 15, 55)
          .PlusNanoseconds(NodaConstants.NanosecondsPerSecond - 1)
          .InZoneStrictly(zone);
          // noda_dart: truncated to the microsecond, as ToDateTimeUtc does.
      var expectedDateTimeUtc = core.DateTime.utc(year, 1, 1, 12, 15, 55)
          .add(core.Duration(microseconds: (NodaConstants.TicksPerSecond - 1) ~/ 10));
      var actualDateTimeUtc = zdt.ToDateTimeUtc();
      Assert.AreEqual(expectedDateTimeUtc, actualDateTimeUtc);
      // Not ported: the same check with DateTimeOffset (ToDateTimeOffset; Dart has no DateTimeOffset).
    },
    'ToDateTimeUtc': (args) {
      ZonedDateTime zoned = SampleZone.AtStrictly(LocalDateTime(2011, 3, 5, 1, 0, 0));
      // Note that this is 10pm the previous day, UTC - so 1am local time
      core.DateTime expected = core.DateTime.utc(2011, 3, 4, 22, 0, 0);
      core.DateTime actual = zoned.ToDateTimeUtc();
      Assert.AreEqual(expected, actual);
      // Kind isn't checked by Equals...
      Assert.AreEqual(true, actual.isUtc);
    },
    'ToDateTimeUtc_InRangeAfterUtcAdjustment': (args) {
      var zone = DateTimeZone.ForOffset(Offset.FromHours(-1));
      var zdt = LocalDateTime(0, 12, 31, 23, 30).InZoneStrictly(zone);
      // Sanity check: without reversing the offset, we're out of range
      Assert.Throws<StateError>(() => zdt.ToDateTimeUnspecified());
      // Not ported: Assert.Throws<InvalidOperationException>(() => zdt.ToDateTimeOffset()) (Dart has no DateTimeOffset).
      var expected = core.DateTime.utc(1, 1, 1, 0, 30, 0);
      var actual = zdt.ToDateTimeUtc();
      Assert.AreEqual(expected, actual);
    },
    'ToDateTimeUnspecified': (args) {
      ZonedDateTime zoned = SampleZone.AtStrictly(LocalDateTime(2011, 3, 5, 1, 0, 0));
      core.DateTime expected = core.DateTime(2011, 3, 5, 1, 0, 0);
      core.DateTime actual = zoned.ToDateTimeUnspecified();
      Assert.AreEqual(expected, actual);
      // Kind isn't checked by Equals...
      Assert.AreEqual(false, actual.isUtc);
    },
    'ToDateTimeUnspecified_JulianCalendar': (args) {
      // Non-Gregorian calendar systems are handled by converting to the same
      // date, just like the DateTime constructor does.
      ZonedDateTime zoned = SampleZone.AtStrictly(
          LocalDateTime.YearMonthDayHourMinuteSecondCalendar(2011, 3, 5, 1, 0, 0, CalendarSystem.Julian));
          // noda_dart: Dart's DateTime is Gregorian: Julian 2011-03-05 is 2011-03-18.
      core.DateTime expected = core.DateTime(2011, 3, 18, 1, 0, 0, 0);
      core.DateTime actual = zoned.ToDateTimeUnspecified();
      Assert.AreEqual(expected, actual);
      // Kind isn't checked by Equals...
      Assert.AreEqual(false, actual.isUtc);
    },
    'ToOffsetDateTime': (args) {
      var local = LocalDateTime(1911, 3, 5, 1, 0, 0); // Early interval
      var zoned = SampleZone.AtStrictly(local);
      var offsetDateTime = zoned.ToOffsetDateTime();
      Assert.AreEqual(local, offsetDateTime.LocalDateTime);
      Assert.AreEqual(SampleZone.EarlyInterval.WallOffset, offsetDateTime.Offset);
    },
    'Equality': (args) {
      // Goes back from 2am to 1am on June 13th
      SingleTransitionDateTimeZone zone = SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);
      var sample = zone.MapLocal(LocalDateTime(2011, 6, 13, 1, 30)).First();
      var fromUtc = Instant.FromUtc(2011, 6, 12, 21, 30).InZone(zone);

      // Checks all the overloads etc: first check is that the zone matters
      TestHelper.TestEqualsStruct(sample, fromUtc, [Instant.FromUtc(2011, 6, 12, 21, 30).InUtc()]);
      TestHelper.TestOperatorEquality(sample, fromUtc, Instant.FromUtc(2011, 6, 12, 21, 30).InUtc());

      // Now just use a simple inequality check for other aspects...

      // Different offset
      var later = zone.MapLocal(LocalDateTime(2011, 6, 13, 1, 30)).Last();
      Assert.AreEqual(sample.LocalDateTime, later.LocalDateTime);
      Assert.AreNotEqual(sample.Offset, later.Offset);
      Assert.AreNotEqual(sample, later);

      // Different local time
      Assert.AreNotEqual(sample, zone.MapLocal(LocalDateTime(2011, 6, 13, 1, 29)).First());

      // Different calendar
      var withOtherCalendar =
          zone.MapLocal(LocalDateTime.YearMonthDayHourMinuteCalendar(2011, 6, 13, 1, 30, CalendarSystem.Gregorian))
              .First();
      Assert.AreNotEqual(sample, withOtherCalendar);
    },
    'Construct_FromLocal_ValidUnambiguousOffset': (args) {
      SingleTransitionDateTimeZone zone = SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

      LocalDateTime local = LocalDateTime(2000, 1, 2, 3, 4, 5);
      ZonedDateTime zoned = ZonedDateTime.LocalDateTimeZoneOffset(local, zone, zone.EarlyInterval.WallOffset);
      Assert.AreEqual(zoned, local.InZoneStrictly(zone));
    },
    'Construct_FromLocal_ValidEarlierOffset': (args) {
      SingleTransitionDateTimeZone zone = SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

      LocalDateTime local = LocalDateTime(2011, 6, 13, 1, 30);
      ZonedDateTime zoned = ZonedDateTime.LocalDateTimeZoneOffset(local, zone, zone.EarlyInterval.WallOffset);

      // Map the local time to the earlier of the offsets in a way which is tested elsewhere.
      var resolver = Resolvers.CreateMappingResolver(Resolvers.ReturnEarlier, Resolvers.ThrowWhenSkipped);
      Assert.AreEqual(zoned, local.InZone(zone, resolver));
    },
    'Construct_FromLocal_ValidLaterOffset': (args) {
      SingleTransitionDateTimeZone zone = SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

      LocalDateTime local = LocalDateTime(2011, 6, 13, 1, 30);
      ZonedDateTime zoned = ZonedDateTime.LocalDateTimeZoneOffset(local, zone, zone.LateInterval.WallOffset);

      // Map the local time to the later of the offsets in a way which is tested elsewhere.
      var resolver = Resolvers.CreateMappingResolver(Resolvers.ReturnLater, Resolvers.ThrowWhenSkipped);
      Assert.AreEqual(zoned, local.InZone(zone, resolver));
    },
    'Construct_FromLocal_InvalidOffset': (args) {
      SingleTransitionDateTimeZone zone = SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

      // Attempt to ask for the later offset in the earlier interval
      LocalDateTime local = LocalDateTime(2000, 1, 1, 0, 0, 0);
      Assert.Throws<ArgumentError>(
          () => ZonedDateTime.LocalDateTimeZoneOffset(local, zone, zone.LateInterval.WallOffset));
    },
    'ZonedDateTime_ToString': (args) {
      var local = LocalDateTime(2013, 7, 23, 13, 05, 20);
      ZonedDateTime zoned = local.InZoneStrictly(SampleZone);
      Assert.AreEqual('2013-07-23T13:05:20 Single (+04)', zoned.toString());
    },
    'ZonedDateTime_ToString_WithFormat': (args) {
      var local = LocalDateTime(2013, 7, 23, 13, 05, 20);
      ZonedDateTime zoned = local.InZoneStrictly(SampleZone);
      Assert.AreEqual('2013/07/23 13:05:20 Single',
          zoned.ToStringPattern('uuuu/MM/dd HH:mm:ss z', NodaCultureInfo.InvariantCulture));
    },
    'LocalComparer': (args) {
      var london = DateTimeZoneProviders.Tzdb['Europe/London'];
      var losAngeles = DateTimeZoneProviders.Tzdb['America/Los_Angeles'];

      // LA is 8 hours behind London. So the London evening occurs before the LA afternoon.
      var londonEvening = LocalDateTime(2014, 7, 9, 20, 32).InZoneStrictly(london);
      var losAngelesAfternoon = LocalDateTime(2014, 7, 9, 14, 0).InZoneStrictly(losAngeles);

      // Same local time as losAngelesAfternoon
      var londonAfternoon = losAngelesAfternoon.LocalDateTime.InZoneStrictly(london);

      var londonPersian = londonEvening.LocalDateTime.WithCalendar(CalendarSystem.PersianSimple).InZoneStrictly(london);

      var comparer = ZonedDateTimeComparer.Local;
      TestHelper.TestComparerStruct(comparer, losAngelesAfternoon, londonAfternoon, londonEvening);
      Assert.Throws<ArgumentError>(() => comparer.Compare(londonPersian, londonEvening));
      Assert.IsFalse(comparer.Equals(londonPersian, londonEvening));
      Assert.AreNotEqual(comparer.GetHashCode(londonPersian), comparer.GetHashCode(londonEvening));
      Assert.IsFalse(comparer.Equals(londonAfternoon, londonEvening));
      Assert.AreNotEqual(comparer.GetHashCode(londonAfternoon), comparer.GetHashCode(londonEvening));
      Assert.IsTrue(comparer.Equals(londonAfternoon, losAngelesAfternoon));
      Assert.AreEqual(comparer.GetHashCode(londonAfternoon), comparer.GetHashCode(losAngelesAfternoon));
    },
    'InstantComparer': (args) {
      var london = DateTimeZoneProviders.Tzdb['Europe/London'];
      var losAngeles = DateTimeZoneProviders.Tzdb['America/Los_Angeles'];

      // LA is 8 hours behind London. So the London evening occurs before the LA afternoon.
      var londonEvening = LocalDateTime(2014, 7, 9, 20, 32).InZoneStrictly(london);
      var losAngelesAfternoon = LocalDateTime(2014, 7, 9, 14, 0).InZoneStrictly(losAngeles);

      // Same instant as londonEvening
      var losAngelesLunchtime = LocalDateTime(2014, 7, 9, 12, 32).InZoneStrictly(losAngeles);

      var londonPersian = londonEvening.LocalDateTime.WithCalendar(CalendarSystem.PersianSimple).InZoneStrictly(london);

      var comparer = ZonedDateTimeComparer.Instant;
      TestHelper.TestComparerStruct(comparer, londonEvening, losAngelesLunchtime, losAngelesAfternoon);
      Assert.AreEqual(0, comparer.Compare(londonPersian, londonEvening));
      Assert.IsTrue(comparer.Equals(londonPersian, londonEvening));
      Assert.AreEqual(comparer.GetHashCode(londonPersian), comparer.GetHashCode(londonEvening));
      Assert.IsTrue(comparer.Equals(losAngelesLunchtime, londonEvening));
      Assert.AreEqual(comparer.GetHashCode(losAngelesLunchtime), comparer.GetHashCode(londonEvening));
      Assert.IsFalse(comparer.Equals(losAngelesAfternoon, londonEvening));
      Assert.AreNotEqual(comparer.GetHashCode(losAngelesAfternoon), comparer.GetHashCode(londonEvening));
    },
    'Deconstruction': (args) {
      var saoPaulo = DateTimeZoneProviders.Tzdb['America/Sao_Paulo'];
      ZonedDateTime value = LocalDateTime(2017, 10, 15, 21, 30, 15).InZoneStrictly(saoPaulo);
      var expectedDateTime = LocalDateTime(2017, 10, 15, 21, 30, 15);
      var expectedZone = saoPaulo;
      var expectedOffset = Offset.FromHours(-2);

      var (actualDateTime, actualZone, actualOffset) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(expectedDateTime, actualDateTime);
        Assert.AreEqual(expectedZone, actualZone);
        Assert.AreEqual(expectedOffset, actualOffset);
      });
    },
  }, skip: {
    'FromDateTimeOffset': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_JulianCalendar': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_TruncatedOffset': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_OffsetOutOfRange': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_OffsetEdgeOfRange': SkipReasons.DateTimeOffset,
    'Constructor_ArgumentValidation':
        "null safety: the zone parameter is non-nullable, and the calendar parameter is optional in Dart (null means ISO)",
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization_Iso': SkipReasons.Xml,
    'XmlSerialization_Bcl': SkipReasons.Xml,
    'XmlSerialization_NonIso': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  });
}
