// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/WeekYearRulesTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: FromCalendarWeekRule takes the BCL enums' numeric values.

import 'package:noda_dart/src/Calendars/WeekYearRules.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/WeekYearRulesTest.generated.dart' as scenarios;

// C#: CalendarWeekRule.FirstDay and DayOfWeek.Monday.
const int CalendarWeekRuleFirstDay = 0;
const int DayOfWeekMonday = 1;

void main() {
  port(scenarios.fixture, {
    'UnsupportedCalendarWeekRule': (args) {
      Assert.Throws<ArgumentError>(() => WeekYearRules.FromCalendarWeekRule(CalendarWeekRuleFirstDay + 1000, DayOfWeekMonday));
    },
  });
}
