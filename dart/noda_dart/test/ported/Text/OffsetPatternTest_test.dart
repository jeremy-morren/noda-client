// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/OffsetPatternTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Text/IPartialPattern.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/OffsetPattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/OffsetPatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

/// A non-breaking space.
const String Nbsp = ' ';

// Not ported: the data arrays (their values come from the scenarios).

void main() {
  Data? data(List<dynamic> args) =>
      PatternTestData.FromScenario<Offset, Data>(args[0], (fields) => Data(fields['value'] as Offset));

  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<Offset>((fields) => Data(fields['value'] as Offset)),

    'ParsePartial': (args) {
      final PatternTestData<Offset> data_ = data(args)!;
      data_.TestParsePartial();
    },

    'NumberFormatIgnored': (args) {
      var culture = Cultures.EnUs;
      // Not ported: setting NumberFormat's signs (our cultures have no NumberFormat).
      var pattern = OffsetPattern.Create('+HH:mm', culture);
      Assert.AreEqual('+05:00', pattern.Format(Offset.FromHours(5)));
      Assert.AreEqual('-05:00', pattern.Format(Offset.FromHours(-5)));
    },
  }, skip: {
    'ParseNull': SkipReasons.NullSafety,
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
  }, cultures: scenarioCultures);
}

/// A container for test data for formatting and parsing [Offset] objects.
final class Data extends PatternTestData<Offset> {
  // Ignored anyway...
  @override
  Offset get DefaultTemplate => Offset.Zero;

  Data(super.value);

  // Not ported: the Data constructors only the data arrays use.

  @override
  IPattern<Offset> CreatePattern() => OffsetPattern.CreateWithInvariantCulture(this.Pattern!).WithCulture(Culture);

  @override
  IPartialPattern<Offset> CreatePartialPattern() =>
      OffsetPattern.CreateWithInvariantCulture(this.Pattern!).WithCulture(Culture).UnderlyingPattern;
}
