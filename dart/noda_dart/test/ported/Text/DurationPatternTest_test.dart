// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/DurationPatternTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Text/DurationPattern.dart';
import 'package:noda_dart/src/Text/IPattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/DurationPatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays (their values come from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<Duration>((fields) => Data(fields['value'] as Duration)),

    'WithCulture': (args) {
      var pattern = DurationPattern.CreateWithInvariantCulture('H:mm').WithCulture(Cultures.DotTimeSeparator);
      var text = pattern.Format(Duration.FromMinutes(90));
      Assert.AreEqual('1.30', text);
    },
  }, skip: {
    'ParseNull': SkipReasons.NullSafety,
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
  }, cultures: scenarioCultures);
}

/// A container for test data for formatting and parsing [Duration] objects.
final class Data extends PatternTestData<Duration> {
  // Ignored anyway...
  @override
  Duration get DefaultTemplate => Duration.Zero;

  Data(super.value);

  // Not ported: the Data constructors only the data arrays use.

  @override
  IPattern<Duration> CreatePattern() => DurationPattern.Create(this.Pattern!, Culture);
}
