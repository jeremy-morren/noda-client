// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/UmAlQuraYearMonthDayCalculatorTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: GenerateData (#if DEBUG, explicit) isn't in the scenarios.

import 'package:noda_dart/src/Calendars/UmAlQuraYearMonthDayCalculator.dart';
import 'package:noda_dart/src/YearMonthDay.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/UmAlQuraYearMonthDayCalculatorTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'GetYearMonthDay_DaysSinceEpoch': (args) {
      var calculator = UmAlQuraYearMonthDayCalculator.New();
      int daysSinceEpoch = calculator.GetStartOfYearInDays(calculator.MinYear);
      for (int year = calculator.MinYear; year <= calculator.MaxYear; year++) {
        for (int month = 1; month <= 12; month++) {
          for (int day = 1; day <= calculator.GetDaysInMonth(year, month); day++) {
            var actual = calculator.GetYearMonthDayDaysSinceEpoch(daysSinceEpoch);
            var expected = YearMonthDay.NewYearMonthDay(year, month, day);
            Assert.AreEqual(expected, actual, 'daysSinceEpoch=$daysSinceEpoch');
            daysSinceEpoch++;
          }
        }
      }
    },

    'GetYearMonthDay_YearAndDayOfYear': (args) {
      var calculator = UmAlQuraYearMonthDayCalculator.New();
      for (int year = calculator.MinYear; year <= calculator.MaxYear; year++) {
        int dayOfYear = 1;
        for (int month = 1; month <= 12; month++) {
          for (int day = 1; day <= calculator.GetDaysInMonth(year, month); day++) {
            var actual = calculator.GetYearMonthDay(year, dayOfYear);
            var expected = YearMonthDay.NewYearMonthDay(year, month, day);
            Assert.AreEqual(expected, actual, 'year=$year; dayOfYear=$dayOfYear');
            dayOfYear++;
          }
        }
      }
    },

    'GetDaysFromStartOfYearToStartOfMonth': (args) {
      var calculator = UmAlQuraYearMonthDayCalculator.New();
      for (int year = calculator.MinYear; year <= calculator.MaxYear; year++) {
        int dayOfYear = 1;
        for (int month = 1; month <= 12; month++) {
          // This delegates to GetDaysFromStartOfYearToStartOfMonth (which is protected).
          Assert.AreEqual(dayOfYear, calculator.GetDayOfYear(YearMonthDay.NewYearMonthDay(year, month, 1)), 'year=$year; month=$month');
          dayOfYear += calculator.GetDaysInMonth(year, month);
        }
      }
    },

    'GetYearMonthDay_InvalidValueForCoverage': (args) {
      var calculator = UmAlQuraYearMonthDayCalculator.New();
      Assert.Throws<RangeError>(() => calculator.GetYearMonthDay(calculator.MinYear, 1000));
    },
  }, skip: {
    'BclEquivalence': SkipReasons.BclCalendar,
    'GetStartOfYearInDays': SkipReasons.BclCalendar,
  });
}
