// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/PatternTestBase.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the inherited test methods are [PatternTestBase.Bodies], spread into the fixture's port().

import 'package:noda_dart/src/Text/IPattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import 'PatternTestData.dart';

/// Base class for all the pattern tests (when we've migrated OffsetPattern off FormattingTestSupport).
/// Derived classes should have internal static fields with the names listed in the TestCaseSource
/// attributes here: InvalidPatternData, ParseFailureData, ParseData, FormatData. Any field
/// which is missing causes that test to be "not runnable" for that concrete subclass.
/// If a test isn't appropriate (e.g. there's no configurable pattern) just provide a property with
/// an array containing a null value - that will be ignored.
abstract final class PatternTestBase {
  /// noda_dart: [createData] makes the fixture's Data from the decoded fields.
  static Map<String, TestBody> Bodies<T>(PatternTestData<T> Function(Map<String, Object?> fields) createData) {
    PatternTestData<T>? data(List<dynamic> args) => PatternTestData.FromScenario<T, PatternTestData<T>>(args[0], createData);
    return {
      'InvalidPatterns': (args) => InvalidPatterns(data(args)),
      'ParseFailures': (args) => ParseFailures(data(args)),
      'Parse': (args) => Parse(data(args)),
      'Format': (args) => Format(data(args)),
      'AppendFormat': (args) => AppendFormat(data(args)),
    };
  }

  static void InvalidPatterns<T>(PatternTestData<T>? data) {
    data?.TestInvalidPattern();
  }

  static void ParseFailures<T>(PatternTestData<T>? data) {
    data?.TestParseFailure();
  }

  static void Parse<T>(PatternTestData<T>? data) {
    data?.TestParse();
  }

  static void Format<T>(PatternTestData<T>? data) {
    data?.TestFormat();
  }

  // Testing this for every item is somewhat overkill, but not too slow.
  static void AppendFormat<T>(PatternTestData<T>? data) {
    data?.TestAppendFormat();
  }

  static void AssertRoundTrip<T>(T value, IPattern<T> pattern) {
    String text = pattern.Format(value);
    var parseResult = pattern.Parse(text);
    Assert.AreEqual(value, parseResult.Value);
  }

  // Not ported: AssertParseNull (null safety).
}
