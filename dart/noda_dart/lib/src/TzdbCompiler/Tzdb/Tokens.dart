// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/Tokens.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Utility/SystemExceptions.dart';
import '../Shims.dart';
import 'MissingTokenException.dart';

/// Provides a simple string tokenizer that breaks the string into words that are separated by
/// white space.
///
/// Multiple white spaces in a row are treated as one separator. White space at the beginning of
/// the line cause an empty token to be returned as the first token. White space at the end of
/// the line are ignored.
@internal
class Tokens {
  /// Represents an empty token list.
  static final List<String> _NoTokens = List<String>.unmodifiable(const <String>[]);

  /// The list of words. This will never be null but may be empty.
  final List<String> _words;

  /// The current index into the words list.
  int _index = 0;

  /// Initializes a new instance of the [Tokens] class.
  ///
  /// [words]: The words list.
  Tokens._NewWords(List<String> words) : _words = words;

  /// Gets a value indicating whether this instance has another token.
  ///
  /// `true` if this instance has another token; otherwise, `false`.
  bool get HasNextToken => _index < _words.length;

  /// Returns the next token.
  ///
  /// [name]: The name of the token. Used in the exception to identify the missing token.
  ///
  /// Returns the next token.
  ///
  /// Throws [MissingTokenException] if there is no next token.
  String NextToken(String name) {
    final (success, result) = TryNextToken();
    if (success) {
      return result;
    }
    throw MissingTokenException(name);
  }

  /// Returns an object that contains the list of the whitespace separated words in the given
  /// string. The string is assumed to be culture invariant.
  ///
  /// [text]: The text to break into words.
  ///
  /// Returns the tokenized text.
  static Tokens Tokenize(String text) {
    // Dart: null safety checks text.
    text = TrimEnd(text);
    if (text == '') {
      return Tokens._NewWords(_NoTokens);
    }
    // Primitive parser, but we need to handle double quotes.
    final list = <String>[];
    final currentWord = StringBuffer();
    var inQuotes = false;
    var lastCharacterWasWhitespace = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') {
        inQuotes = !inQuotes;
        lastCharacterWasWhitespace = false;
        continue;
      }
      if (IsWhiteSpace(c) && !inQuotes) {
        if (!lastCharacterWasWhitespace) {
          list.add(currentWord.toString());
          lastCharacterWasWhitespace = true;
          currentWord.clear();
        }
        // Otherwise, we're just collapsing multiple whitespace
      } else {
        currentWord.write(c);
        lastCharacterWasWhitespace = false;
      }
    }
    if (!lastCharacterWasWhitespace) {
      list.add(currentWord.toString());
    }
    if (inQuotes) {
      throw InvalidDataException('Line has unterminated quotes');
    }
    return Tokens._NewWords(list);
  }

  /// Tries to get the next token.
  ///
  /// Returns a record: true if there was a next token, false otherwise; and the next token (C#'s `out string
  /// result`, "" if there was none).
  (bool, String) TryNextToken() {
    if (HasNextToken) {
      return (true, _words[_index++]);
    }
    return (false, '');
  }
}
