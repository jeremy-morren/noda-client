// Ported from NodaTime 6e024dde: src/NodaTime/Text/DurationPattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Duration.dart';
import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import 'IPattern.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

/// Represents a pattern for parsing and formatting [Duration] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class DurationPattern implements IPattern<Duration> {
  /// Gets the general pattern for durations using the invariant culture, with a format string of "-D:hh:mm:ss.FFFFFFFFF".
  /// This pattern round-trips. This corresponds to the "o" standard pattern.
  ///
  /// Returns the general pattern for durations using the invariant culture.
  static DurationPattern get Roundtrip => DurationPatternPatterns.RoundtripPatternImpl;

  /// Gets a pattern for durations using the invariant culture, with a format string of "-H:mm:ss.FFFFFFFFF".
  /// This pattern round-trips, and is the pattern that NodaTime.Serialization.JsonNet uses by default.
  /// This corresponds to the "j" standard pattern.
  ///
  /// Returns the pattern for durations using the invariant culture. This is the pattern that NodaTime.Serialization.JsonNet uses by default.
  static DurationPattern get JsonRoundtrip => DurationPatternPatterns.JsonRoundtripPatternImpl;

  @internal
  static final PatternBclSupport<Duration> BclSupport =
      PatternBclSupport<Duration>.NewDefaultFormatPatternPatternParser("o", (fi) => fi.DurationPatternParser);

  final IPattern<Duration> _pattern;

  /// Gets the pattern text for this pattern, as supplied on creation.
  ///
  /// Returns the pattern text for this pattern, as supplied on creation.
  final String PatternText;

  DurationPattern._NewPatternTextPattern(String patternText, IPattern<Duration> pattern)
      : PatternText = patternText,
        _pattern = pattern;

  /// Parses the given text value according to the rules of this pattern.
  ///
  /// This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
  /// the argument being null are wrapped in a parse result.
  ///
  /// [text]: The text value to parse.
  ///
  /// Returns the result of parsing, which may be successful or unsuccessful.
  @override
  ParseResult<Duration> Parse(String text) => _pattern.Parse(text);

  /// Formats the given duration as text according to the rules of this pattern.
  ///
  /// [value]: The duration to format.
  ///
  /// Returns the duration formatted according to this pattern.
  @override
  String Format(Duration value) => _pattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(Duration value, StringBuffer builder) => _pattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text and format info.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: Localization information
  ///
  /// Returns a pattern for parsing and formatting offsets.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static DurationPattern _CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo) {
    // Dart: null safety checks patternText and formatInfo.
    var pattern = formatInfo.DurationPatternParser.ParsePattern(patternText);
    return DurationPattern._NewPatternTextPattern(patternText, pattern);
  }

  /// Creates a pattern for the given pattern text and culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  ///
  /// Returns a pattern for parsing and formatting offsets.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static DurationPattern Create(String patternText, NodaCultureInfo cultureInfo) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern for the given pattern text in the current thread's current culture.
  ///
  /// See the user guide for the available pattern text options. Note that the current culture
  /// is captured at the time this method is called - it is not captured at the point of parsing
  /// or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting offsets.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static DurationPattern CreateWithCurrentCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting offsets.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static DurationPattern CreateWithInvariantCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  DurationPattern WithCulture(NodaCultureInfo cultureInfo) =>
      _CreateNodaFormatInfo(PatternText, NodaFormatInfo.GetFormatInfo(cultureInfo));
}

// Nested class for ease of type initialization
@internal
abstract final class DurationPatternPatterns {
  static final DurationPattern RoundtripPatternImpl = DurationPattern.CreateWithInvariantCulture("-D:hh:mm:ss.FFFFFFFFF");
  static final DurationPattern JsonRoundtripPatternImpl = DurationPattern.CreateWithInvariantCulture("-H:mm:ss.FFFFFFFFF");
}
