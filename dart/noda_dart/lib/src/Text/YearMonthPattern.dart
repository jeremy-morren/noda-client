// Ported from NodaTime 6e024dde: src/NodaTime/Text/YearMonthPattern.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../YearMonth.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'LocalDatePattern.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';
import 'YearMonthPatternParser.dart';

const String _IsoFormatPattern = "g"; // General (ISO)

/// Represents a pattern for parsing and formatting [YearMonth] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
class YearMonthPattern implements IPattern<YearMonth> {
  @internal
  static final YearMonth DefaultTemplateValue = YearMonth(2000, 1);

  @internal
  static const String CultureDefaultFormatPattern = "G"; // General (culture-specific)

  @internal
  static final PatternBclSupport<YearMonth> BclSupport =
      PatternBclSupport<YearMonth>.NewDefaultFormatPatternPatternParser(_IsoFormatPattern, (fi) => fi.YearMonthPatternParser);

  /// Gets an invariant year/month pattern which is ISO-8601 compatible.
  /// This corresponds to the text pattern "uuuu'-'MM".
  ///
  /// This pattern corresponds to the 'g' standard pattern.
  ///
  /// Returns an invariant year/month pattern which is ISO-8601 compatible.
  static YearMonthPattern get Iso => YearMonthPatternPatterns.IsoPatternImpl;

  /// Returns the pattern that this object delegates to. Mostly useful to avoid this public class
  /// implementing an internal interface.
  @internal
  final IPartialPattern<YearMonth> UnderlyingPattern;

  /// Gets the pattern text for this pattern, as supplied on creation.
  ///
  /// Returns the pattern text for this pattern, as supplied on creation.
  final String PatternText;

  /// Returns the localization information used in this pattern.
  final NodaFormatInfo _FormatInfo;

  /// Gets the value used as a template for parsing: any field values unspecified
  /// in the pattern are taken from the template.
  ///
  /// Returns the value used as a template for parsing.
  final YearMonth TemplateValue;

  /// Maximum two-digit-year in the template to treat as the current century.
  /// If the value parsed is higher than this, the result is adjusted to the previous century.
  /// This value defaults to 30. To create a pattern with a different value, use [WithTwoDigitYearMax].
  ///
  /// Returns the value used for the maximum two-digit-year, in the range 0-99 inclusive.
  final int TwoDigitYearMax;

  YearMonthPattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(String patternText, NodaFormatInfo formatInfo,
      YearMonth templateValue, int twoDigitYearMax, IPartialPattern<YearMonth> pattern)
      : PatternText = patternText,
        _FormatInfo = formatInfo,
        TemplateValue = templateValue,
        UnderlyingPattern = pattern,
        TwoDigitYearMax = twoDigitYearMax;

  /// Parses the given text value according to the rules of this pattern.
  ///
  /// This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
  /// the argument being null are wrapped in a parse result.
  ///
  /// [text]: The text value to parse.
  ///
  /// Returns the result of parsing, which may be successful or unsuccessful.
  @override
  ParseResult<YearMonth> Parse(String text) => UnderlyingPattern.Parse(text);

  /// Formats the given year/month as text according to the rules of this pattern.
  ///
  /// [value]: The value to format.
  ///
  /// Returns the year/month formatted according to this pattern.
  @override
  String Format(YearMonth value) => UnderlyingPattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(YearMonth value, StringBuffer builder) => UnderlyingPattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, and template value.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  /// [twoDigitYearMax]: Maximum two-digit-year in the template to treat as the current century.
  ///
  /// Returns a pattern for parsing and formatting year/month values.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  @internal
  static YearMonthPattern CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      YearMonth templateValue, int twoDigitYearMax) {
    // Dart: null safety checks patternText and formatInfo.
    // Use the "fixed" parser for the common case of the default template value.
    IPattern<YearMonth> pattern = templateValue == DefaultTemplateValue && twoDigitYearMax == LocalDatePattern.DefaultTwoDigitYearMax
        ? formatInfo.YearMonthPatternParser.ParsePattern(patternText)
        : YearMonthPatternParser.NewTemplateValueTwoDigitYearMax(templateValue, twoDigitYearMax).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    pattern = pattern is YearMonthPattern ? pattern.UnderlyingPattern : pattern;
    final partialPattern = pattern as IPartialPattern<YearMonth>;
    return YearMonthPattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(patternText, formatInfo, templateValue, twoDigitYearMax, partialPattern);
  }

  /// Creates a pattern for the given pattern text, culture, and template value.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields (if omitted, a template value of 2000-01)
  ///
  /// Returns a pattern for parsing and formatting year/months.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static YearMonthPattern Create(String patternText, NodaCultureInfo cultureInfo, [YearMonth? templateValue]) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), templateValue ?? DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the current thread's current culture.
  ///
  /// See the user guide for the available pattern text options. Note that the current culture
  /// is captured at the time this method is called - it is not captured at the point of parsing
  /// or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting year/month values.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static YearMonthPattern CreateWithCurrentCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting year/month values.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static YearMonthPattern CreateWithInvariantCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  YearMonthPattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  YearMonthPattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern like this one, but with the specified template value.
  ///
  /// [newTemplateValue]: The template value for the new pattern, used to fill in unspecified fields.
  ///
  /// Returns a new pattern with the given template value.
  YearMonthPattern WithTemplateValue(YearMonth newTemplateValue) =>
      CreateNodaFormatInfo(PatternText, _FormatInfo, newTemplateValue, TwoDigitYearMax);

  /// Creates a pattern like this one, but with a different [TwoDigitYearMax] value.
  ///
  /// [twoDigitYearMax]: The value to use for [TwoDigitYearMax] in the new pattern, in the range 0-99 inclusive.
  ///
  /// Returns a new pattern with the specified maximum two-digit-year.
  YearMonthPattern WithTwoDigitYearMax(int twoDigitYearMax) =>
      CreateNodaFormatInfo(PatternText, _FormatInfo, TemplateValue, twoDigitYearMax);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
@internal
abstract final class YearMonthPatternPatterns {
  static final YearMonthPattern IsoPatternImpl = YearMonthPattern.CreateWithInvariantCulture("uuuu'-'MM");
}
