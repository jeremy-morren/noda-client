// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/BadiCalendarSystemTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/BadiYearMonthDayCalculator.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/DateAdjusters.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/PeriodUnits.generated.dart';
import 'package:noda_dart/src/Utility/Preconditions.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/BadiCalendarSystemTest.generated.dart' as scenarios;

// For use with CreateBadíʿDate, this is a notional "month"
// containing Ayyam-i-Ha. The days here are represented in month
// 18 in LocalDate etc.
const int AyyamiHaMonth = 0;

// Period related tests
final LocalDate TestDate1_167_5_15 = CreateBadiDate(167, 5, 15);
final LocalDate TestDate1_167_6_7 = CreateBadiDate(167, 6, 7);
final LocalDate TestDate2_167_Ayyam_4 = CreateBadiDate(167, AyyamiHaMonth, 4);
final LocalDate TestDate3_168_Ayyam_5 = CreateBadiDate(168, AyyamiHaMonth, 5);

/// Tests for the Badíʿ calendar system.
void main() {
  port(scenarios.fixture, {
    'BadiEpoch': (args) {
      // ignore: unused_local_variable
      CalendarSystem badi = CalendarSystem.Badi;
      LocalDate badiEpoch = CreateBadiDate(1, 1, 1);

      CalendarSystem gregorian = CalendarSystem.Gregorian;
      LocalDate converted = badiEpoch.WithCalendar(gregorian);

      LocalDate expected = LocalDate(1844, 3, 21);

      Assert.AreEqual(expected.toString(), converted.toString());
    },

    'YearZeroIsInvalidForPublicCalendarOperations': (args) {
      // Week-year calculations need year 0 internally, but calendar years still start at 1.
      Assert.Throws<RangeError>(() => LocalDate(0, 1, 1, CalendarSystem.Badi));
      Assert.Throws<RangeError>(() => CalendarSystem.Badi.IsLeapYear(0));
    },

    'UnixEpoch': (args) {
      CalendarSystem badi = CalendarSystem.Badi;
      LocalDate unixEpochInBadiCalendar = NodaConstants.UnixEpoch.InZone(DateTimeZone.Utc, badi).LocalDateTime.Date;
      LocalDate expected = CreateBadiDate(126, 16, 2);
      Assert.AreEqual(expected, unixEpochInBadiCalendar);
    },

    'SampleDate': (args) {
      CalendarSystem badiCalendar = CalendarSystem.Badi;
      LocalDate iso = LocalDate(2017, 3, 4);
      LocalDate badi = iso.WithCalendar(badiCalendar);

      Assert.AreEqual(19, BadiMonth(badi));

      Assert.AreEqual(Era.Bahai, badi.Era);
      Assert.AreEqual(173, badi.YearOfEra);

      Assert.AreEqual(173, badi.Year);
      Assert.IsFalse(badiCalendar.IsLeapYear(173));

      Assert.AreEqual(4, BadiDay(badi));

      Assert.AreEqual(IsoDayOfWeek.Saturday, badi.DayOfWeek);
    },

    'GeneralConversionNearNawRuz': (args) {
      final [int gYear, int gMonth, int gDay, int bYear, int bMonth, int bDay] = args;
      // create in the Badíʿ calendar
      var bDate = CreateBadiDate(bYear, bMonth, bDay);
      var gDate = bDate.WithCalendar(CalendarSystem.Gregorian);
      Assert.AreEqual(gYear, gDate.Year);
      Assert.AreEqual(gMonth, gDate.Month);
      Assert.AreEqual(gDay, gDate.Day);

      // convert to the Badíʿ calendar
      var bDate2 = LocalDate(gYear, gMonth, gDay).WithCalendar(CalendarSystem.Badi);
      Assert.AreEqual(bYear, bDate2.Year);
      Assert.AreEqual(bMonth, BadiMonth(bDate2));
      Assert.AreEqual(bDay, BadiDay(bDate2));
    },

    'SpecialCases': (args) {
      final [int gYear, int gMonth, int gDay, int bYear, int bMonth, int bDay] = args;
      // create in test calendar
      var bDate = CreateBadiDate(bYear, bMonth, bDay);

      // convert to gregorian
      var gDate = bDate.WithCalendar(CalendarSystem.Gregorian);

      Assert.AreEqual('$gYear-$gMonth-$gDay', '${gDate.Year}-${gDate.Month}-${gDate.Day}');

      // create in gregorian
      // convert to test calendar
      var gDate2 = LocalDate(gYear, gMonth, gDay);
      var bDate2 = gDate2.WithCalendar(CalendarSystem.Badi);

      Assert.AreEqual('$bYear-$bMonth-$bDay', '${bDate2.Year}-${BadiMonth(bDate2)}-${BadiDay(bDate2)}');
    },

    'GeneralWtoG': (args) {
      final [int bYear, int bMonth, int bDay, int gYear, int gMonth, int gDay] = args;
      // create in this calendar
      var bDate = CreateBadiDate(bYear, bMonth, bDay);
      var gDate = bDate.WithCalendar(CalendarSystem.Gregorian);
      Assert.AreEqual(gYear, gDate.Year);
      Assert.AreEqual(gMonth, gDate.Month);
      Assert.AreEqual(gDay, gDate.Day);

      // convert to this calendar
      var bDate2 = LocalDate(gYear, gMonth, gDay).WithCalendar(CalendarSystem.Badi);
      Assert.AreEqual(bYear, bDate2.Year);
      Assert.AreEqual(bMonth, BadiMonth(bDate2));
      Assert.AreEqual(bDay, BadiDay(bDate2));
    },

    'DaysInAyyamiHa': (args) {
      final [int bYear, int days] = args;
      Assert.AreEqual(days, BadiYearMonthDayCalculator.GetDaysInAyyamiHa(bYear));
    },

    'DayOfYear': (args) {
      final [int bYear, int bMonth, int bDay, int dayOfYear] = args;
      var badi = BadiYearMonthDayCalculator.New();
      Assert.AreEqual(dayOfYear, badi.GetDayOfYear(CreateBadiDate(bYear, bMonth, bDay).YearMonthDay));
    },

    // Cannot use EndOfMonth with Ayyam-i-Ha because they are internally stored as days in month 18.
    // In Ayyam-i-Ha, EndOfMonth should throw an exception or return the last day of Ayyam-i-Ha.
    // In this implementation, it will always return the last day of the month 18.
    'EndOfMonth': (args) {
      final [int year, int month, int day, int eomMonth, int eomDay] = args;
      var start = CreateBadiDate(year, month, day);
      var end = CreateBadiDate(year, eomMonth, eomDay);
      Assert.AreEqual(AsBadiString(end), AsBadiString(DateAdjusters.EndOfMonth(start)));
    },

    'LeapYear': (args) {
      var calendar = CalendarSystem.Badi;
      Assert.IsFalse(calendar.IsLeapYear(172));
      Assert.IsFalse(calendar.IsLeapYear(173));
      Assert.IsTrue(calendar.IsLeapYear(207));
      Assert.IsTrue(calendar.IsLeapYear(220));
    },

    'GetMonthsInYear': (args) {
      var calendar = CalendarSystem.Badi;
      Assert.AreEqual(19, calendar.GetMonthsInYear(180));
    },

    'GetDaysInMonth': (args) {
      final [int year, int month, int expectedDays] = args;
      var calendar = CalendarSystem.Badi;
      Assert.AreEqual(expectedDays, calendar.GetDaysInMonth(year, month));
    },

    'CreateDate_InAyyamiHa': (args) {
      var d1 = CreateBadiDate(180, 0, 3);
      var d3 = CreateBadiDate(180, 18, 22);

      Assert.AreEqual(d1, d3);
    },

    'CreateDate_Invalid': (args) {
      final [int year, int month, int day] = args;
      Assert.Throws<RangeError>(() => CreateBadiDate(year, month, day));
    },

    'BetweenLocalDates_InvalidUnits': (args) {
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(TestDate1_167_5_15, TestDate2_167_Ayyam_4, PeriodUnits(0)));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(TestDate1_167_5_15, TestDate2_167_Ayyam_4, PeriodUnits(-1)));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(TestDate1_167_5_15, TestDate2_167_Ayyam_4, PeriodUnits.AllTimeUnits));
      Assert.Throws<ArgumentError>(() => Period.BetweenLocalDate(TestDate1_167_5_15, TestDate2_167_Ayyam_4, PeriodUnits.Years | PeriodUnits.Hours));
    },

    'SetYear': (args) {
      // Crafted to test SetYear with 0
      var d1 = CreateBadiDate(180, 1, 1);
      LocalDate result = d1 + Period.FromYears(0);
      Assert.AreEqual(180, result.Year);
    },

    'BetweenLocalDates_MovingForwardNoLeapYears_WithExactResults': (args) {
      Period actual = Period.BetweenLocalDate(TestDate1_167_5_15, TestDate1_167_6_7);
      Period expected = Period.FromDays(11);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingForwardNoLeapYears_WithExactResults_2': (args) {
      Period actual = Period.BetweenLocalDate(TestDate1_167_5_15, TestDate2_167_Ayyam_4);
      Period expected = Period.FromMonths(13) + Period.FromDays(8);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingForwardInLeapYear_WithExactResults': (args) {
      Period actual = Period.BetweenLocalDate(TestDate1_167_5_15, TestDate3_168_Ayyam_5);
      Period expected = Period.FromYears(1) + Period.FromMonths(13) + Period.FromDays(9);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingBackwardNoLeapYears_WithExactResults': (args) {
      Period actual = Period.BetweenLocalDate(TestDate2_167_Ayyam_4, TestDate1_167_5_15);
      Period expected = Period.FromMonths(-13) + Period.FromDays(-8);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingBackward_WithExactResults': (args) {
      // should be -1y -13m -9d
      // but system first moves back a year, and in that year, the last day of Ayyam-i-Ha is day 4
      // from there, it is -13m -8d

      Period expected = Period.FromYears(-1) + Period.FromMonths(-13) + Period.FromDays(-8);
      Period actual = Period.BetweenLocalDate(TestDate3_168_Ayyam_5, TestDate1_167_5_15);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingForward_WithJustMonths': (args) {
      Period actual = Period.BetweenLocalDate(TestDate1_167_5_15, TestDate3_168_Ayyam_5, PeriodUnits.Months);
      Period expected = Period.FromMonths(32);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_MovingBackward_WithJustMonths': (args) {
      Period actual = Period.BetweenLocalDate(TestDate3_168_Ayyam_5, TestDate1_167_5_15, PeriodUnits.Months);
      Period expected = Period.FromMonths(-32);
      Assert.AreEqual(expected, actual);
    },

    'BetweenLocalDates_AsymmetricForwardAndBackward': (args) {
      LocalDate d1 = CreateBadiDate(166, 18, 4);
      LocalDate d2 = CreateBadiDate(167, 1, 10);

      // spanning Ayyam-i-Ha - not counted as a month
      Assert.AreEqual(Period.FromMonths(2) + Period.FromDays(6), Period.BetweenLocalDate(d1, d2));
      Assert.AreEqual(Period.FromMonths(-2) + Period.FromDays(-6), Period.BetweenLocalDate(d2, d1));
    },

    'BetweenLocalDates_EndOfMonth': (args) {
      LocalDate d1 = CreateBadiDate(171, 5, 19);
      LocalDate d2 = CreateBadiDate(171, 6, 19);
      Assert.AreEqual(Period.FromMonths(1), Period.BetweenLocalDate(d1, d2));
      Assert.AreEqual(Period.FromMonths(-1), Period.BetweenLocalDate(d2, d1));
    },

    'BetweenLocalDates_OnLeapYear': (args) {
      LocalDate d1 = LocalDate(2012, 2, 29).WithCalendar(CalendarSystem.Badi);
      LocalDate d2 = LocalDate(2013, 2, 28).WithCalendar(CalendarSystem.Badi);

      Assert.AreEqual('168-0-4', AsBadiString(d1));
      Assert.AreEqual('169-0-3', AsBadiString(d2));

      Assert.AreEqual(Period.FromMonths(19) + Period.FromDays(18), Period.BetweenLocalDate(d1, d2));
    },

    'BetweenLocalDates_AfterLeapYear': (args) {
      LocalDate d1 = CreateBadiDate(180, 19, 5);
      LocalDate d2 = CreateBadiDate(181, 19, 5);
      Assert.AreEqual(Period.FromYears(1), Period.BetweenLocalDate(d1, d2));
      Assert.AreEqual(Period.FromYears(-1), Period.BetweenLocalDate(d2, d1));
    },


    'Addition_DayCrossingMonthBoundary': (args) {
      LocalDate start = CreateBadiDate(182, 4, 13);
      LocalDate result = start + Period.FromDays(10);
      Assert.AreEqual(CreateBadiDate(182, 5, 4), result);
    },

    'Addition': (args) {
      var start = CreateBadiDate(182, 1, 1);

      var result = start + Period.FromDays(3);
      Assert.AreEqual(CreateBadiDate(182, 1, 4), result);

      result = start + Period.FromDays(20);
      Assert.AreEqual(CreateBadiDate(182, 2, 2), result);
    },

    'Addition_DayCrossingMonthBoundaryFromAyyamiHa': (args) {
      var start = CreateBadiDate(182, AyyamiHaMonth, 3);

      var result = start + Period.FromDays(10);
      // in 182, Ayyam-i-Ha has 5 days
      Assert.AreEqual(CreateBadiDate(182, 19, 8), result);
    },

    'Addition_OneYearOnLeapDay': (args) {
      LocalDate start = CreateBadiDate(182, AyyamiHaMonth, 5);
      LocalDate result = start + Period.FromYears(1);
      // Ayyam-i-Ha 5 becomes Ayyam-i-Ha 4
      Assert.AreEqual(CreateBadiDate(183, AyyamiHaMonth, 4), result);
    },

    'Addition_FiveYearsOnLeapDay': (args) {
      LocalDate start = CreateBadiDate(182, AyyamiHaMonth, 5);
      LocalDate result = start + Period.FromYears(5);
      Assert.AreEqual(CreateBadiDate(187, AyyamiHaMonth, 5), result);
    },

    'Addition_YearMonthDay': (args) {
      // One year, one month, two days
      Period period = Period.FromYears(1) + Period.FromMonths(1) + Period.FromDays(2);
      LocalDate start = CreateBadiDate(171, 1, 19);
      // Periods are added in order, so this becomes...
      // Add one year: 172.1.19
      // Add one month: 172.2.19
      // Add two days: 172.3.2
      LocalDate result = start + period;
      Assert.AreEqual(CreateBadiDate(172, 3, 2), result);
    },

    'PlusMonths_ToLastMonthOfNextYear': (args) {
      final [int year, int month, int day, int months, int expectedYear, int expectedMonth, int expectedDay] = args;
      var start = CreateBadiDate(year, month, day);
      var actual = start.PlusMonths(months);
      var expected = CreateBadiDate(expectedYear, expectedMonth, expectedDay);
      Assert.AreEqual(expected.YearMonthDay, actual.YearMonthDay);
    },

    'PlusMonths_Overflow': (args) {
      var calendar = CalendarSystem.Badi;
      var earlyDate = LocalDate(calendar.MinYear, 1, 1, calendar);
      var lateDate = LocalDate(calendar.MaxYear, 19, 1, calendar);

      Assert.Throws<OverflowException>(() => earlyDate.PlusMonths(-1));
      Assert.Throws<OverflowException>(() => lateDate.PlusMonths(1));
    },

    // See https://github.com/nodatime/nodatime/issues/1908
    'EpochDaysRoundtrip': (args) {
      const int daysSinceEpoch = 45003;
      var calculator = BadiYearMonthDayCalculator.New();
      var ymd = calculator.GetYearMonthDayDaysSinceEpoch(daysSinceEpoch);
      Assert.AreEqual(daysSinceEpoch, calculator.GetDaysSinceEpoch(ymd));
    },

    'HelperMethod_BadiDay': (args) {
      // ensure that this helper method is working
      Assert.AreEqual(BadiDay(CreateBadiDate(180, 10, 10)), 10);
      Assert.AreEqual(BadiDay(CreateBadiDate(180, 18, 19)), 19);
      Assert.AreEqual(BadiDay(CreateBadiDate(180, 0, 3)), 3);
      Assert.AreEqual(BadiDay(CreateBadiDate(180, 19, 1)), 1);
    },

    'HelperMethod_BadiMonth': (args) {
      // ensure that this helper method is working
      Assert.AreEqual(BadiMonth(CreateBadiDate(180, 10, 10)), 10);
      Assert.AreEqual(BadiMonth(CreateBadiDate(180, 18, 19)), 18);
      Assert.AreEqual(BadiMonth(CreateBadiDate(180, 0, 3)), 0);
      Assert.AreEqual(BadiMonth(CreateBadiDate(180, 19, 1)), 19);
    },

    'HelperMethod_AsBadiString': (args) {
      // ensure that this helper method is working
      Assert.AreEqual(AsBadiString(CreateBadiDate(180, 10, 10)), '180-10-10');
      Assert.AreEqual(AsBadiString(CreateBadiDate(180, 18, 19)), '180-18-19');
      Assert.AreEqual(AsBadiString(CreateBadiDate(180, 0, 3)), '180-0-3');
      Assert.AreEqual(AsBadiString(CreateBadiDate(180, 19, 1)), '180-19-1');
    },
  });
}

