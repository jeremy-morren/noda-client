// Ported from NodaTime 6e024dde: src/NodaTime/Text/OffsetDateTimePattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../LocalDateTime.dart';
import '../Offset.dart';
import '../OffsetDateTime.dart';
import 'IPattern.dart';
import 'LocalDatePattern.dart';
import 'OffsetDateTimePatternParser.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

/// Represents a pattern for parsing and formatting [OffsetDateTime] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class OffsetDateTimePattern implements IPattern<OffsetDateTime> {
  @internal
  static final OffsetDateTime DefaultTemplateValue = LocalDateTime(2000, 1, 1, 0, 0).WithOffset(Offset.Zero);

  /// Gets an invariant offset date/time pattern based on ISO-8601 (down to the second), including offset from UTC.
  ///
  /// The calendar system is not parsed or formatted as part of this pattern. It corresponds to a custom pattern of
  /// "uuuu'-'MM'-'dd'T'HH':'mm':'sso&lt;G&gt;". This pattern is available as the "G"
  /// standard pattern (even though it is invariant).
  ///
  /// Returns an invariant offset date/time pattern based on ISO-8601 (down to the second), including offset from UTC.
  static OffsetDateTimePattern get GeneralIso => OffsetDateTimePatternPatterns.GeneralIsoPatternImpl;

  /// Gets an invariant offset date/time pattern based on ISO-8601 (down to the nanosecond), including offset from UTC.
  ///
  /// The calendar system is not parsed or formatted as part of this pattern. It corresponds to a custom pattern of
  /// "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo&lt;G&gt;". This will round-trip any values
  /// in the ISO calendar, and is available as the "o" standard pattern.
  ///
  /// Returns an invariant offset date/time pattern based on ISO-8601 (down to the nanosecond), including offset from UTC.
  static OffsetDateTimePattern get ExtendedIso => OffsetDateTimePatternPatterns.ExtendedIsoPatternImpl;

  /// Gets an invariant offset date/time pattern based on RFC 3339 (down to the nanosecond), including offset from UTC
  /// as hours and minutes only.
  ///
  /// The minutes part of the offset is always included, but any sub-minute component
  /// of the offset is lost. An offset of zero is formatted as 'Z', but all of 'Z', '+00:00' and '-00:00' are parsed
  /// the same way. The RFC 3339 meaning of '-00:00' is not supported by Noda Time.
  /// Note that parsing is case-sensitive (so 'T' and 'Z' must be upper case).
  /// The calendar system is not parsed or formatted as part of this pattern. It corresponds to a custom pattern of
  /// "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo&lt;Z+HH:mm&gt;".
  ///
  /// Returns an invariant offset date/time pattern based on RFC 3339 (down to the nanosecond), including offset from UTC
  /// as hours and minutes only.
  static OffsetDateTimePattern get Rfc3339 => OffsetDateTimePatternPatterns.Rfc3339PatternImpl;

  /// Gets an invariant offset date/time pattern based on ISO-8601 (down to the nanosecond)
  /// including offset from UTC and calendar ID.
  ///
  /// The returned pattern corresponds to a custom pattern of
  /// "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo&lt;G&gt; '('c')'". This will round-trip any value in any calendar,
  /// and is available as the "r" standard pattern.
  ///
  /// Returns an invariant offset date/time pattern based on ISO-8601 (down to the nanosecond)
  /// including offset from UTC and calendar ID.
  static OffsetDateTimePattern get FullRoundtrip => OffsetDateTimePatternPatterns.FullRoundtripPatternImpl;

  final IPattern<OffsetDateTime> _pattern;

  /// Gets the pattern text for this pattern, as supplied on creation.
  ///
  /// Returns the pattern text for this pattern, as supplied on creation.
  final String PatternText;

  // Visible for testing
  /// Gets the localization information used in this pattern.
  @internal
  final NodaFormatInfo FormatInfo;

  /// Gets the value used as a template for parsing: any field values unspecified
  /// in the pattern are taken from the template.
  ///
  /// Returns the value used as a template for parsing.
  final OffsetDateTime TemplateValue;

  /// Maximum two-digit-year in the template to treat as the current century.
  /// If the value parsed is higher than this, the result is adjusted to the previous century.
  /// This value defaults to 30. To create a pattern with a different value, use [WithTwoDigitYearMax].
  ///
  /// Returns the value used for the maximum two-digit-year, in the range 0-99 inclusive.
  final int TwoDigitYearMax;

  OffsetDateTimePattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(String patternText, NodaFormatInfo formatInfo,
      OffsetDateTime templateValue, int twoDigitYearMax, IPattern<OffsetDateTime> pattern)
      : PatternText = patternText,
        FormatInfo = formatInfo,
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
  ParseResult<OffsetDateTime> Parse(String text) => _pattern.Parse(text);

  /// Formats the given offset date/time as text according to the rules of this pattern.
  ///
  /// [value]: The offset date/time to format.
  ///
  /// Returns the offset date/time formatted according to this pattern.
  @override
  String Format(OffsetDateTime value) => _pattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(OffsetDateTime value, StringBuffer builder) => _pattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, and template value.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  /// [twoDigitYearMax]: Maximum two-digit-year in the template to treat as the current century.
  ///
  /// Returns a pattern for parsing and formatting offset date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetDateTimePattern _CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      OffsetDateTime templateValue, int twoDigitYearMax) {
    // Dart: null safety checks patternText and formatInfo.
    var pattern = OffsetDateTimePatternParser.NewTemplateValueTwoDigitYearMax(templateValue, twoDigitYearMax).ParsePattern(patternText, formatInfo);
    return OffsetDateTimePattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(patternText, formatInfo, templateValue, twoDigitYearMax, pattern);
  }

  /// Creates a pattern for the given pattern text, culture, and template value.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  ///
  /// Returns a pattern for parsing and formatting local date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetDateTimePattern Create(String patternText, NodaCultureInfo cultureInfo, OffsetDateTime templateValue) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), templateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the invariant culture, using the default
  /// template value of midnight January 1st 2000 at an offset of 0.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetDateTimePattern CreateWithInvariantCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the current culture, using the default
  /// template value of midnight January 1st 2000 at an offset of 0.
  ///
  /// See the user guide for the available pattern text options. Note that the current culture
  /// is captured at the time this method is called - it is not captured at the point of parsing
  /// or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetDateTimePattern CreateWithCurrentCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the same original localization information as this pattern, but with the specified
  /// pattern text.
  ///
  /// [patternText]: The pattern text to use in the new pattern.
  ///
  /// Returns a new pattern with the given pattern text.
  OffsetDateTimePattern WithPatternText(String patternText) =>
      _CreateNodaFormatInfo(patternText, FormatInfo, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  OffsetDateTimePattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      _CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  OffsetDateTimePattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern for the same original pattern text and culture as this pattern, but with
  /// the specified template value.
  ///
  /// [newTemplateValue]: The template value to use in the new pattern.
  ///
  /// Returns a new pattern with the given template value.
  OffsetDateTimePattern WithTemplateValue(OffsetDateTime newTemplateValue) =>
      _CreateNodaFormatInfo(PatternText, FormatInfo, newTemplateValue, TwoDigitYearMax);

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
  OffsetDateTimePattern WithCalendar(CalendarSystem calendar) =>
      WithTemplateValue(TemplateValue.WithCalendar(calendar));

  /// Creates a pattern like this one, but with a different [TwoDigitYearMax] value.
  ///
  /// [twoDigitYearMax]: The value to use for [TwoDigitYearMax] in the new pattern, in the range 0-99 inclusive.
  ///
  /// Returns a new pattern with the specified maximum two-digit-year.
  OffsetDateTimePattern WithTwoDigitYearMax(int twoDigitYearMax) =>
      _CreateNodaFormatInfo(PatternText, FormatInfo, TemplateValue, twoDigitYearMax);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
@internal
abstract final class OffsetDateTimePatternPatterns {
  static final OffsetDateTimePattern GeneralIsoPatternImpl = OffsetDateTimePattern._CreateNodaFormatInfo("uuuu'-'MM'-'dd'T'HH':'mm':'sso<G>", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  static final OffsetDateTimePattern ExtendedIsoPatternImpl = OffsetDateTimePattern._CreateNodaFormatInfo("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G>", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  static final OffsetDateTimePattern Rfc3339PatternImpl = OffsetDateTimePattern._CreateNodaFormatInfo("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  static final OffsetDateTimePattern FullRoundtripPatternImpl = OffsetDateTimePattern._CreateNodaFormatInfo("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> '('c')'", NodaFormatInfo.InvariantInfo, OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);
  static final PatternBclSupport<OffsetDateTime> BclSupport =
      PatternBclSupport<OffsetDateTime>.NewDefaultFormatPatternPatternParser("G", (fi) => fi.OffsetDateTimePatternParser);
}
