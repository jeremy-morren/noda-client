// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/Patterns/PatternCursorTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Text/InvalidPatternException.dart';
import 'package:noda_dart/src/Text/Patterns/PatternCursor.dart';
import 'package:noda_dart/src/Text/TextCursor.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/Text/Patterns/PatternCursorTest.generated.dart' as scenarios;
import '../TextCursorTestBase.dart';

void main() {
  port(scenarios.fixture, {
    ...TextCursorTestBase.Bodies(MakeCursor),

    'GetQuotedString_Invalid': (args) {
      final [String pattern] = args;
      var cursor = PatternCursor.NewPattern(pattern);
      Assert.AreEqual("'", TextCursorTestBase.GetNextCharacter(cursor));
      Assert.Throws<InvalidPatternException>(() => cursor.GetQuotedString("'"));
    },

    'GetQuotedString_Valid': (args) {
      final [String pattern, String expected] = args;
      var cursor = PatternCursor.NewPattern(pattern);
      Assert.AreEqual("'", TextCursorTestBase.GetNextCharacter(cursor));
      String actual = cursor.GetQuotedString("'");
      Assert.AreEqual(expected, actual);
      Assert.IsFalse(cursor.MoveNext());
    },

    'GetQuotedString_HandlesOtherQuote': (args) {
      var cursor = PatternCursor.NewPattern('[abc]');
      TextCursorTestBase.GetNextCharacter(cursor);
      String actual = cursor.GetQuotedString(']');
      Assert.AreEqual('abc', actual);
      Assert.IsFalse(cursor.MoveNext());
    },

    'GetQuotedString_NotAtEnd': (args) {
      var cursor = PatternCursor.NewPattern("'abc'more");
      String openQuote = TextCursorTestBase.GetNextCharacter(cursor);
      String actual = cursor.GetQuotedString(openQuote);
      Assert.AreEqual('abc', actual);
      TextCursorTestBase.ValidateCurrentCharacter(cursor, 4, "'");

      Assert.AreEqual('m', TextCursorTestBase.GetNextCharacter(cursor));
    },

    'GetRepeatCount_Valid': (args) {
      final [String text, int expectedCount] = args;
      var cursor = PatternCursor.NewPattern(text);
      Assert.IsTrue(cursor.MoveNext());
      int actual = cursor.GetRepeatCount(10);
      Assert.AreEqual(expectedCount, actual);
      TextCursorTestBase.ValidateCurrentCharacter(cursor, expectedCount - 1, 'a');
    },

    'GetRepeatCount_ExceedsMax': (args) {
      var cursor = PatternCursor.NewPattern('aaa');
      Assert.IsTrue(cursor.MoveNext());
      Assert.Throws<InvalidPatternException>(() => cursor.GetRepeatCount(2));
    },

    'GetEmbeddedPattern_Valid': (args) {
      final [String pattern, String expectedEmbedded] = args;
      var cursor = PatternCursor.NewPattern(pattern);
      cursor.MoveNext();
      String embedded = cursor.GetEmbeddedPattern();
      Assert.AreEqual(expectedEmbedded, embedded);
      TextCursorTestBase.ValidateCurrentCharacter(cursor, expectedEmbedded.length + 2, '>');
    },

    'GetEmbeddedPattern_Invalid': (args) {
      final [String text] = args;
      var cursor = PatternCursor.NewPattern(text);
      cursor.MoveNext();
      Assert.Throws<InvalidPatternException>(() => cursor.GetEmbeddedPattern());
    },
  });
}

TextCursor MakeCursor(String value) {
  return PatternCursor.NewPattern(value);
}
