// Ported from NodaTime 6e024dde: src/NodaTime.Test/OffsetDateTimeTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: DateTimeOffset isn't ported.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateAdjusters.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetDate.dart';
import 'package:noda_dart/src/OffsetDateTime.dart';
import 'package:noda_dart/src/OffsetTime.dart';
import 'package:noda_dart/src/TimeAdjusters.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/OffsetDateTimeTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'LocalDateTimeProperties': (args) {
      LocalDateTime local =
          LocalDateTime.YearMonthDayHourMinuteSecondCalendar(2012, 6, 19, 1, 2, 3, CalendarSystem.Julian)
              .PlusNanoseconds(123456789);
      Offset offset = Offset.FromHours(5);

      OffsetDateTime odt = OffsetDateTime(local, offset);

          // noda_dart: no reflection: the properties are listed by hand.
      var localDateTimeProperties = <String, Object? Function(LocalDateTime)>{
        'Calendar': (x) => x.Calendar,
        'Year': (x) => x.Year,
        'YearOfEra': (x) => x.YearOfEra,
        'Era': (x) => x.Era,
        'Month': (x) => x.Month,
        'DayOfYear': (x) => x.DayOfYear,
        'Day': (x) => x.Day,
        'DayOfWeek': (x) => x.DayOfWeek,
        'Hour': (x) => x.Hour,
        'ClockHourOfHalfDay': (x) => x.ClockHourOfHalfDay,
        'Minute': (x) => x.Minute,
        'Second': (x) => x.Second,
        'Millisecond': (x) => x.Millisecond,
        'TickOfSecond': (x) => x.TickOfSecond,
        'TickOfDay': (x) => x.TickOfDay,
        'NanosecondOfSecond': (x) => x.NanosecondOfSecond,
        'NanosecondOfDay': (x) => x.NanosecondOfDay,
        'TimeOfDay': (x) => x.TimeOfDay,
        'Date': (x) => x.Date,
      };
      var offsetDateTimeProperties = <String, Object? Function(OffsetDateTime)>{
        'Calendar': (x) => x.Calendar,
        'Year': (x) => x.Year,
        'Month': (x) => x.Month,
        'Day': (x) => x.Day,
        'YearMonthDay': (x) => x.YearMonthDay,
        'DayOfWeek': (x) => x.DayOfWeek,
        'YearOfEra': (x) => x.YearOfEra,
        'Era': (x) => x.Era,
        'DayOfYear': (x) => x.DayOfYear,
        'Hour': (x) => x.Hour,
        'ClockHourOfHalfDay': (x) => x.ClockHourOfHalfDay,
        'Minute': (x) => x.Minute,
        'Second': (x) => x.Second,
        'Millisecond': (x) => x.Millisecond,
        'TickOfSecond': (x) => x.TickOfSecond,
        'TickOfDay': (x) => x.TickOfDay,
        'NanosecondOfSecond': (x) => x.NanosecondOfSecond,
        'NanosecondOfDay': (x) => x.NanosecondOfDay,
        'LocalDateTime': (x) => x.LocalDateTime,
        'Date': (x) => x.Date,
        'TimeOfDay': (x) => x.TimeOfDay,
        'Offset': (x) => x.Offset,
      };
      var localDateTimePropertyNames = localDateTimeProperties.keys.toList();
      var commonProperties = offsetDateTimeProperties.entries.where((p) => localDateTimePropertyNames.contains(p.key));
      for (var property in commonProperties) {
        Assert.AreEqual(localDateTimeProperties[property.key]!(local), property.value(odt));
      }
    },
    'OffsetProperty': (args) {
      Offset offset = Offset.FromHours(5);

      OffsetDateTime odt = OffsetDateTime(LocalDateTime(2012, 1, 2, 3, 4), offset);
      Assert.AreEqual(offset, odt.Offset);
    },
    'LocalDateTimeProperty': (args) {
      LocalDateTime local =
          LocalDateTime.YearMonthDayHourMinuteSecondCalendar(2012, 6, 19, 1, 2, 3, CalendarSystem.Julian)
              .PlusNanoseconds(123456789);
      Offset offset = Offset.FromHours(5);

      OffsetDateTime odt = OffsetDateTime(local, offset);
      Assert.AreEqual(local, odt.LocalDateTime);
    },
    'ToInstant': (args) {
      Instant instant = Instant.FromUtc(2012, 6, 25, 16, 5, 20);
      LocalDateTime local = LocalDateTime(2012, 6, 25, 21, 35, 20);
      Offset offset = Offset.FromHoursAndMinutes(5, 30);

      OffsetDateTime odt = OffsetDateTime(local, offset);
      Assert.AreEqual(instant, odt.ToInstant());
    },
    'Equality': (args) {
      LocalDateTime local1 = LocalDateTime(2012, 10, 6, 1, 2, 3);
      LocalDateTime local2 = LocalDateTime(2012, 9, 5, 1, 2, 3);
      Offset offset1 = Offset.FromHours(1);
      Offset offset2 = Offset.FromHours(2);

      OffsetDateTime equal1 = OffsetDateTime(local1, offset1);
      OffsetDateTime equal2 = OffsetDateTime(local1, offset1);
      OffsetDateTime unequalByOffset = OffsetDateTime(local1, offset2);
      OffsetDateTime unequalByLocal = OffsetDateTime(local2, offset1);

      TestHelper.TestEqualsStruct(equal1, equal2, [unequalByOffset]);
      TestHelper.TestEqualsStruct(equal1, equal2, [unequalByLocal]);

      TestHelper.TestOperatorEquality(equal1, equal2, unequalByOffset);
      TestHelper.TestOperatorEquality(equal1, equal2, unequalByLocal);
    },
    'InFixedZone': (args) {
      Offset offset = Offset.FromHours(5);
      LocalDateTime local = LocalDateTime(2012, 1, 2, 3, 4);
      OffsetDateTime odt = OffsetDateTime(local, offset);

      ZonedDateTime zoned = odt.InFixedZone();
      Assert.AreEqual(DateTimeZone.ForOffset(offset).AtStrictly(local), zoned);
    },
    'ToString_WholeHourOffset': (args) {
      LocalDateTime local = LocalDateTime(2012, 10, 6, 1, 2, 3);
      Offset offset = Offset.FromHours(1);
      OffsetDateTime odt = OffsetDateTime(local, offset);
      Assert.AreEqual('2012-10-06T01:02:03+01', odt.toString());
    },
    'ToString_PartHourOffset': (args) {
      LocalDateTime local = LocalDateTime(2012, 10, 6, 1, 2, 3);
      Offset offset = Offset.FromHoursAndMinutes(1, 30);
      OffsetDateTime odt = OffsetDateTime(local, offset);
      Assert.AreEqual('2012-10-06T01:02:03+01:30', odt.toString());
    },
    'ToString_Utc': (args) {
      LocalDateTime local = LocalDateTime(2012, 10, 6, 1, 2, 3);
      OffsetDateTime odt = OffsetDateTime(local, Offset.Zero);
      Assert.AreEqual('2012-10-06T01:02:03Z', odt.toString());
    },
    'ToString_WithFormat': (args) {
      LocalDateTime local = LocalDateTime(2012, 10, 6, 1, 2, 3);
      Offset offset = Offset.FromHours(1);
      OffsetDateTime odt = OffsetDateTime(local, offset);
      Assert.AreEqual('2012/10/06 01:02:03 01',
          odt.ToStringPattern('uuuu/MM/dd HH:mm:ss o<-HH>', NodaCultureInfo.InvariantCulture));
    },
    'LocalComparer': (args) {
      var localControl = LocalDateTime(2013, 4, 2, 19, 54);
      var control = OffsetDateTime(localControl, Offset.Zero);
      var negativeOffset = control.LocalDateTime.WithOffset(Offset.FromHours(-1));
      var positiveOffset = control.LocalDateTime.WithOffset(Offset.FromHours(1));
      var differentCalendar = control.LocalDateTime.WithCalendar(CalendarSystem.Coptic).WithOffset(Offset.FromHours(5));
      // Later instant, earlier local
      var earlierLocal = control.LocalDateTime.PlusHours(-2).WithOffset(Offset.FromHours(-10));
      // Same offset, previous day
      var muchEarlierLocal = control.PlusHours(-24);
      // Earlier instant, later local
      var laterLocal = control.LocalDateTime.PlusHours(2).WithOffset(Offset.FromHours(10));
      // Same offset, next day
      var muchLaterLocal = control.PlusHours(24);

      var comparer = OffsetDateTimeComparer.Local;

      Assert.AreEqual(0, comparer.Compare(control, negativeOffset));
      Assert.AreEqual(0, comparer.Compare(control, positiveOffset));
      Assert.Throws<ArgumentError>(() => comparer.Compare(control, differentCalendar));
      Assert.AreEqual(1, comparer.Compare(control, earlierLocal).sign);
      Assert.AreEqual(1, comparer.Compare(control, muchEarlierLocal).sign);
      Assert.AreEqual(-1, comparer.Compare(earlierLocal, control).sign);
      Assert.AreEqual(-1, comparer.Compare(muchEarlierLocal, control).sign);
      Assert.AreEqual(-1, comparer.Compare(control, laterLocal).sign);
      Assert.AreEqual(-1, comparer.Compare(control, muchLaterLocal).sign);
      Assert.AreEqual(1, comparer.Compare(laterLocal, control).sign);
      Assert.AreEqual(1, comparer.Compare(muchLaterLocal, control).sign);

      Assert.IsFalse(comparer.Equals(control, differentCalendar));
      Assert.IsFalse(comparer.Equals(control, earlierLocal));
      Assert.IsFalse(comparer.Equals(control, muchEarlierLocal));
      Assert.IsFalse(comparer.Equals(control, laterLocal));
      Assert.IsFalse(comparer.Equals(control, muchLaterLocal));
      Assert.IsTrue(comparer.Equals(control, control));

      Assert.AreEqual(comparer.GetHashCode(control), comparer.GetHashCode(negativeOffset));
      Assert.AreEqual(comparer.GetHashCode(control), comparer.GetHashCode(positiveOffset));
      Assert.AreNotEqual(comparer.GetHashCode(control), comparer.GetHashCode(earlierLocal));
      Assert.AreNotEqual(comparer.GetHashCode(control), comparer.GetHashCode(muchEarlierLocal));
      Assert.AreNotEqual(comparer.GetHashCode(control), comparer.GetHashCode(laterLocal));
      Assert.AreNotEqual(comparer.GetHashCode(control), comparer.GetHashCode(muchLaterLocal));
      Assert.AreNotEqual(comparer.GetHashCode(control), comparer.GetHashCode(differentCalendar));
    },
    'InstantComparer': (args) {
      var localControl = LocalDateTime(2013, 4, 2, 19, 54);
      var control = OffsetDateTime(localControl, Offset.Zero);
      var equalAndOppositeChanges = control.LocalDateTime.PlusHours(1).WithOffset(Offset.FromHours(1));
      var differentCalendar = control.LocalDateTime.WithCalendar(CalendarSystem.Coptic).WithOffset(Offset.Zero);

      // Negative offset means later instant
      var negativeOffset = control.LocalDateTime.WithOffset(Offset.FromHours(-1));
      // Positive offset means earlier instant
      var positiveOffset = control.LocalDateTime.WithOffset(Offset.FromHours(1));

      // Later instant, earlier local
      var earlierLocal = control.LocalDateTime.PlusHours(-2).WithOffset(Offset.FromHours(-10));
      // Earlier instant, later local
      var laterLocal = control.LocalDateTime.PlusHours(2).WithOffset(Offset.FromHours(10));

      var comparer = OffsetDateTimeComparer.Instant;

      Assert.AreEqual(0, comparer.Compare(control, differentCalendar));
      Assert.AreEqual(0, comparer.Compare(control, equalAndOppositeChanges));

      Assert.AreEqual(-1, comparer.Compare(control, negativeOffset).sign);
      Assert.AreEqual(1, comparer.Compare(negativeOffset, control).sign);
      Assert.AreEqual(1, comparer.Compare(control, positiveOffset));
      Assert.AreEqual(-1, comparer.Compare(positiveOffset, control).sign);

      Assert.AreEqual(-1, comparer.Compare(control, earlierLocal).sign);
      Assert.AreEqual(1, comparer.Compare(earlierLocal, control).sign);
      Assert.AreEqual(1, comparer.Compare(control, laterLocal).sign);
      Assert.AreEqual(-1, comparer.Compare(laterLocal, control).sign);

      Assert.IsTrue(comparer.Equals(control, differentCalendar));
      Assert.IsFalse(comparer.Equals(control, earlierLocal));
      Assert.IsTrue(comparer.Equals(control, equalAndOppositeChanges));

      Assert.AreEqual(comparer.GetHashCode(control), comparer.GetHashCode(differentCalendar));
      Assert.AreEqual(comparer.GetHashCode(control), comparer.GetHashCode(equalAndOppositeChanges));
      Assert.AreNotEqual(comparer.GetHashCode(control), comparer.GetHashCode(earlierLocal));
    },
    'Subtraction_Duration': (args) {
      // Test all three approaches... not bothering to check a different calendar,
      // but we'll use two different offsets.
      OffsetDateTime end = LocalDateTime(2014, 08, 14, 15, 0).WithOffset(Offset.FromHours(1));
      Duration duration = Duration.FromHours(8) + Duration.FromMinutes(9);
      OffsetDateTime expected = LocalDateTime(2014, 08, 14, 6, 51).WithOffset(Offset.FromHours(1));
      Assert.AreEqual(expected, end - duration);
      Assert.AreEqual(expected, end.Minus(duration));
      Assert.AreEqual(expected, OffsetDateTime.Subtract(end, duration));
    },
    'Addition_Duration': (args) {
      const int minutes = 23;
      const int hours = 3;
      const int milliseconds = 40000;
      const int seconds = 321;
      const int nanoseconds = 12345;
      const int ticks = 5432112345;

      // Test all three approaches... not bothering to check a different calendar,
      // but we'll use two different offsets.
      OffsetDateTime start = LocalDateTime(2014, 08, 14, 6, 51).WithOffset(Offset.FromHours(1));
      Duration duration = Duration.FromHours(8) + Duration.FromMinutes(9);
      OffsetDateTime expected = LocalDateTime(2014, 08, 14, 15, 0).WithOffset(Offset.FromHours(1));
      Assert.AreEqual(expected, start + duration);
      Assert.AreEqual(expected, start.Plus(duration));
      Assert.AreEqual(expected, OffsetDateTime.Add(start, duration));

      Assert.AreEqual(start + Duration.FromHours(hours), start.PlusHours(hours));
      Assert.AreEqual(start + Duration.FromHours(-hours), start.PlusHours(-hours));

      Assert.AreEqual(start + Duration.FromMinutes(minutes), start.PlusMinutes(minutes));
      Assert.AreEqual(start + Duration.FromMinutes(-minutes), start.PlusMinutes(-minutes));

      Assert.AreEqual(start + Duration.FromSeconds(seconds), start.PlusSeconds(seconds));
      Assert.AreEqual(start + Duration.FromSeconds(-seconds), start.PlusSeconds(-seconds));

      Assert.AreEqual(start + Duration.FromMilliseconds(milliseconds), start.PlusMilliseconds(milliseconds));
      Assert.AreEqual(start + Duration.FromMilliseconds(-milliseconds), start.PlusMilliseconds(-milliseconds));

      Assert.AreEqual(start + Duration.FromTicks(ticks), start.PlusTicks(ticks));
      Assert.AreEqual(start + Duration.FromTicks(-ticks), start.PlusTicks(-ticks));

      Assert.AreEqual(start + Duration.FromNanoseconds(nanoseconds), start.PlusNanoseconds(nanoseconds));
      Assert.AreEqual(start + Duration.FromNanoseconds(-nanoseconds), start.PlusNanoseconds(-nanoseconds));
    },
    'Subtraction_OffsetDateTime': (args) {
      // Test all three approaches... not bothering to check a different calendar,
      // but we'll use two different offsets.
      OffsetDateTime start = LocalDateTime(2014, 08, 14, 6, 51).WithOffset(Offset.FromHours(1));
      OffsetDateTime end = LocalDateTime(2014, 08, 14, 18, 0).WithOffset(Offset.FromHours(4));
      Duration expected = Duration.FromHours(8) + Duration.FromMinutes(9);
      // noda_dart: end - start (C#'s operator) is MinusOffsetDateTime.
      Assert.AreEqual(expected, end.MinusOffsetDateTime(start));
      Assert.AreEqual(expected, end.MinusOffsetDateTime(start));
      Assert.AreEqual(expected, OffsetDateTime.SubtractOffsetDateTime(end, start));
    },
    'WithOffset': (args) {
      LocalDateTime morning = LocalDateTime(2014, 1, 31, 9, 30);
      OffsetDateTime original = OffsetDateTime(morning, Offset.FromHours(-8));
      LocalDateTime evening = LocalDateTime(2014, 1, 31, 19, 30);
      Offset newOffset = Offset.FromHours(2);
      OffsetDateTime expected = OffsetDateTime(evening, newOffset);
      Assert.AreEqual(expected, original.WithOffset(newOffset));
    },
    'WithOffset_CrossDates': (args) {
      OffsetDateTime noon = OffsetDateTime(LocalDateTime(2017, 8, 22, 12, 0, 0), Offset.FromHours(0));
      OffsetDateTime previousNight = noon.WithOffset(Offset.FromHours(-14));
      OffsetDateTime nextMorning = noon.WithOffset(Offset.FromHours(14));
      Assert.AreEqual(LocalDateTime(2017, 8, 21, 22, 0, 0), previousNight.LocalDateTime);
      Assert.AreEqual(LocalDateTime(2017, 8, 23, 2, 0, 0), nextMorning.LocalDateTime);
    },
    'WithOffset_TwoDaysForwardAndBack': (args) {
      // Go from UTC-18 to UTC+18
      OffsetDateTime night = OffsetDateTime(LocalDateTime(2017, 8, 21, 18, 0, 0), Offset.FromHours(-18));
      OffsetDateTime morning = night.WithOffset(Offset.FromHours(18));
      Assert.AreEqual(LocalDateTime(2017, 8, 23, 6, 0, 0), morning.LocalDateTime);
      OffsetDateTime backAgain = morning.WithOffset(Offset.FromHours(-18));
      Assert.AreEqual(night, backAgain);
    },
    'WithCalendar': (args) {
      CalendarSystem julianCalendar = CalendarSystem.Julian;
      OffsetDateTime gregorianEpoch = NodaConstants.UnixEpoch.WithOffset(Offset.Zero);

      OffsetDateTime expected = LocalDate(1969, 12, 19, julianCalendar).AtMidnight().WithOffset(Offset.FromHours(0));
      OffsetDateTime actual = gregorianEpoch.WithCalendar(CalendarSystem.Julian);
      Assert.AreEqual(expected, actual);
    },
    'With_TimeAdjuster': (args) {
      Offset offset = Offset.FromHoursAndMinutes(2, 30);
      OffsetDateTime start = LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789).WithOffset(offset);
      OffsetDateTime expected = LocalDateTime(2014, 6, 27, 12, 15, 8).WithOffset(offset);
      Assert.AreEqual(expected, start.WithTimeAdjuster(TimeAdjusters.TruncateToSecond));
    },
    'With_DateAdjuster': (args) {
      Offset offset = Offset.FromHoursAndMinutes(2, 30);
      OffsetDateTime start = LocalDateTime(2014, 6, 27, 12, 5, 8).PlusNanoseconds(123456789).WithOffset(offset);
      OffsetDateTime expected = LocalDateTime(2014, 6, 30, 12, 5, 8).PlusNanoseconds(123456789).WithOffset(offset);
      Assert.AreEqual(expected, start.With(DateAdjusters.EndOfMonth));
    },
    'InZone': (args) {
      Offset offset = Offset.FromHours(-7);
      OffsetDateTime start = LocalDateTime(2017, 10, 31, 18, 12, 0).WithOffset(offset);
      var zone = DateTimeZoneProviders.Tzdb['Europe/London'];
      var zoned = start.InZone(zone);

      // On October 31st, the UK had already gone back, so the offset is 0.
      // Importantly, it's not the offset of the original OffsetDateTime: we're testing
      // that InZone *doesn't* require that.
      var expected =
          ZonedDateTime.NewOffsetDateTimeZone(LocalDateTime(2017, 11, 1, 1, 12, 0).WithOffset(Offset.Zero), zone);
      Assert.AreEqual(expected, zoned);
    },
    'Deconstruction': (args) {
      var dateTime = LocalDateTime(2017, 10, 15, 21, 30);
      var offset = Offset.FromHours(-2);
      var value = OffsetDateTime(dateTime, offset);

      var (actualDateTime, actualOffset) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(dateTime, actualDateTime);
        Assert.AreEqual(offset, actualOffset);
      });
    },
    'MoreGranularDeconstruction': (args) {
      var date = LocalDate(2017, 10, 15);
      var time = LocalTime(21, 30, 15);
      var offset = Offset.FromHours(-2);

      var value = OffsetDateTime(date.At(time), offset);

      var (actualDate, actualTime, actualOffset) = value.DeconstructLocalDateLocalTimeOffset;

      Assert.Multiple(() {
        Assert.AreEqual(date, actualDate);
        Assert.AreEqual(time, actualTime);
        Assert.AreEqual(offset, actualOffset);
      });
    },
    'ToOffsetDate': (args) {
      var offset = Offset.FromHoursAndMinutes(2, 30);
      var odt = LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789).WithOffset(offset);
      var expected = OffsetDate(LocalDate(2014, 6, 27), offset);
      Assert.AreEqual(expected, odt.ToOffsetDate());
    },
    'ToOffsetTime': (args) {
      var offset = Offset.FromHoursAndMinutes(2, 30);
      var odt = LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789).WithOffset(offset);
      var expected = OffsetTime(LocalTime(12, 15, 8).PlusNanoseconds(123456789), offset);
      Assert.AreEqual(expected, odt.ToOffsetTime());
    },
  }, skip: {
    'ToDateTimeOffset': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_JulianCalendar': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_TruncatedOffset': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_OffsetOutOfRange': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_OffsetEdgeOfRange': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_DateOutOfRange': SkipReasons.DateTimeOffset,
    'ToDateTimeOffset_TruncateNanosTowardStartOfTime': SkipReasons.DateTimeOffset,
    'FromDateTimeOffset': SkipReasons.DateTimeOffset,
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization_Iso': SkipReasons.Xml,
    'XmlSerialization_ZeroOffset': SkipReasons.Xml,
    'XmlSerialization_NonIso': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  });
}
