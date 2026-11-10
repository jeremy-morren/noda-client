// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/TextCursorTestBase.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the inherited test methods are [TextCursorTestBase.Bodies], spread into the fixture's port().

import 'package:noda_dart/src/Text/TextCursor.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';

/// Base class for tests of classes derived from TextCursor.
abstract final class TextCursorTestBase {
  /// noda_dart: the test methods, as bodies over the fixture's [MakeCursor].
  static Map<String, TestBody> Bodies(TextCursor Function(String value) MakeCursor) => {
        'TestConstructor': (args) {
          const String testString = 'test';
          TextCursor cursor = MakeCursor(testString);
          ValidateContents(cursor, testString);
          ValidateBeginningOfString(cursor);
        },

        'TestMove': (args) {
          TextCursor cursor = MakeCursor('test');
          ValidateBeginningOfString(cursor);
          Assert.True(cursor.Move(0));
          ValidateCurrentCharacter(cursor, 0, 't');
          Assert.True(cursor.Move(1));
          ValidateCurrentCharacter(cursor, 1, 'e');
          Assert.True(cursor.Move(2));
          ValidateCurrentCharacter(cursor, 2, 's');
          Assert.True(cursor.Move(3));
          ValidateCurrentCharacter(cursor, 3, 't');
          Assert.False(cursor.Move(4));
          ValidateEndOfString(cursor);
        },

        'TestMove_NextPrevious': (args) {
          TextCursor cursor = MakeCursor('test');
          ValidateBeginningOfString(cursor);
          Assert.True(cursor.Move(2), 'Move(2)');
          ValidateCurrentCharacter(cursor, 2, 's');
          Assert.True(cursor.MovePrevious(), 'MovePrevious()');
          ValidateCurrentCharacter(cursor, 1, 'e');
          Assert.True(cursor.MoveNext(), 'MoveNext()');
          ValidateCurrentCharacter(cursor, 2, 's');
          Assert.True(cursor.MovePrevious()); // 1
          Assert.True(cursor.MovePrevious()); // 0
          Assert.False(cursor.MovePrevious());
          ValidateCurrentCharacter(cursor, -1, '\u0000');
          Assert.False(cursor.MovePrevious());
          ValidateCurrentCharacter(cursor, -1, '\u0000');
        },

        'TestMove_invalid': (args) {
          TextCursor cursor = MakeCursor('test');
          ValidateBeginningOfString(cursor);
          Assert.False(cursor.Move(-1000));
          ValidateBeginningOfString(cursor);
          Assert.False(cursor.Move(1000));
          ValidateEndOfString(cursor);
          Assert.False(cursor.Move(-1000));
          ValidateBeginningOfString(cursor);
        },
      };

  static String GetNextCharacter(TextCursor cursor) {
    Assert.IsTrue(cursor.MoveNext());
    return cursor.Current;
  }

  static void ValidateBeginningOfString(TextCursor cursor) {
    ValidateCurrentCharacter(cursor, -1, TextCursor.Nul);
  }

  static void ValidateCurrentCharacter(TextCursor cursor, int expectedCurrentIndex, String expectedCurrentCharacter) {
    Assert.AreEqual(expectedCurrentCharacter, cursor.Current);
    Assert.AreEqual(expectedCurrentIndex, cursor.Index);
  }

  static void ValidateEndOfString(TextCursor cursor) {
    ValidateCurrentCharacter(cursor, cursor.Length, TextCursor.Nul);
  }

  /// noda_dart: C#'s two overloads, (cursor, value) and (cursor, value, length), are one with an optional length.
  static void ValidateContents(TextCursor cursor, String value, [int length = -1]) {
    if (length < 0) {
      length = value.length;
    }
    Assert.AreEqual(value, cursor.Value, 'Cursor Value mismatch');
    Assert.AreEqual(length, cursor.Length, 'Cursor Length mismatch');
  }
}
