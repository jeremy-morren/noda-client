// Ported from NodaTime 6e024dde: src/NodaTime/Text/TextCursor.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

/// Provides a cursor over text being parsed. None of the methods in this class throw exceptions (unless
/// there is a bug in Noda Time, in which case an exception is appropriate) and none of the methods
/// have ref parameters indicating failures, unlike subclasses. This class is used as the basis for both
/// value and pattern parsing, so can make no judgement about what's wrong (i.e. it wouldn't know what
/// type of failure to indicate). Instead, methods return Boolean values to indicate success or failure.
@internal
abstract class TextCursor {
  /// Gets the length of the string being parsed.
  final int Length;

  /// Gets the string being parsed.
  final String Value;

  /// A nul character. This character is not allowed in any parsable string and is used to
  /// indicate that the current character is not set.
  static const String Nul = '\u0000';

  /// Initializes a new instance to parse the given value.
  TextCursor.NewValue(String value)
      // Validated by caller.
      : Value = value,
        Length = value.length {
    Move(-1);
  }

  String _current = Nul;

  /// Gets the current character.
  String get Current => _current;

  /// Gets a value indicating whether this instance has more characters.
  ///
  /// `true` if this instance has more characters; otherwise, `false`.
  bool get HasMoreCharacters => (Index + 1) < Length;

  int _index = -1;

  /// Gets the current index into the string being parsed.
  int get Index => _index;

  /// Gets the remainder the string that has not been parsed yet.
  String get Remainder => Value.substring(Index);

  ///   Returns a [String] that represents this instance.
  @override
  String toString() => Index <= 0
      ? '^$Value'
      : Index >= Length
          ? '$Value^'
          : '${Value.substring(0, Index)}^${Value.substring(Index)}';

  /// Returns the next character if there is one or [Nul] if there isn't.
  String PeekNext() => HasMoreCharacters ? Value[Index + 1] : Nul;

  /// Moves the specified target index. If the new index is out of range of the valid indices
  /// for this string then the index is set to the beginning or the end of the string whichever
  /// is nearest the requested index.
  ///
  /// [targetIndex]: Index of the target.
  ///
  /// Returns `true` if the requested index is in range.
  bool Move(int targetIndex) {
    if (targetIndex >= 0) {
      if (targetIndex < Length) {
        _index = targetIndex;
        _current = Value[Index];
        return true;
      } else {
        _current = Nul;
        _index = Length;
        return false;
      }
    }
    _current = Nul;
    _index = -1;
    return false;
  }

  /// Moves to the next character.
  ///
  /// Returns `true` if the requested index is in range.
  bool MoveNext() {
    // Logically this is Move(Index + 1), but it's micro-optimized as we
    // know we'll never hit the lower limit this way.
    int targetIndex = Index + 1;
    if (targetIndex < Length) {
      _index = targetIndex;
      _current = Value[Index];
      return true;
    }
    _current = Nul;
    _index = Length;
    return false;
  }

  /// Moves to the previous character.
  ///
  /// Returns `true` if the requested index is in range.
  bool MovePrevious() {
    // Logically this is Move(Index - 1), but it's micro-optimized as we
    // know we'll never hit the upper limit this way.
    if (Index > 0) {
      _index--;
      _current = Value[Index];
      return true;
    }
    _current = Nul;
    _index = -1;
    return false;
  }
}
