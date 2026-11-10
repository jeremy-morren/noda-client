// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/HebrewEcclesiasticalCalculatorTest.cs
// (class HebrewScripturalCalculatorTest)
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: both tests use the BCL's System.Globalization.HebrewCalendar as the oracle, which Dart doesn't have.

import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/HebrewScripturalCalculatorTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {}, skip: {
    'DaysInYear': SkipReasons.BclCalendar,
    'DaysInMonth': SkipReasons.BclCalendar,
  });
}
