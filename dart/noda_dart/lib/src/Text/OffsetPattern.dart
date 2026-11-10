// Ported from NodaTime 6e024dde: src/NodaTime/Text/OffsetPattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../Offset.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

const String _DefaultFormatPattern = "g";

/// Represents a pattern for parsing and formatting [Offset] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class OffsetPattern implements IPattern<Offset> {
  /// The "general" offset pattern (e.g. +HH, +HH:mm, +HH:mm:ss, +HH:mm:ss.fff) for the invariant culture.
  ///
  /// Returns the "general" offset pattern for the invariant culture.
  static final OffsetPattern GeneralInvariant = CreateWithInvariantCulture("g");

  /// The "general" offset pattern (e.g. +HH, +HH:mm, +HH:mm:ss, +HH:mm:ss.fff) for the invariant culture,
  /// but producing (and allowing) Z as a value for a zero offset.
  ///
  /// Returns the "general" offset pattern for the invariant culture but producing (and allowing) Z as a value for a zero offset.
  static final OffsetPattern GeneralInvariantWithZ = CreateWithInvariantCulture("G");

  @internal
  static final PatternBclSupport<Offset> BclSupport =
      PatternBclSupport<Offset>.NewDefaultFormatPatternPatternParser(_DefaultFormatPattern, (fi) => fi.OffsetPatternParser);

  /// Gets the pattern text for this pattern, as supplied on creation.
  ///
  /// Returns the pattern text for this pattern, as supplied on creation.
  final String PatternText;

  /// Returns the pattern that this object delegates to. Mostly useful to avoid this public class
  /// implementing an internal interface.
  @internal
  final IPartialPattern<Offset> UnderlyingPattern;

  OffsetPattern._NewPatternTextPattern(String patternText, IPartialPattern<Offset> pattern)
      : PatternText = patternText,
        UnderlyingPattern = pattern;

  /// Parses the given text value according to the rules of this pattern.
  ///
  /// This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
  /// the argument being null are wrapped in a parse result.
  ///
  /// [text]: The text value to parse.
  ///
  /// Returns the result of parsing, which may be successful or unsuccessful.
  @override
  ParseResult<Offset> Parse(String text) => UnderlyingPattern.Parse(text);

  /// Formats the given offset as text according to the rules of this pattern.
  ///
  /// [value]: The offset to format.
  ///
  /// Returns the offset formatted according to this pattern.
  @override
  String Format(Offset value) => UnderlyingPattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(Offset value, StringBuffer builder) => UnderlyingPattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text and format info.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: Localization information
  ///
  /// Returns a pattern for parsing and formatting offsets.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  @internal
  static OffsetPattern CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo) {
    // Dart: null safety checks patternText and formatInfo.
    var pattern = formatInfo.OffsetPatternParser.ParsePattern(patternText) as IPartialPattern<Offset>;
    return OffsetPattern._NewPatternTextPattern(patternText, pattern);
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
  static OffsetPattern Create(String patternText, NodaCultureInfo cultureInfo) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo));

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
  static OffsetPattern CreateWithCurrentCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting offsets.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetPattern CreateWithInvariantCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  OffsetPattern WithCulture(NodaCultureInfo cultureInfo) =>
      CreateNodaFormatInfo(PatternText, NodaFormatInfo.GetFormatInfo(cultureInfo));
}
