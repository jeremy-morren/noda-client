// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/TokensTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/ParserHelper.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/Tokens.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/TokensTest.generated.dart' as scenarios;

/// This is a test class for containing all of the ParserHelper unit tests.
void main() {
  port(scenarios.fixture, {
    'Tokenize': (args) {
      final [String line, List<dynamic> expectedTokens] = args;
      var actualTokens = Tokens.Tokenize(line);
      AssertTokensEqual(expectedTokens.cast<String>(), actualTokens);
    },

    'ParseOffset_ZeroHoursWithMinutesAndSeconds': (args) {
      // Initial offset for Paris
      const String text = '0:09:21';
      var offset = ParserHelper.ParseOffset(text);
      Duration duration = Duration.FromMinutes(9) + Duration.FromSeconds(21);
      Assert.AreEqual(Offset.FromTicks(duration.BclCompatibleTicks), offset);
    },

    'ParseOffset_NegativeZeroHoursWithMinutesAndSeconds': (args) {
      // Initial offset for Ouagadougou
      const String text = '-0:06:04';
      var offset = ParserHelper.ParseOffset(text);
      Duration duration = Duration.FromMinutes(6) + Duration.FromSeconds(4);
      Assert.AreEqual(Offset.FromTicks(-duration.BclCompatibleTicks), offset);
    },
  }, skip: {
    'Tokenize_nullArgument_Exception': SkipReasons.NullSafety,
  });
}

void AssertTokensEqual(List<String> expectedTokens, Tokens tokens) {
  for (int i = 0; i < expectedTokens.length; i++) {
    Assert.True(tokens.HasNextToken, 'Not enough items in enumeration');
    var actual = tokens.NextToken(i.toString());
    // Not ported: `if (actual is null) Assert.Fail(...)` (NextToken's result is non-nullable in Dart).
    Assert.AreEqual(expectedTokens[i], actual, 'The enumeration item at index [$i] is not correct');
  }
  Assert.False(tokens.HasNextToken, 'Too many items in enumeration');
}
