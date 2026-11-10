// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/PeriodPatternTest.cs (+ PeriodPatternTest.NormalizingIso.cs, PeriodPatternTest.Roundtrip.cs)
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: two nested fixtures, a port() each, sharing Data.

import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/PeriodPattern.dart';

import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/PeriodPatternTest.PeriodPatternNormalizingIsoTest.generated.dart' as normalizing_iso;
import '../../scenarios/Text/PeriodPatternTest.PeriodPatternRoundtripTest.generated.dart' as roundtrip;
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

void main() {
  // #region PeriodPatternTest.NormalizingIso.cs
  // Not ported: the data arrays and their static constructor (from the scenarios).
  port(normalizing_iso.fixture, {
    ...PatternTestBase.Bodies<Period>((fields) => Data(fields['value'] as Period)),
  }, skip: {
    'ParseNull': SkipReasons.NullSafety,
  });
  // #endregion

  // #region PeriodPatternTest.Roundtrip.cs
  // Tests for RoundtripPatternImpl.
  // Not ported: the data arrays (their values come from the scenarios).
  port(roundtrip.fixture, {
    ...PatternTestBase.Bodies<Period>((fields) => Data(fields['value'] as Period)),
  }, skip: {
    'ParseNull': SkipReasons.NullSafety,
  });
  // #endregion
}

/// A container for test data for formatting and parsing [Period] objects.
final class Data extends PatternTestData<Period> {
  // Irrelevant
  @override
  Period get DefaultTemplate => Period.FromDays(0);

  Data(super.value) {
    StandardPattern = PeriodPattern.Roundtrip;
  }

  // Not ported: Data() and Data(PeriodBuilder builder) (only the data arrays use them).

  @override
  IPattern<Period> CreatePattern() => StandardPattern!;
}
