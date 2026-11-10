// Ported from NodaTime 6e024dde: src/NodaTime/Text/Patterns/PatternCursor.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Utility/StringFormat.dart';
import '../InvalidPatternException.dart';
import '../TextCursor.dart';
import '../TextErrorMessages.generated.dart';

/// Extends [TextCursor] to simplify parsing patterns such as "uuuu-MM-dd".
@internal
final class PatternCursor extends TextCursor {
  /// The character signifying the start of an embedded pattern.
  static const String EmbeddedPatternStart = '<';

  /// The character signifying the end of an embedded pattern.
  static const String EmbeddedPatternEnd = '>';

  @internal
  PatternCursor.NewPattern(super.pattern) : super.NewValue();

  /// Gets the quoted string.
  ///
  /// The cursor is left positioned at the end of the quoted region.
  ///
  /// [closeQuote]: The close quote character to match for the end of the quoted string.
  ///
  /// Returns the quoted string sans open and close quotes. This can be an empty string but will not be null.
  String GetQuotedString(String closeQuote) {
    // The most common form of quoting is for a single character (e.g. T, Z or a separator such as ':' or '-').
    // If the builder needs to expand beyond that, it's still *probably* going to be short.
    var builder = StringBuffer();
    bool endQuoteFound = false;
    while (MoveNext()) {
      if (Current == closeQuote) {
        MoveNext();
        endQuoteFound = true;
        break;
      }
      if (Current == '\\') {
        if (!MoveNext()) {
          throw InvalidPatternException(TextErrorMessages.EscapeAtEndOfString);
        }
      }
      builder.write(Current);
    }
    if (!endQuoteFound) {
      throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.MissingEndQuote, [closeQuote]);
    }
    MovePrevious();
    return builder.toString();
  }

  /// Gets the pattern repeat count. The cursor is left on the final character of the
  /// repeated sequence.
  ///
  /// [maximumCount]: The maximum number of repetitions allowed.
  ///
  /// Returns the repetition count which is always at least `1`.
  int GetRepeatCount(int maximumCount) {
    String patternCharacter = Current;
    int startPos = Index;
    while (MoveNext() && Current == patternCharacter) {}
    int repeatLength = Index - startPos;
    // Move the cursor back to the last character of the repeated pattern
    MovePrevious();
    if (repeatLength > maximumCount) {
      throw InvalidPatternException.NewFormatStringParameters(
          TextErrorMessages.RepeatCountExceeded, [patternCharacter, maximumCount]);
    }
    return repeatLength;
  }

  /// Returns a string containing the embedded pattern within this one.
  ///
  /// The cursor is expected to be positioned immediately before the [EmbeddedPatternStart] character (`<`),
  /// and on success the cursor will be positioned on the [EmbeddedPatternEnd] character (`>`).
  ///
  /// Quote characters (' and ") and escaped characters (escaped with a backslash) are handled
  /// but not unescaped: the resulting pattern should be ready for parsing as normal. It is assumed that the
  /// embedded pattern will itself handle embedded patterns, so if the input is on the first `<`
  /// of `"before <outer1 <inner> outer2> after"`
  /// this method will return `"outer1 <inner> outer2"` and the cursor will be positioned
  /// on the final `>` afterwards.
  ///
  /// Returns the embedded pattern, not including the start/end pattern characters.
  String GetEmbeddedPattern() {
    if (!MoveNext() || Current != EmbeddedPatternStart) {
      throw InvalidPatternException(StringFormat.Format(TextErrorMessages.MissingEmbeddedPatternStart, [EmbeddedPatternStart]));
    }
    int startIndex = Index + 1;
    int depth = 1; // For nesting
    while (MoveNext()) {
      String current = Current;
      if (current == EmbeddedPatternEnd) {
        depth--;
        if (depth == 0) {
          return Value.substring(startIndex, Index);
        }
      } else if (current == EmbeddedPatternStart) {
        depth++;
      } else if (current == '\\') {
        if (!MoveNext()) {
          throw InvalidPatternException(TextErrorMessages.EscapeAtEndOfString);
        }
      } else if (current == '\'' || current == '"') {
        // We really don't care about the value here. It's slightly inefficient to
        // create the substring and then ignore it, but it's unlikely to be significant.
        GetQuotedString(current);
      }
    }
    // We've reached the end of the enclosing pattern without reaching the end of the embedded pattern. Oops.
    throw InvalidPatternException(StringFormat.Format(TextErrorMessages.MissingEmbeddedPatternEnd, [EmbeddedPatternEnd]));
  }
}