/// Create a [LocalDate] in the Badíʿ calendar, treating 0
/// as the month containing Ayyam-i-Ha.
///
/// [year]: Year in the Badíʿ calendar
/// [month]: Month (use 0 for Ayyam-i-Ha)
/// [day]: Day in month
LocalDate CreateBadiDate(int year, int month, int day) {
  if (month == AyyamiHaMonth) {
    Preconditions.CheckArgumentRange('day', day, 1, BadiYearMonthDayCalculator.GetDaysInAyyamiHa(year));
    // Move Ayyam-i-Ha days to fall after the last day of month 18.
    month = BadiYearMonthDayCalculator.Month18;
    day += BadiYearMonthDayCalculator.DaysInMonth;
  }
  return LocalDate(year, month, day, CalendarSystem.Badi);
}

/// Return the day of this month, treating Ayyam-i-Ha as a separate month.
int BadiDay(LocalDate input) {
  Preconditions.CheckArgument(input.Calendar == CalendarSystem.Badi, 'input', 'Only valid when using the Badíʿ calendar');

  if (input.Month == BadiYearMonthDayCalculator.Month18 &&
      input.Day > BadiYearMonthDayCalculator.DaysInMonth) {
    return input.Day - BadiYearMonthDayCalculator.DaysInMonth;
  }
  return input.Day;
}

/// Return the month of this date. If in Ayyam-i-Ha, returns 0.
int BadiMonth(LocalDate input) {
  Preconditions.CheckArgument(input.Calendar == CalendarSystem.Badi, 'input', 'Only valid when using the Badíʿ calendar');

  if (input.Month == BadiYearMonthDayCalculator.Month18 &&
      input.Day > BadiYearMonthDayCalculator.DaysInMonth) {
    return AyyamiHaMonth;
  }
  return input.Month;
}

/// Get a text representation of the date.
String AsBadiString(LocalDate input) {
  var year = input.Year;
  var month = BadiMonth(input);
  var day = BadiDay(input);

  return '$year-$month-$day';
}
