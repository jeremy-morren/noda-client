// Ported from NodaTime 6e024dde: src/NodaTime/Text/InstantPattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../Instant.dart';
import 'IPattern.dart';
import 'InstantPatternParser.dart';
import 'LocalDatePattern.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

const String _DefaultFormatPattern = "g";

/// Represents a pattern for parsing and formatting [Instant] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class InstantPattern implements IPattern<Instant> {
  @internal
  static final Instant DefaultTemplateValue = Instant.FromUtc(2000, 1, 1, 0, 0);

  /// Gets the general pattern, which always uses an invariant culture. The general pattern represents
  /// an instant as a UTC date/time in ISO-8601 style "uuuu-MM-ddTHH:mm:ss'Z'".
  ///
  /// Returns the general pattern, which always uses an invariant culture.
  static InstantPattern get General => _InstantPatternPatterns.GeneralPatternImpl;

  /// Gets an invariant instant pattern which is ISO-8601 compatible, providing up to 9 decimal places
  /// of sub-second accuracy. (These digits are omitted when unnecessary.)
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'".
  ///
  /// Returns an invariant instant pattern which is ISO-8601 compatible, providing up to 9 decimal places
  /// of sub-second accuracy.
  static InstantPattern get ExtendedIso => _InstantPatternPatterns.ExtendedIsoPatternImpl;

  @internal
  static final PatternBclSupport<Instant> BclSupport =
      PatternBclSupport<Instant>.NewDefaultFormatPatternPatternParser(_DefaultFormatPattern, (fi) => fi.InstantPatternParser);

  final IPattern<Instant> _pattern;

  /// Gets the pattern text for this pattern, as supplied on creation.
  ///
  /// Returns the pattern text for this pattern, as supplied on creation.
  final String PatternText;

  /// Gets the value used as a template for parsing: any field values unspecified
  /// in the pattern are taken from the template.
  ///
  /// Returns the value used as a template for parsing.
  final Instant TemplateValue;

  /// Maximum two-digit-year in the template to treat as the current century.
  /// If the value parsed is higher than this, the result is adjusted to the previous century.
  /// This value defaults to 30. To create a pattern with a different value, use [WithTwoDigitYearMax].
  ///
  /// Returns the value used for the maximum two-digit-year, in the range 0-99 inclusive.
  final int TwoDigitYearMax;

  /// Gets the localization information used in this pattern.
  final NodaFormatInfo _FormatInfo;

  InstantPattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(String patternText, NodaFormatInfo formatInfo,
      Instant templateValue, int twoDigitYearMax, IPattern<Instant> pattern)
      : PatternText = patternText,
        _FormatInfo = formatInfo,
        TemplateValue = templateValue,
        TwoDigitYearMax = twoDigitYearMax,
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
  ParseResult<Instant> Parse(String text) => _pattern.Parse(text);

  /// Formats the given instant as text according to the rules of this pattern.
  ///
  /// [value]: The instant to format.
  ///
  /// Returns the instant formatted according to this pattern.
  @override
  String Format(Instant value) => _pattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(Instant value, StringBuffer builder) => _pattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text and format info.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: The template value to use in the pattern
  /// [twoDigitYearMax]: Maximum two-digit-year in the template to treat as the current century.
  ///
  /// Returns a pattern for parsing and formatting instants.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static InstantPattern _CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo, Instant templateValue, int twoDigitYearMax) {
    // Dart: null safety checks patternText and formatInfo.
    // Note: no check for the default template value, as that ends up being done in the
    // underlying LocalDateTimePattern creation.
    var pattern = InstantPatternParser.NewTemplateValueTwoDigitYearMax(templateValue, twoDigitYearMax).ParsePattern(patternText, formatInfo);
    return InstantPattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(patternText, formatInfo, templateValue, twoDigitYearMax, pattern);
  }

  /// Creates a pattern for the given pattern text and culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  ///
  /// Returns a pattern for parsing and formatting instants.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static InstantPattern Create(String patternText, NodaCultureInfo cultureInfo) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the current thread's current culture.
  ///
  /// See the user guide for the available pattern text options. Note that the current culture
  /// is captured at the time this method is called - it is not captured at the point of parsing
  /// or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting instants.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static InstantPattern CreateWithCurrentCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting instants.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static InstantPattern CreateWithInvariantCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  InstantPattern _WithFormatInfo(NodaFormatInfo formatInfo) => _CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  InstantPattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern like this one, but with the specified template value.
  ///
  /// [newTemplateValue]: The template value for the new pattern, used to fill in unspecified fields.
  ///
  /// Returns a new pattern with the given template value.
  InstantPattern WithTemplateValue(Instant newTemplateValue) =>
      _CreateNodaFormatInfo(PatternText, _FormatInfo, newTemplateValue, TwoDigitYearMax);

  /// Creates a pattern like this one, but with a different [TwoDigitYearMax] value.
  ///
  /// [twoDigitYearMax]: The value to use for [TwoDigitYearMax] in the new pattern, in the range 0-99 inclusive.
  ///
  /// Returns a new pattern with the specified maximum two-digit-year.
  InstantPattern WithTwoDigitYearMax(int twoDigitYearMax) =>
      _CreateNodaFormatInfo(PatternText, _FormatInfo, TemplateValue, twoDigitYearMax);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
abstract final class _InstantPatternPatterns {
  static final InstantPattern ExtendedIsoPatternImpl = InstantPattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'");
  static final InstantPattern GeneralPatternImpl = InstantPattern.CreateWithInvariantCulture("uuuu-MM-ddTHH:mm:ss'Z'");
}
