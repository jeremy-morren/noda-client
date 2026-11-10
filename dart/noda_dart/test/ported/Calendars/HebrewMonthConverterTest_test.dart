// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/HebrewMonthConverterTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Calendars/HebrewMonthConverter.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/HebrewMonthConverterTest.generated.dart' as scenarios;

const int SampleLeapYear = 5502;
const int SampleNonLeapYear = 5501;

void main() {
  port(scenarios.fixture, {
    'NonLeapYear': (args) {
      final [int scriptural, int civil] = args;
      Assert.AreEqual(scriptural, HebrewMonthConverter.CivilToScriptural(SampleNonLeapYear, civil));
      Assert.AreEqual(civil, HebrewMonthConverter.ScripturalToCivil(SampleNonLeapYear, scriptural));
    },

    'LeapYear': (args) {
      final [int scriptural, int civil] = args;
      Assert.AreEqual(scriptural, HebrewMonthConverter.CivilToScriptural(SampleLeapYear, civil));
      Assert.AreEqual(civil, HebrewMonthConverter.ScripturalToCivil(SampleLeapYear, scriptural));
    },
  });
}
