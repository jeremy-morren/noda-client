// Ported from NodaTime 6e024dde: src/NodaTime.Test/PeriodTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: C#'s object initializers are cascades.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/IslamicEpoch.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicLeapYearPattern.generated.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/PeriodBuilder.dart';
import 'package:noda_dart/src/PeriodUnits.generated.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';
import 'package:noda_dart/src/Text/LocalDateTimePattern.dart';
import 'package:noda_dart/src/Text/LocalTimePattern.dart';
import 'package:noda_dart/src/Text/PeriodPattern.dart';
import 'package:noda_dart/src/Text/YearMonthPattern.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';
import 'package:noda_dart/src/YearMonth.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/PeriodTest.generated.dart' as scenarios;

// June 19th 2010, 2:30:15am
final LocalDateTime TestDateTime1 = LocalDateTime(2010, 6, 19, 2, 30, 15);
// June 19th 2010, 4:45:10am
final LocalDateTime TestDateTime2 = LocalDateTime(2010, 6, 19, 4, 45, 10);
// June 19th 2010
final LocalDate TestDate1 = LocalDate(2010, 6, 19);
// March 1st 2011
final LocalDate TestDate2 = LocalDate(2011, 3, 1);
// March 1st 2012
final LocalDate TestDate3 = LocalDate(2012, 3, 1);

final PeriodUnits HoursMinutesPeriodType = PeriodUnits.Hours | PeriodUnits.Minutes;

// Not ported: AllPeriodUnits (Enum.GetValues; the generated cases of Between_ExtremeValues are its values).

