// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/FormatHelperTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Text/FormatHelper.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/FormatHelperTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'TestLeftPad': (args) {
      final [int value, int length, String expected] = args;
      var builder = StringBuffer();
      FormatHelper.LeftPad(value, length, builder);
      Assert.AreEqual(expected, builder.toString());
    },

    'TestLeftPadNonNegativeInt64': (args) {
      final [int value, int length, String expected] = args;
      var builder = StringBuffer();
      FormatHelper.LeftPadNonNegativeInt64(value, length, builder);
      Assert.AreEqual(expected, builder.toString());
    },

    'TestAppendFraction': (args) {
      final [int value, int length, int scale, String expected] = args;
      var builder = StringBuffer();
      FormatHelper.AppendFraction(value, length, scale, builder);
      Assert.AreEqual(expected, builder.toString());
    },

    'TestAppendFractionTruncate': (args) {
      final [String initial, int value, int length, int scale, String expected] = args;
      var builder = StringBuffer(initial);
      FormatHelper.AppendFractionTruncate(value, length, scale, builder);
      Assert.AreEqual(expected, builder.toString());
    },

    'FormatInvariant': (args) {
      final [int value, String expected] = args;
      var builder = StringBuffer('x');
      FormatHelper.FormatInvariant(value, builder);
      Assert.AreEqual(expected, builder.toString());
    },
  });
}
