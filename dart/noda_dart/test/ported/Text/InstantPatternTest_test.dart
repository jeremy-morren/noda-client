// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/InstantPatternTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/InstantPattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/InstantPatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays (their values come from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<Instant>((fields) => Data(fields['value'] as Instant)),

    'IsoHandlesCommas': (args) {
      Instant expected = Instant.FromUtc(2012, 1, 1, 0, 0) + Duration.Epsilon;
      Instant actual = InstantPattern.ExtendedIso.Parse('2012-01-01T00:00:00,000000001Z').Value;
      Assert.AreEqual(expected, actual);
    },

    'Create': (args) {
      var pattern = InstantPattern.Create('HH:mm:ss', Cultures.DotTimeSeparator);
      var text = pattern.Format(Instant.FromUtc(2000, 1, 1, 12, 34, 56));
      Assert.AreEqual('12.34.56', text);
    },

    'WithTwoDigitYearMax': (args) {
      final [int twoDigitYearMax, String text, int expectedYear] = args;
      var pattern = InstantPattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss").WithTwoDigitYearMax(twoDigitYearMax);
      var value = pattern.Parse(text).Value;
      Assert.AreEqual(expectedYear, value.InUtc().Year);
    },

    'WithTwoDigitYearMax_Invalid': (args) {
      final [int twoDigitYearMax] = args;
      Assert.Throws<RangeError>(() => InstantPattern.General.WithTwoDigitYearMax(twoDigitYearMax));
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

/// A container for test data for formatting and parsing [LocalTime] objects.
final class Data extends PatternTestData<Instant> {
  @override
  Instant get DefaultTemplate => NodaConstants.UnixEpoch;

  Data(super.value);

  // Not ported: the Data constructors only the data arrays use.

  @override
  IPattern<Instant> CreatePattern() =>
      InstantPattern.CreateWithInvariantCulture(this.Pattern!).WithTemplateValue(Template).WithCulture(Culture);
}