void main() {
  port(scenarios.fixture, {
    'BetweenLocalDateTimes_WithoutSpecifyingUnits_OmitsWeeks': (args) {
      Period actual = Period.Between(LocalDateTime(2012, 2, 21, 0, 0), LocalDateTime(2012, 2, 28, 0, 0));
      Period expected = Period.FromDays(7);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_MovingForwardWithAllFields_GivesExactResult': (args) {
      Period actual = Period.Between(TestDateTime1, TestDateTime2);
      Period expected = Period.FromHours(2) + Period.FromMinutes(14) + Period.FromSeconds(55);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_MovingBackwardWithAllFields_GivesExactResult': (args) {
      Period actual = Period.Between(TestDateTime2, TestDateTime1);
      Period expected = Period.FromHours(-2) + Period.FromMinutes(-14) + Period.FromSeconds(-55);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_MovingForwardWithHoursAndMinutes_RoundsTowardsStart': (args) {
      Period actual = Period.Between(TestDateTime1, TestDateTime2, HoursMinutesPeriodType);
      Period expected = Period.FromHours(2) + Period.FromMinutes(14);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_MovingBackwardWithHoursAndMinutes_RoundsTowardsStart': (args) {
      Period actual = Period.Between(TestDateTime2, TestDateTime1, HoursMinutesPeriodType);
      Period expected = Period.FromHours(-2) + Period.FromMinutes(-14);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_AcrossDays': (args) {
      Period expected = Period.FromHours(23) + Period.FromMinutes(59);
      Period actual = Period.Between(TestDateTime1, TestDateTime1.PlusDays(1).PlusMinutes(-1));
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_AcrossDays_MinutesAndSeconds': (args) {
      Period expected = Period.FromMinutes(24 * 60 - 1) + Period.FromSeconds(59);
      Period actual = Period.Between(
          TestDateTime1, TestDateTime1.PlusDays(1).PlusSeconds(-1), PeriodUnits.Minutes | PeriodUnits.Seconds);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_StartIsLaterDayLaterTime': (args) {
      Period expected = Period.FromDays(-2) + Period.FromHours(-2);
      Period actual = Period.Between(
          LocalDateTime(2000, 1, 7, 10, 0), LocalDateTime(2000, 1, 5, 8, 0), PeriodUnits.Days | PeriodUnits.Hours);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_StartIsLaterDayLaterTime_DaysOnly': (args) {
      Period expected = Period.FromDays(-2);
      Period actual = Period.Between(LocalDateTime(2000, 1, 7, 10, 0), LocalDateTime(2000, 1, 5, 8, 0), PeriodUnits.Days);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_NotInt64Representable': (args) {
      LocalDateTime start = LocalDateTime(-5000, 1, 1, 0, 1, 2, 123);
      LocalDateTime end = LocalDateTime(9000, 1, 1, 1, 2, 3, 456);
      Assert.False((end.ToLocalInstant().TimeSinceLocalEpoch - start.ToLocalInstant().TimeSinceLocalEpoch)
          .IsInt64Representable);

      Period expected = (PeriodBuilder()
            // 365.2425 * 14000 = 5113395
            ..Hours = 5113395 * 24 + 1
            ..Minutes = 1
            ..Seconds = 1
            ..Milliseconds = 333)
          .Build();
      Period actual = Period.Between(start, end, PeriodUnits.AllTimeUnits);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDateTimes_NotInt64Representable_SubsecondUnits': (args) {
      final [PeriodUnits units, int expectedTicks, int expectedNanoseconds] = args;
      var start = LocalDateTime(2000, 1, 1, 0, 0);
      var end = LocalDateTime(2400, 1, 1, 0, 0).PlusNanoseconds(123);
      var expected = (PeriodBuilder()
            ..Hours = 146097 * 24
            ..Ticks = expectedTicks
            ..Nanoseconds = expectedNanoseconds)
          .Build();

      Assert.AreEqual(expected, Period.Between(start, end, units));
      Assert.AreEqual(-expected, Period.Between(end, start, units));
    },

    'BetweenLocalDates_InvalidUnits': (args) {
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(TestDate1, TestDate2, PeriodUnits(0)));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(TestDate1, TestDate2, PeriodUnits(-1)));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(TestDate1, TestDate2, PeriodUnits.AllTimeUnits));
      Assert.Throws<ArgumentError>(
          () => Period.BetweenLocalDate(TestDate1, TestDate2, PeriodUnits.Years | PeriodUnits.Hours));
    },

    'BetweenLocalDates_DifferentCalendarSystems_Throws': (args) {
      LocalDate start = LocalDate(2017, 11, 1, CalendarSystem.Coptic);
      LocalDate end = LocalDate(2017, 11, 5, CalendarSystem.Gregorian);
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(start, end));
    },

    'BetweenLocalDates_SingleUnit': (args) {
      final [String startText, String endText, PeriodUnits units, int expectedValue] = args;
      var start = LocalDatePattern.Iso.Parse(startText).Value;
      var end = LocalDatePattern.Iso.Parse(endText).Value;
      var actual = Period.BetweenLocalDate(start, end, units);
      var expected = (PeriodBuilder()..[units] = expectedValue).Build();
      Assert.AreEqual(expected, actual);
    },

    'DaysBetweenLocalDates_DifferentCalendarsThrows': (args) {
      var start = LocalDate(2020, 6, 13, CalendarSystem.Iso);
      var end = LocalDate(2020, 6, 15, CalendarSystem.Julian);
      Assert.Throws<ArgumentError>(() => Period.DaysBetween(start, end));
    },

    'DaysBetweenLocalDates_SameDatesReturnsZero': (args) {
      var start = LocalDate(2020, 6, 13, CalendarSystem.Iso);
      var end = start;
      var expected = 0;
      var actual = Period.DaysBetween(start, end);
      Assert.AreEqual(expected, actual);
    },

    'DaysBetweenLocalDates': (args) {
      final [String startText, String endText, int expected] = args;
      var start = LocalDatePattern.Iso.Parse(startText).Value;
      var end = LocalDatePattern.Iso.Parse(endText).Value;
      var actual = Period.DaysBetween(start, end);
      Assert.AreEqual(expected, actual);
    },

    'DaysBetweenLocalDates_StartDateGreaterThanEndDate': (args) {
      final [String startText, String endText, int expected] = args;
      var start = LocalDatePattern.Iso.Parse(startText).Value;
      var end = LocalDatePattern.Iso.Parse(endText).Value;
      var actual = Period.DaysBetween(start, end);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingForwardNoLeapYears_WithExactResults': (args) {
      Period actual = Period.BetweenLocalDate(TestDate1, TestDate2);
      Period expected = Period.FromMonths(8) + Period.FromDays(10);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingForwardInLeapYear_WithExactResults': (args) {
      Period actual = Period.BetweenLocalDate(TestDate1, TestDate3);
      Period expected = Period.FromYears(1) + Period.FromMonths(8) + Period.FromDays(11);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingBackwardNoLeapYears_WithExactResults': (args) {
      Period actual = Period.BetweenLocalDate(TestDate2, TestDate1);
      Period expected = Period.FromMonths(-8) + Period.FromDays(-12);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingBackwardInLeapYear_WithExactResults': (args) {
      // This is asymmetric with moving forward, because we first take off a whole year, which
      // takes us to March 1st 2011, then 8 months to take us to July 1st 2010, then 12 days
      // to take us back to June 19th. In this case, the fact that our start date is in a leap
      // year had no effect.
      Period actual = Period.BetweenLocalDate(TestDate3, TestDate1);
      Period expected = Period.FromYears(-1) + Period.FromMonths(-8) + Period.FromDays(-12);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingForward_WithJustMonths': (args) {
      Period actual = Period.BetweenLocalDate(TestDate1, TestDate3, PeriodUnits.Months);
      Period expected = Period.FromMonths(20);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingBackward_WithJustMonths': (args) {
      Period actual = Period.BetweenLocalDate(TestDate3, TestDate1, PeriodUnits.Months);
      Period expected = Period.FromMonths(-20);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_AsymmetricForwardAndBackward': (args) {
      // February 10th 2010
      LocalDate d1 = LocalDate(2010, 2, 10);
      // March 30th 2010
      LocalDate d2 = LocalDate(2010, 3, 30);
      // Going forward, we go to March 10th (1 month) then March 30th (20 days)
      Assert.AreEqual(Period.FromMonths(1) + Period.FromDays(20), Period.BetweenLocalDate(d1, d2));
      // Going backward, we go to February 28th (-1 month, day is rounded) then February 10th (-18 days)
      Assert.AreEqual(Period.FromMonths(-1) + Period.FromDays(-18), Period.BetweenLocalDate(d2, d1));
    },

    'BetweenLocalDates_EndOfMonth': (args) {
      LocalDate d1 = LocalDate(2013, 3, 31);
      LocalDate d2 = LocalDate(2013, 4, 30);
      Assert.AreEqual(Period.FromMonths(1), Period.BetweenLocalDate(d1, d2));
      Assert.AreEqual(Period.FromDays(-30), Period.BetweenLocalDate(d2, d1));
    },

    'BetweenLocalDates_OnLeapYear': (args) {
      LocalDate d1 = LocalDate(2012, 2, 29);
      LocalDate d2 = LocalDate(2013, 2, 28);
      Assert.AreEqual(Period.FromYears(1), Period.BetweenLocalDate(d1, d2));
      // Go back from February 28th 2013 to March 28th 2012, then back 28 days to February 29th 2012
      Assert.AreEqual(Period.FromMonths(-11) + Period.FromDays(-28), Period.BetweenLocalDate(d2, d1));
    },

    'BetweenLocalDates_AfterLeapYear': (args) {
      LocalDate d1 = LocalDate(2012, 3, 5);
      LocalDate d2 = LocalDate(2013, 3, 5);
      Assert.AreEqual(Period.FromYears(1), Period.BetweenLocalDate(d1, d2));
      Assert.AreEqual(Period.FromYears(-1), Period.BetweenLocalDate(d2, d1));
    },

    'BetweenLocalDateTimes_OnLeapYear': (args) {
      LocalDateTime dt1 = LocalDateTime(2012, 2, 29, 2, 0);
      LocalDateTime dt2 = LocalDateTime(2012, 2, 29, 4, 0);
      LocalDateTime dt3 = LocalDateTime(2013, 2, 28, 3, 0);
      Assert.AreEqual(Parse('P1YT1H'), Period.Between(dt1, dt3));
      Assert.AreEqual(Parse('P11M29DT23H'), Period.Between(dt2, dt3));

      Assert.AreEqual(Parse('P-11M-28DT-1H'), Period.Between(dt3, dt1));
      Assert.AreEqual(Parse('P-11M-27DT-23H'), Period.Between(dt3, dt2));
    },

    'BetweenLocalDateTimes_OnLeapYearIslamic': (args) {
      var calendar = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
      Assert.IsTrue(calendar.IsLeapYear(2));
      Assert.IsFalse(calendar.IsLeapYear(3));

      LocalDateTime dt1 = LocalDateTime.YearMonthDayHourMinuteCalendar(2, 12, 30, 2, 0, calendar);
      LocalDateTime dt2 = LocalDateTime.YearMonthDayHourMinuteCalendar(2, 12, 30, 4, 0, calendar);
      LocalDateTime dt3 = LocalDateTime.YearMonthDayHourMinuteCalendar(3, 12, 29, 3, 0, calendar);

      // Adding a year truncates to 0003-12-28T02:00:00, then add an hour.
      Assert.AreEqual(Parse('P1YT1H'), Period.Between(dt1, dt3));
      // Adding a year would overshoot. Adding 11 months takes us to month 03-11-30T04:00.
      // Adding another 28 days takes us to 03-12-28T04:00, then add another 23 hours to finish.
      Assert.AreEqual(Parse('P11M28DT23H'), Period.Between(dt2, dt3));

      // Subtracting 11 months takes us to 03-01-29T03:00. Subtracting another 29 days
      // takes us to 02-12-30T03:00, and another hour to get to the target.
      Assert.AreEqual(Parse('P-11M-29DT-1H'), Period.Between(dt3, dt1));
      Assert.AreEqual(Parse('P-11M-28DT-23H'), Period.Between(dt3, dt2));
    },

    'BetweenLocalDateTimes_InvalidUnits': (args) {
      Assert.Throws<ArgumentError>(() => Period.Between(TestDateTime1, TestDateTime2, PeriodUnits(0)));
      Assert.Throws<ArgumentError>(() => Period.Between(TestDateTime1, TestDateTime2, PeriodUnits(-1)));
    },

    'NanosecondsBetweenLocalTimes': (args) {
      final [LocalTime start, LocalTime end, int expected] = args;
      var actual = Period.NanosecondsBetween(start, end);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalTimes_InvalidUnits': (args) {
      LocalTime t1 = LocalTime(10, 0);
      LocalTime t2 = LocalTime.FromHourMinuteSecondMillisecondTick(15, 30, 45, 20, 5);
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalTime(t1, t2, PeriodUnits(0)));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalTime(t1, t2, PeriodUnits(-1)));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalTime(t1, t2, PeriodUnits.YearMonthDay));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalTime(t1, t2, PeriodUnits.Years | PeriodUnits.Hours));
    },

    'BetweenLocalTimes_SingleUnit': (args) {
      final [String startText, String endText, PeriodUnits units, int expectedValue] = args;
      var start = LocalTimePattern.ExtendedIso.Parse(startText).Value;
      var end = LocalTimePattern.ExtendedIso.Parse(endText).Value;
      var actual = Period.BetweenLocalTime(start, end, units);
      var expected = (PeriodBuilder()..[units] = expectedValue).Build();
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalTimes_MovingForwards': (args) {
      LocalTime t1 = LocalTime(10, 0);
      LocalTime t2 = LocalTime.FromHourMinuteSecondMillisecondTick(15, 30, 45, 20, 5);
      Assert.AreEqual(
          Period.FromHours(5) +
              Period.FromMinutes(30) +
              Period.FromSeconds(45) +
              Period.FromMilliseconds(20) +
              Period.FromTicks(5),
          Period.BetweenLocalTime(t1, t2));
    },

    'BetweenLocalTimes_MovingBackwards': (args) {
      LocalTime t1 = LocalTime.FromHourMinuteSecondMillisecondTick(15, 30, 45, 20, 5);
      LocalTime t2 = LocalTime(10, 0);
      Assert.AreEqual(
          Period.FromHours(-5) +
              Period.FromMinutes(-30) +
              Period.FromSeconds(-45) +
              Period.FromMilliseconds(-20) +
              Period.FromTicks(-5),
          Period.BetweenLocalTime(t1, t2));
    },

    'BetweenLocalTimes_MovingForwards_WithJustHours': (args) {
      LocalTime t1 = LocalTime(11, 30);
      LocalTime t2 = LocalTime(17, 15);
      Assert.AreEqual(Period.FromHours(5), Period.BetweenLocalTime(t1, t2, PeriodUnits.Hours));
    },

    'BetweenLocalTimes_MovingBackwards_WithJustHours': (args) {
      LocalTime t1 = LocalTime(17, 15);
      LocalTime t2 = LocalTime(11, 30);
      Assert.AreEqual(Period.FromHours(-5), Period.BetweenLocalTime(t1, t2, PeriodUnits.Hours));
    },

    'Addition_WithDifferent_PeriodTypes': (args) {
      Period p1 = Period.FromHours(3);
      Period p2 = Period.FromMinutes(20);
      Period sum = p1 + p2;
      Assert.AreEqual(3, sum.Hours);
      Assert.AreEqual(20, sum.Minutes);
    },

    'Addition_MaxAndMinValue': (args) {
      Period p1 = Period.MaxValue;
      Period p2 = Period.MinValue;
      Period sum = p1 + p2;
      Assert.AreEqual(
          Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
              -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
          sum);
    },

    'Addition_With_IdenticalPeriodTypes': (args) {
      Period p1 = Period.FromHours(3);
      Period p2 = Period.FromHours(2);
      Period sum = p1 + p2;
      Assert.AreEqual(5, sum.Hours);
      Assert.AreEqual(sum, Period.Add(p1, p2));
    },

    'Addition_DayCrossingMonthBoundary': (args) {
      LocalDateTime start = LocalDateTime(2010, 2, 20, 10, 0);
      LocalDateTime result = start + Period.FromDays(10);
      Assert.AreEqual(LocalDateTime(2010, 3, 2, 10, 0), result);
    },

    'Addition_OneYearOnLeapDay': (args) {
      LocalDateTime start = LocalDateTime(2012, 2, 29, 10, 0);
      LocalDateTime result = start + Period.FromYears(1);
      // Feb 29th becomes Feb 28th
      Assert.AreEqual(LocalDateTime(2013, 2, 28, 10, 0), result);
    },

    'Addition_FourYearsOnLeapDay': (args) {
      LocalDateTime start = LocalDateTime(2012, 2, 29, 10, 0);
      LocalDateTime result = start + Period.FromYears(4);
      // Feb 29th is still valid in 2016
      Assert.AreEqual(LocalDateTime(2016, 2, 29, 10, 0), result);
    },

    'Addition_YearMonthDay': (args) {
      // One year, one month, two days
      Period period = Period.FromYears(1) + Period.FromMonths(1) + Period.FromDays(2);
      LocalDateTime start = LocalDateTime(2007, 1, 30, 0, 0);
      // Periods are added in order, so this becomes...
      // Add one year: Jan 30th 2008
      // Add one month: Feb 29th 2008
      // Add two days: March 2nd 2008
      // If we added the days first, we'd end up with March 1st instead.
      LocalDateTime result = start + period;
      Assert.AreEqual(LocalDateTime(2008, 3, 2, 0, 0), result);
    },

    'Subtraction_WithDifferent_PeriodTypes': (args) {
      Period p1 = Period.FromHours(3);
      Period p2 = Period.FromMinutes(20);
      Period difference = p1 - p2;
      Assert.AreEqual(3, difference.Hours);
      Assert.AreEqual(-20, difference.Minutes);
      Assert.AreEqual(difference, Period.Subtract(p1, p2));
    },

    'Subtraction_With_IdenticalPeriodTypes': (args) {
      Period p1 = Period.FromHours(3);
      Period p2 = Period.FromHours(2);
      Period difference = p1 - p2;
      Assert.AreEqual(1, difference.Hours);
      Assert.AreEqual(difference, Period.Subtract(p1, p2));
    },

    'UnaryNegation': (args) {
      Period period = Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
          2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
      Period negation = -period;
      Assert.AreEqual(
          Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(
              -2, -3, -4, -5, -6, -7, -8, -9, -10, -11),
          negation);
    },

    'Equality_WhenEqual': (args) {
      Assert.AreEqual(Period.FromHours(10), Period.FromHours(10));
      Assert.AreEqual(Period.FromMinutes(15), Period.FromMinutes(15));
      Assert.AreEqual(Period.FromDays(5), Period.FromDays(5));
    },

    'Equality_WithDifferentPeriodTypes_OnlyConsidersValues': (args) {
      Period allFields = Period.FromMinutes(1) + Period.FromHours(1) - Period.FromMinutes(1);
      Period justHours = Period.FromHours(1);
      Assert.AreEqual(allFields, justHours);
    },

    'Equality_WhenUnequal': (args) {
      Assert.IsFalse(Period.FromHours(10).Equals(Period.FromHours(20)));
      Assert.IsFalse(Period.FromMinutes(15).Equals(Period.FromSeconds(15)));
      Assert.IsFalse(Period.FromHours(1).Equals(Period.FromMinutes(60)));
      // noda_dart: C#'s Equals(object) is Dart's ==.
      Assert.IsFalse(Period.FromHours(1) == Object());
      Assert.IsFalse(Period.FromHours(1).Equals(null));
      Object? nullObject;
      Assert.IsFalse(Period.FromHours(1) == nullObject);
    },

    'EqualityOperators': (args) {
      Period val1 = Period.FromHours(1);
      Period val2 = Period.FromHours(1);
      Period val3 = Period.FromHours(2);
      Period? val4 = NullPeriod();
      Assert.IsTrue(val1 == val2);
      Assert.IsFalse(val1 == val3);
      Assert.IsFalse(val1 == val4);
      Assert.IsFalse(val4 == val1);
      Assert.IsTrue(val4 == null);
      Assert.IsTrue(null == val4);

      Assert.IsFalse(val1 != val2);
      Assert.IsTrue(val1 != val3);
      Assert.IsTrue(val1 != val4);
      Assert.IsTrue(val4 != val1);
      Assert.IsFalse(val4 != null);
      Assert.IsFalse(null != val4);
    },

    'HasTimeComponent_SingleValued': (args) {
      final [PeriodUnits unit, bool hasTimeComponent] = args;
      var period = (PeriodBuilder()..[unit] = 1).Build();
      Assert.AreEqual(hasTimeComponent, period.HasTimeComponent);
    },

    'HasDateComponent_SingleValued': (args) {
      final [PeriodUnits unit, bool hasDateComponent] = args;
      var period = (PeriodBuilder()..[unit] = 1).Build();
      Assert.AreEqual(hasDateComponent, period.HasDateComponent);
    },

    'HasTimeComponent_Compound': (args) {
      LocalDateTime dt1 = LocalDateTime(2000, 1, 1, 10, 45, 00);
      LocalDateTime dt2 = LocalDateTime(2000, 2, 4, 11, 50, 00);

      // Case 1: Entire period is date-based (no time units available)
      Assert.IsFalse(Period.BetweenLocalDate(dt1.Date, dt2.Date).HasTimeComponent);

      // Case 2: Period contains date and time units, but time units are all zero
      Assert.IsFalse(Period.Between(dt1.Date.At(LocalTime.Midnight), dt2.Date.At(LocalTime.Midnight)).HasTimeComponent);

      // Case 3: Entire period is time-based, but 0. (Same local time twice here.)
      Assert.IsFalse(Period.BetweenLocalTime(dt1.TimeOfDay, dt1.TimeOfDay).HasTimeComponent);

      // Case 4: Period contains date and time units, and some time units are non-zero
      Assert.IsTrue(Period.Between(dt1, dt2).HasTimeComponent);

      // Case 5: Entire period is time-based, and some time units are non-zero
      Assert.IsTrue(Period.BetweenLocalTime(dt1.TimeOfDay, dt2.TimeOfDay).HasTimeComponent);
    },

    'HasDateComponent_Compound': (args) {
      LocalDateTime dt1 = LocalDateTime(2000, 1, 1, 10, 45, 00);
      LocalDateTime dt2 = LocalDateTime(2000, 2, 4, 11, 50, 00);

      // Case 1: Entire period is time-based (no date units available)
      Assert.IsFalse(Period.BetweenLocalTime(dt1.TimeOfDay, dt2.TimeOfDay).HasDateComponent);

      // Case 2: Period contains date and time units, but date units are all zero
      Assert.IsFalse(Period.Between(dt1, dt1.Date.At(dt2.TimeOfDay)).HasDateComponent);

      // Case 3: Entire period is date-based, but 0. (Same local date twice here.)
      Assert.IsFalse(Period.BetweenLocalDate(dt1.Date, dt1.Date).HasDateComponent);

      // Case 4: Period contains date and time units, and some date units are non-zero
      Assert.IsTrue(Period.Between(dt1, dt2).HasDateComponent);

      // Case 5: Entire period is date-based, and some time units are non-zero
      Assert.IsTrue(Period.BetweenLocalDate(dt1.Date, dt2.Date).HasDateComponent);
    },

    'ToString_Positive': (args) {
      Period period = Period.FromDays(1) + Period.FromHours(2);
      Assert.AreEqual('P1DT2H', period.toString());
    },

    'ToString_AllUnits': (args) {
      Period period =
          Period.NewYearsMonthsWeeksDaysHoursMinutesSecondsMillisecondsTicksNanoseconds(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
      Assert.AreEqual('P1Y2M3W4DT5H6M7S8s9t10n', period.toString());
    },

    'ToString_Negative': (args) {
      Period period = Period.FromDays(-1) + Period.FromHours(-2);
      Assert.AreEqual('P-1DT-2H', period.toString());
    },

    'ToString_Mixed': (args) {
      Period period = Period.FromDays(-1) + Period.FromHours(2);
      Assert.AreEqual('P-1DT2H', period.toString());
    },

    'ToString_Zero': (args) {
      Assert.AreEqual('P0D', Period.Zero.toString());
    },

    'ToBuilder_SingleUnit': (args) {
      var builder = Period.FromHours(5).ToBuilder();
      var expected = (PeriodBuilder()..Hours = 5).Build();
      Assert.AreEqual(expected, builder.Build());
    },

    'ToBuilder_MultipleUnits': (args) {
      var builder = (Period.FromHours(5) + Period.FromWeeks(2)).ToBuilder();
      var expected = (PeriodBuilder()
            ..Hours = 5
            ..Weeks = 2)
          .Build();
      Assert.AreEqual(expected, builder.Build());
    },

    'Normalize_Weeks': (args) {
      var original = (PeriodBuilder()
            ..Weeks = 2
            ..Days = 5)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()..Days = 19).Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_Hours': (args) {
      var original = (PeriodBuilder()
            ..Hours = 25
            ..Days = 1)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Hours = 1
            ..Days = 2)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_Minutes': (args) {
      var original = (PeriodBuilder()
            ..Hours = 1
            ..Minutes = 150)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Hours = 3
            ..Minutes = 30)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_Seconds': (args) {
      var original = (PeriodBuilder()
            ..Minutes = 1
            ..Seconds = 150)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Minutes = 3
            ..Seconds = 30)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_Milliseconds': (args) {
      var original = (PeriodBuilder()
            ..Seconds = 1
            ..Milliseconds = 1500)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Seconds = 2
            ..Milliseconds = 500)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_Ticks': (args) {
      var original = (PeriodBuilder()
            ..Milliseconds = 1
            ..Ticks = 15000)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Milliseconds = 2
            ..Ticks = 0
            ..Nanoseconds = 500000)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_Nanoseconds': (args) {
      var original = (PeriodBuilder()
            ..Ticks = 1
            ..Nanoseconds = 150)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()..Nanoseconds = 250).Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_MultipleFields': (args) {
      var original = (PeriodBuilder()
            ..Hours = 1
            ..Minutes = 119
            ..Seconds = 150)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Hours = 3
            ..Minutes = 1
            ..Seconds = 30)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_AllNegative': (args) {
      var original = (PeriodBuilder()
            ..Hours = -1
            ..Minutes = -119
            ..Seconds = -150)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Hours = -3
            ..Minutes = -1
            ..Seconds = -30)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_MixedSigns_PositiveResult': (args) {
      var original = (PeriodBuilder()
            ..Hours = 3
            ..Minutes = -1)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Hours = 2
            ..Minutes = 59)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_MixedSigns_NegativeResult': (args) {
      var original = (PeriodBuilder()
            ..Hours = 1
            ..Minutes = -121)
          .Build();
      var normalized = original.Normalize();
      var expected = (PeriodBuilder()
            ..Hours = -1
            ..Minutes = -1)
          .Build();
      Assert.AreEqual(expected, normalized);
    },

    'Normalize_DoesntAffectMonthsAndYears': (args) {
      var original = (PeriodBuilder()
            ..Years = 2
            ..Months = 1
            ..Days = 400)
          .Build();
      Assert.AreEqual(original, original.Normalize());
    },

    'Normalize_ZeroResult': (args) {
      var original = (PeriodBuilder()..Years = 0).Build();
      Assert.AreEqual(Period.Zero, original.Normalize());
    },

    'Normalize_Overflow': (args) {
      Period period = Period.FromHours(Int64.MaxValue);
      Assert.Throws<OverflowException>(() => period.Normalize());
    },

    'ToString_SingleUnit': (args) {
      var period = Period.FromHours(5);
      Assert.AreEqual('PT5H', period.toString());
    },

    'ToString_MultipleUnits': (args) {
      var period = (PeriodBuilder()
            ..Hours = 5
            ..Minutes = 30)
          .Build();
      Assert.AreEqual('PT5H30M', period.toString());
    },

    'ToDuration_InvalidWithYears': (args) {
      Period period = Period.FromYears(1);
      Assert.Throws<StateError>(() => period.ToDuration());
    },

    'ToDuration_InvalidWithMonths': (args) {
      Period period = Period.FromMonths(1);
      Assert.Throws<StateError>(() => period.ToDuration());
    },

    'ToDuration_ValidAllAcceptableUnits': (args) {
      Period period = (PeriodBuilder()
            ..Weeks = 1
            ..Days = 2
            ..Hours = 3
            ..Minutes = 4
            ..Seconds = 5
            ..Milliseconds = 6
            ..Ticks = 7)
          .Build();
      Assert.AreEqual(
          1 * NodaConstants.TicksPerWeek +
              2 * NodaConstants.TicksPerDay +
              3 * NodaConstants.TicksPerHour +
              4 * NodaConstants.TicksPerMinute +
              5 * NodaConstants.TicksPerSecond +
              6 * NodaConstants.TicksPerMillisecond +
              7,
          period.ToDuration().BclCompatibleTicks);
    },

    'ToDuration_ValidWithZeroValuesInMonthYearUnits': (args) {
      Period period = Period.FromMonths(1) + Period.FromYears(1);
      period = period - period + Period.FromDays(1);
      Assert.IsFalse(period.HasTimeComponent);
      Assert.AreEqual(Duration.OneDay, period.ToDuration());
    },

    'ToDuration_Overflow': (args) {
      Period period = Period.FromSeconds(Int64.MaxValue);
      Assert.Throws<OverflowException>(() => period.ToDuration());
    },

    'ToDuration_Overflow_WhenPossiblyValid': (args) {
      // These two should pretty much cancel each other out - and would, if we had a 128-bit integer
      // representation to use.
      Period period = Period.FromSeconds(Int64.MaxValue) + Period.FromMinutes(Int64.MinValue ~/ 60);
      Assert.Throws<OverflowException>(() => period.ToDuration());
    },

    'NormalizingEqualityComparer_NullToNonNull': (args) {
      Period period = Period.FromYears(1);
      Assert.IsFalse(Period.NormalizingEqualityComparer.Equals(period, null));
      Assert.IsFalse(Period.NormalizingEqualityComparer.Equals(null, period));
    },

    'NormalizingEqualityComparer_NullToNull': (args) {
      Assert.IsTrue(Period.NormalizingEqualityComparer.Equals(null, null));
    },

    'NormalizingEqualityComparer_PeriodToItself': (args) {
      Period period = Period.FromYears(1);
      Assert.IsTrue(Period.NormalizingEqualityComparer.Equals(period, period));
    },

    'NormalizingEqualityComparer_NonEqualAfterNormalization': (args) {
      Period period1 = Period.FromHours(2);
      Period period2 = Period.FromMinutes(150);
      Assert.IsFalse(Period.NormalizingEqualityComparer.Equals(period1, period2));
    },

    'NormalizingEqualityComparer_EqualAfterNormalization': (args) {
      Period period1 = Period.FromHours(2);
      Period period2 = Period.FromMinutes(120);
      Assert.IsTrue(Period.NormalizingEqualityComparer.Equals(period1, period2));
    },

    'NormalizingEqualityComparer_GetHashCodeAfterNormalization': (args) {
      Period period1 = Period.FromHours(2);
      Period period2 = Period.FromMinutes(120);
      Assert.AreEqual(Period.NormalizingEqualityComparer.GetHashCode(period1),
          Period.NormalizingEqualityComparer.GetHashCode(period2));
    },

    'Comparer_NullWithNull': (args) {
      var comparer = Period.CreateComparer(LocalDateTime(2000, 1, 1, 0, 0));
      Assert.AreEqual(0, comparer.Compare(null, null));
    },

    'Comparer_NullWithNonNull': (args) {
      var comparer = Period.CreateComparer(LocalDateTime(2000, 1, 1, 0, 0));
      Assert.That(comparer.Compare(null, Period.Zero), Is.LessThan(0));
    },

    'Comparer_NonNullWithNull': (args) {
      var comparer = Period.CreateComparer(LocalDateTime(2000, 1, 1, 0, 0));
      Assert.That(comparer.Compare(Period.Zero, null), Is.GreaterThan(0));
    },

    'Comparer_DurationablePeriods': (args) {
      var bigger = Period.FromHours(25);
      var smaller = Period.FromDays(1);
      var comparer = Period.CreateComparer(LocalDateTime(2000, 1, 1, 0, 0));
      Assert.That(comparer.Compare(bigger, smaller), Is.GreaterThan(0));
      Assert.That(comparer.Compare(smaller, bigger), Is.LessThan(0));
      Assert.AreEqual(0, comparer.Compare(bigger, bigger));
    },

    'Comparer_NonDurationablePeriods': (args) {
      var month = Period.FromMonths(1);
      var days = Period.FromDays(30);
      // At the start of January, a month is longer than 30 days
      var januaryComparer = Period.CreateComparer(LocalDateTime(2000, 1, 1, 0, 0));
      Assert.That(januaryComparer.Compare(month, days), Is.GreaterThan(0));
      Assert.That(januaryComparer.Compare(days, month), Is.LessThan(0));
      Assert.AreEqual(0, januaryComparer.Compare(month, month));

      // At the start of February, a month is shorter than 30 days
      var februaryComparer = Period.CreateComparer(LocalDateTime(2000, 2, 1, 0, 0));
      Assert.That(februaryComparer.Compare(month, days), Is.LessThan(0));
      Assert.That(februaryComparer.Compare(days, month), Is.GreaterThan(0));
      Assert.AreEqual(0, februaryComparer.Compare(month, month));
    },

    /// Ensure that Period.MaxValue and Period.MinValue contain the max/min value assignable to each public property.
    'Period_MaxAndMinValues_AllMembers': (args) {
      final [Period period, int expectedIntValue, int expectedLongValue] = args;
          // noda_dart: no reflection: Period's properties up to HasTimeComponent, in order, with whether each is an int.
      final properties = <(String, Object, bool)>[
        ('Nanoseconds', period.Nanoseconds, false),
        ('Ticks', period.Ticks, false),
        ('Milliseconds', period.Milliseconds, false),
        ('Seconds', period.Seconds, false),
        ('Minutes', period.Minutes, false),
        ('Hours', period.Hours, false),
        ('Days', period.Days, true),
        ('Weeks', period.Weeks, true),
        ('Months', period.Months, true),
        ('Years', period.Years, true),
        ('HasTimeComponent', period.HasTimeComponent, false),
        ('HasDateComponent', period.HasDateComponent, false),
      ];
      for (var (_, actualValue, isInt) in properties) {
        // HasTimeComponent is a public property that will get included in this loop.
        // This block allows us to ignore it.
        if (actualValue is bool) {
          return;
        }

        var expectedValue = isInt ? expectedIntValue : expectedLongValue;
        Assert.AreEqual(expectedValue, actualValue);
      }
    },

    'Between_ExtremeValues': (args) {
      final [PeriodUnits units] = args;
      // We can't use None, and Nanoseconds will *correctly* overflow.
      if (units == PeriodUnits.None || units == PeriodUnits.Nanoseconds) {
        return;
      }
      var minValue = LocalDate.MinIsoValue.At(LocalTime.MinValue);
      var maxValue = LocalDate.MaxIsoValue.At(LocalTime.MaxValue);
      Period.Between(minValue, maxValue, units);
    },

    'Between_ExtremeValues_Overflow': (args) {
      var minValue = LocalDate.MinIsoValue.At(LocalTime.MinValue);
      var maxValue = LocalDate.MaxIsoValue.At(LocalTime.MaxValue);
      Assert.Throws<OverflowException>(() => Period.Between(minValue, maxValue, PeriodUnits.Nanoseconds));
    },

    'Between_LocalDateTime_AwkwardTimeOfDayWithSingleUnit': (args) {
      final [String startText, String endText, PeriodUnits units, int expectedForward, int expectedBackward] = args;
      LocalDateTime start = LocalDateTimePattern.ExtendedIso.Parse(startText).Value;
      LocalDateTime end = LocalDateTimePattern.ExtendedIso.Parse(endText).Value;
      Period forward = Period.Between(start, end, units);
      Assert.AreEqual(expectedForward, forward.ToBuilder()[units]);
      Period backward = Period.Between(end, start, units);
      Assert.AreEqual(expectedBackward, backward.ToBuilder()[units]);
    },

    'Between_LocalDateTime_SameValue': (args) {
      LocalDateTime start = LocalDateTime(2014, 1, 1, 16, 0, 0);
      Assert.AreSame(Period.Zero, Period.Between(start, start));
    },

    'Between_LocalDateTime_AwkwardTimeOfDayWithMultipleUnits': (args) {
      LocalDateTime start = LocalDateTime(2014, 1, 1, 16, 0, 0);
      LocalDateTime end = LocalDateTime(2015, 2, 3, 8, 0, 0);
      Period actual = Period.Between(start, end, PeriodUnits.YearMonthDay | PeriodUnits.AllTimeUnits);
      Period expected = (PeriodBuilder()
            ..Years = 1
            ..Months = 1
            ..Days = 1
            ..Hours = 16)
          .Build();
      Assert.AreEqual(expected, actual);
    },

    'BetweenYearMonth_InvalidUnits': (args) {
      YearMonth yearMonth1 = YearMonth(2010, 1);
      YearMonth yearMonth2 = YearMonth(2011, 3);
      Assert.Throws<ArgumentError>(() => Period.BetweenYearMonth(yearMonth1, yearMonth2, PeriodUnits(0)));
      Assert.Throws<ArgumentError>(() => Period.BetweenYearMonth(yearMonth1, yearMonth2, PeriodUnits(-1)));
      Assert.Throws<ArgumentError>(() => Period.BetweenYearMonth(yearMonth1, yearMonth2, PeriodUnits.AllTimeUnits));
      Assert.Throws<ArgumentError>(() => Period.BetweenYearMonth(yearMonth1, yearMonth2, PeriodUnits.Days));
      Assert.Throws<ArgumentError>(
          () => Period.BetweenYearMonth(yearMonth1, yearMonth2, PeriodUnits.Years | PeriodUnits.Days));
      Assert.Throws<ArgumentError>(
          () => Period.BetweenYearMonth(yearMonth1, yearMonth2, PeriodUnits.Years | PeriodUnits.Weeks));
      Assert.Throws<ArgumentError>(
          () => Period.BetweenYearMonth(yearMonth1, yearMonth2, PeriodUnits.Years | PeriodUnits.Hours));
    },

    'BetweenYearMonth_DifferentCalendarSystems_Throws': (args) {
      YearMonth start = YearMonth(2017, 11, CalendarSystem.Coptic);
      YearMonth end = YearMonth(2017, 11, CalendarSystem.Gregorian);
      Assert.Throws<ArgumentError>(() => Period.BetweenYearMonth(start, end));
    },

    'BetweenYearMonth_SingleUnit': (args) {
      final [String startText, String endText, PeriodUnits units, int expectedValue] = args;
      var start = YearMonthPattern.Iso.Parse(startText).Value;
      var end = YearMonthPattern.Iso.Parse(endText).Value;
      var forward = Period.BetweenYearMonth(start, end, units);
      var expectedForward = (PeriodBuilder()..[units] = expectedValue).Build();
      Assert.AreEqual(expectedForward, forward);
      var backward = Period.BetweenYearMonth(end, start, units);
      var expectedBackward = (PeriodBuilder()..[units] = -expectedValue).Build();
      Assert.AreEqual(expectedBackward, backward);
    },

    'BetweenYearMonth_BothUnits': (args) {
      final [String startText, String endText, int expectedYears, int expectedMonths] = args;
      var start = YearMonthPattern.Iso.Parse(startText).Value;
      var end = YearMonthPattern.Iso.Parse(endText).Value;
      var forward = Period.BetweenYearMonth(start, end, PeriodUnits.Years | PeriodUnits.Months);
      var expectedForward = (PeriodBuilder()
            ..[PeriodUnits.Years] = expectedYears
            ..[PeriodUnits.Months] = expectedMonths)
          .Build();
      Assert.AreEqual(expectedForward, forward);
      var forwardNoUnits = Period.BetweenYearMonth(start, end);
      Assert.AreEqual(expectedForward, forwardNoUnits);
      var backward = Period.BetweenYearMonth(end, start, PeriodUnits.Years | PeriodUnits.Months);
      var expectedBackward = (PeriodBuilder()
            ..[PeriodUnits.Years] = -expectedYears
            ..[PeriodUnits.Months] = -expectedMonths)
          .Build();
      Assert.AreEqual(expectedBackward, backward);
      var backwardNoUnits = Period.BetweenYearMonth(end, start);
      Assert.AreEqual(expectedBackward, backwardNoUnits);
    },

    'FromNanoseconds': (args) {
      var period = Period.FromNanoseconds(1234567890);
      Assert.AreEqual(1234567890, period.Nanoseconds);
    },

    'AddPeriodToPeriod_NoOverflow': (args) {
      Period p1 = Period.FromHours(Int64.MaxValue);
      Period p2 = Period.FromMinutes(60);
      Assert.AreEqual(
          (PeriodBuilder()
                ..Hours = Int64.MaxValue
                ..Minutes = 60)
              .Build(),
          p1 + p2);
    },

    'AddPeriodToPeriod_Overflow': (args) {
      Period p1 = Period.FromHours(Int64.MaxValue);
      Period p2 = Period.FromHours(1);
      Assert.Throws<OverflowException>(() => (p1 + p2).hashCode);
    },
  }, skip: {
    'UnaryAddition': SkipReasons.UnaryPlus,
    // Period.MaxValue's long fields (long.MaxValue) round to 2^63 on dart2js, so MaxValue + MinValue is zero there.
    if (isDart2js) 'Addition_MaxAndMinValue': SkipReasons.Dart2jsInt,
    if (isDart2js) 'Normalize_Overflow': SkipReasons.Dart2jsInt,
    if (isDart2js) 'ToDuration_Overflow': SkipReasons.Dart2jsInt,
    if (isDart2js) 'ToDuration_Overflow_WhenPossiblyValid': SkipReasons.Dart2jsInt,
    if (isDart2js) 'AddPeriodToPeriod_NoOverflow': SkipReasons.Dart2jsInt,
    if (isDart2js) 'AddPeriodToPeriod_Overflow': SkipReasons.Dart2jsInt,
  });
}

/// Just a simple way of parsing a period string. It's a more compact period representation.
Period Parse(String text) {
  return PeriodPattern.Roundtrip.Parse(text).Value;
}

// noda_dart: C#'s `Period? val4 = null;`, opaque to flow analysis.
Period? NullPeriod() => null;
