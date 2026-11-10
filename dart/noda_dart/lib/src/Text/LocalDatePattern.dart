// Ported from NodaTime 6e024dde: src/NodaTime/Text/LocalDatePattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../LocalDate.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'LocalDatePatternParser.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

const String _DefaultFormatPattern = "D"; // Long

/// Represents a pattern for parsing and formatting [LocalDate] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class LocalDatePattern implements IPattern<LocalDate> {
  /// Default value for [TwoDigitYearMax].
  @internal
  static const int DefaultTwoDigitYearMax = 30;

  @internal
  static final LocalDate DefaultTemplateValue = LocalDate(2000, 1, 1);

  @internal
  static final PatternBclSupport<LocalDate> BclSupport =
      PatternBclSupport<LocalDate>.NewDefaultFormatPatternPatternParser(_DefaultFormatPattern, (fi) => fi.LocalDatePatternParser);

  /// Gets an invariant local date pattern which is ISO-8601 compatible and which round trips values, but doesn't include the calendar system.
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd".
  ///
  /// This pattern corresponds to the 'R' standard pattern.
  ///
  /// Returns an invariant local date pattern which is ISO-8601 compatible.
  static LocalDatePattern get Iso => LocalDatePatternPatterns.IsoPatternImpl;

  /// Gets an invariant local date pattern which round trips values including the calendar system.
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd '('c')'".
  ///
  /// This pattern corresponds to the 'r' standard pattern.
  ///
  /// Returns an invariant local date pattern which round trips values including the calendar system.
  static LocalDatePattern get FullRoundtrip => LocalDatePatternPatterns.FullRoundtripPatternImpl;

  /// Returns the pattern that this object delegates to. Mostly useful to avoid this public class
  /// implementing an internal interface.
  @internal
  final IPartialPattern<LocalDate> UnderlyingPattern;

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
  final LocalDate TemplateValue;

  /// Maximum two-digit-year in the template to treat as the current century.
  /// If the value parsed is higher than this, the result is adjusted to the previous century.
  /// This value defaults to 30. To create a pattern with a different value, use [WithTwoDigitYearMax].
  ///
  /// Returns the value used for the maximum two-digit-year, in the range 0-99 inclusive.
  final int TwoDigitYearMax;

  LocalDatePattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(this.PatternText, this._FormatInfo, this.TemplateValue,
      this.TwoDigitYearMax, IPartialPattern<LocalDate> pattern)
      : UnderlyingPattern = pattern;

  /// Parses the given text value according to the rules of this pattern.
  ///
  /// This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
  /// the argument being null are wrapped in a parse result.
  ///
  /// [text]: The text value to parse.
  ///
  /// Returns the result of parsing, which may be successful or unsuccessful.
  @override
  ParseResult<LocalDate> Parse(String text) => UnderlyingPattern.Parse(text);

  /// Formats the given local date as text according to the rules of this pattern.
  ///
  /// [value]: The local date to format.
  ///
  /// Returns the local date formatted according to this pattern.
  @override
  String Format(LocalDate value) => UnderlyingPattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(LocalDate value, StringBuffer builder) => UnderlyingPattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, and template value.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  /// [twoDigitYearMax]: Maximum two-digit-year in the template to treat as the current century.
  ///
  /// Returns a pattern for parsing and formatting local dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  @internal
  static LocalDatePattern CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      LocalDate templateValue, int twoDigitYearMax) {
    // Dart: null safety checks patternText and formatInfo.
    // Use the "fixed" parser for the common case of the default template value.
    IPattern<LocalDate> pattern = templateValue == DefaultTemplateValue && twoDigitYearMax == DefaultTwoDigitYearMax
        ? formatInfo.LocalDatePatternParser.ParsePattern(patternText)
        : LocalDatePatternParser.NewTemplateValueTwoDigitYearMax(templateValue, twoDigitYearMax).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    pattern = pattern is LocalDatePattern ? pattern.UnderlyingPattern : pattern;
    final partialPattern = pattern as IPartialPattern<LocalDate>;
    return LocalDatePattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(patternText, formatInfo, templateValue, twoDigitYearMax, partialPattern);
  }

  /// Creates a pattern for the given pattern text, culture, and template value.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields (if omitted, a template value of 2000-01-01)
  ///
  /// Returns a pattern for parsing and formatting local dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalDatePattern Create(String patternText, NodaCultureInfo cultureInfo, [LocalDate? templateValue]) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), templateValue ?? DefaultTemplateValue, DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the current thread's current culture.
  ///
  /// See the user guide for the available pattern text options. Note that the current culture
  /// is captured at the time this method is called - it is not captured at the point of parsing
  /// or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalDatePattern CreateWithCurrentCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, DefaultTemplateValue, DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalDatePattern CreateWithInvariantCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, DefaultTemplateValue, DefaultTwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  LocalDatePattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  LocalDatePattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern like this one, but with the specified template value.
  ///
  /// [newTemplateValue]: The template value for the new pattern, used to fill in unspecified fields.
  ///
  /// Returns a new pattern with the given template value.
  LocalDatePattern WithTemplateValue(LocalDate newTemplateValue) =>
      CreateNodaFormatInfo(PatternText, _FormatInfo, newTemplateValue, TwoDigitYearMax);

  /// Creates a pattern like this one, but with the template value modified to use
  /// the specified calendar system.
  ///
  /// Care should be taken in two (relatively rare) scenarios. Although the default template value
  /// is supported by all Noda Time calendar systems, if a pattern is created with a different
  /// template value and then this method is called with a calendar system which doesn't support that
  /// date, an exception will be thrown. Additionally, if the pattern only specifies some date fields,
  /// it's possible that the new template value will not be suitable for all values.
  ///
  /// [calendar]: The calendar system to convert the template value into.
  ///
  /// Returns a new pattern with a template value in the specified calendar system.
  LocalDatePattern WithCalendar(CalendarSystem calendar) =>
      WithTemplateValue(TemplateValue.WithCalendar(calendar));

  /// Creates a pattern like this one, but with a different [TwoDigitYearMax] value.
  ///
  /// [twoDigitYearMax]: The value to use for [TwoDigitYearMax] in the new pattern, in the range 0-99 inclusive.
  ///
  /// Returns a new pattern with the specified maximum two-digit-year.
  LocalDatePattern WithTwoDigitYearMax(int twoDigitYearMax) =>
      CreateNodaFormatInfo(PatternText, _FormatInfo, TemplateValue, twoDigitYearMax);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
@internal
abstract final class LocalDatePatternPatterns {
  static final LocalDatePattern IsoPatternImpl = LocalDatePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd");
  static final LocalDatePattern FullRoundtripPatternImpl = LocalDatePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd '('c')'");
}
