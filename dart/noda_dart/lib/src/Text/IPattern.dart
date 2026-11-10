// Ported from NodaTime 6e024dde: src/NodaTime/Text/IPattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'ParseResult.dart';

/// Generic interface supporting parsing and formatting. Parsing always results in a
/// [ParseResult] which can represent success or failure.
///
/// Idiomatic text handling in Noda Time involves creating a pattern once and reusing it multiple
/// times, rather than specifying the pattern text repeatedly. All patterns are immutable and thread-safe,
/// and include the culture used for localization purposes.
///
/// [T]: Type of value to parse or format.
abstract interface class IPattern<T> {
  /// Parses the given text value according to the rules of this pattern.
  ///
  /// This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
  /// the argument being null are wrapped in a parse result.
  ///
  /// [text]: The text value to parse.
  ///
  /// Returns the result of parsing, which may be successful or unsuccessful.
  ParseResult<T> Parse(String text);

  /// Formats the given value as text according to the rules of this pattern.
  ///
  /// [value]: The value to format.
  ///
  /// Returns the value formatted according to this pattern.
  String Format(T value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer] (C#: `StringBuilder`).
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  StringBuffer AppendFormat(T value, StringBuffer builder);
}
