// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/YearMonthDayCalculatorTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the calculators arrive as NamedWrapper<YearMonthDayCalculator> values (Decode.dart).

import 'package:noda_dart/src/Calendars/YearMonthDayCalculator.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/NamedWrapper.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/YearMonthDayCalculatorTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // Note for tests:
    // We can't make the parameter of type YearMonthDayCalculator, because that's internal.
    // We can't make the method internal, as then it isn't a test. Casting is all we've got.
    'ValidateStartOfYear1Days': (args) {
      final [Object calculatorWrapper] = args;
      var calculator = (calculatorWrapper as NamedWrapper<YearMonthDayCalculator>).Value;
      // Some calendars (e.g. Um Al Qura) don't support year 1, so the DaysAtStartOfYear1
      // is somewhat theoretical. (It's still used in such calendars, but only to get a guess
      // as to a year number given a day number.)
      if (calculator.MinYear > 1 || calculator.MaxYear < 0) {
        return;
      }
      Assert.AreEqual(calculator.GetStartOfYearInDays(1), calculator.DaysAtStartOfYear1);
    },

    'GetYearConsistentWithGetYearDays': (args) {
      final [Object calculatorWrapper] = args;
      var calculator = (calculatorWrapper as NamedWrapper<YearMonthDayCalculator>).Value;
      for (int year = calculator.MinYear; year <= calculator.MaxYear; year++) {
        int startOfYearDays = calculator.GetStartOfYearInDays(year);
        var (int actualYear, int dayOfYear) = calculator.GetYear(startOfYearDays);
        Assert.AreEqual(year, actualYear, 'Start of year $year');
        Assert.AreEqual(0, dayOfYear); // Zero-based...
        (actualYear, dayOfYear) = calculator.GetYear(startOfYearDays - 1);
        Assert.AreEqual(year - 1, actualYear, 'End of year ${year - 1}');
        Assert.AreEqual(calculator.GetDaysInYear(year - 1) - 1, dayOfYear);
      }
    },
  });
}
