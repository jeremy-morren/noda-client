// Ported from NodaTime 6e024dde: src/NodaTime/Text/LocalDateTimePattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../LocalDateTime.dart';
import 'CompositePatternBuilder.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'LocalDatePattern.dart';
import 'LocalDateTimePatternParser.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

const String _DefaultFormatPattern = "G"; // General (long time)

/// Represents a pattern for parsing and formatting [LocalDateTime] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class LocalDateTimePattern implements IPattern<LocalDateTime> {
  @internal
  static final LocalDateTime DefaultTemplateValue = LocalDateTime(2000, 1, 1, 0, 0);

  @internal
  static final PatternBclSupport<LocalDateTime> BclSupport =
      PatternBclSupport<LocalDateTime>.NewDefaultFormatPatternPatternParser(_DefaultFormatPattern, (fi) => fi.LocalDateTimePatternParser);

  /// Gets an invariant local date/time pattern which is ISO-8601 compatible, down to the second.
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss".
  ///
  /// This pattern corresponds to the 's' standard pattern ("shorter sortable").
  ///
  /// Returns an invariant local date/time pattern which is ISO-8601 compatible, down to the second.
  static LocalDateTimePattern get GeneralIso => LocalDateTimePatternPatterns.GeneralIsoPatternImpl;

  /// Gets an invariant local date/time pattern which is ISO-8601 compatible, providing up to 9 decimal places
  /// of sub-second accuracy. (These digits are omitted when unnecessary.)
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF".
  ///
  /// This pattern corresponds to the 'S' standard pattern ("longer sortable").
  ///
  /// Returns an invariant local date/time pattern which is ISO-8601 compatible, providing up to 9 decimal places
  /// of sub-second accuracy.
  static LocalDateTimePattern get ExtendedIso => LocalDateTimePatternPatterns.ExtendedIsoPatternImpl;

  /// Gets an invariant local date/time pattern which is ISO-8601 compatible, providing up to 7 decimal places
  /// of sub-second accuracy which are always present (including trailing zeroes). This is compatible with the
  /// BCL round-trip formatting of `DateTime` values with a kind of "unspecified".
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffff". It does not necessarily
  /// round-trip all `LocalDateTime` values as it will lose sub-tick information. Use
  /// [FullRoundtripWithoutCalendar] for full precision.
  ///
  /// This pattern corresponds to the 'o' and 'O' standard patterns.
  ///
  /// Returns an invariant local date/time pattern which is ISO-8601 compatible, providing up to 7 decimal places
  /// of sub-second accuracy which are always present (including trailing zeroes).
  static LocalDateTimePattern get BclRoundtrip => LocalDateTimePatternPatterns.BclRoundtripPatternImpl;

  /// Gets an invariant local date/time pattern which round trips values, but doesn't include the calendar system.
  /// It provides up to 9 decimal places of sub-second accuracy which are always present (including trailing zeroes).
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff". It will
  /// round-trip all [LocalDateTime] values if the calendar system of the template value is the same
  /// as the calendar system of the original value.
  ///
  /// This pattern corresponds to the 'r' standard pattern.
  ///
  /// Returns an invariant local date/time pattern which is ISO-8601 compatible, providing up to 7 decimal places
  /// of sub-second accuracy which are always present (including trailing zeroes).
  static LocalDateTimePattern get FullRoundtripWithoutCalendar => LocalDateTimePatternPatterns.FullRoundtripWithoutCalendarImpl;

  /// Gets an invariant local date/time pattern which round trips values including the calendar system.
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff '('c')'".
  ///
  /// This pattern corresponds to the 'R' standard pattern.
  ///
  /// Returns an invariant local date/time pattern which round trips values including the calendar system.
  static LocalDateTimePattern get FullRoundtrip => LocalDateTimePatternPatterns.FullRoundtripPatternImpl;

  /// Gets an invariant local date/time pattern which is ISO-8601 compatible, with precision of just minutes.
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH':'mm".
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible, with no sub-minute precision.
  static LocalDateTimePattern get DateHourMinuteIso => LocalDateTimePatternPatterns.DateHourMinuteIsoPatternImpl;

  /// Gets an invariant local date/time pattern which is ISO-8601 compatible, with a precision of just hours.
  /// This corresponds to the text pattern "uuuu'-'MM'-'dd'T'HH".
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible, with no sub-hour precision.
  static LocalDateTimePattern get DateHourIso => LocalDateTimePatternPatterns.DateHourIsoPatternImpl;

  /// Gets an invariant local date/time pattern which can parse any ISO-8601 compatible value with a calendar date
  /// (in extended format, that is, with separators), regardless of precision in the time part.
  /// Valid values for time include "just hours", "hours and minutes", "hours, minutes and seconds",
  /// and values with fractions of seconds (as far as nanoseconds). The time part must be present, however; this pattern
  /// will not parse date-only values. (It will also not parse ordinal dates or week dates, as described in ISO-8601.)
  ///
  /// This is expressed as an [IPattern] rather than a [LocalDateTimePattern],
  /// as it has no single pattern text.
  ///
  /// Returns an invariant local date/time pattern which is ISO-8601 compatible for all time precisions.
  static IPattern<LocalDateTime> get VariablePrecisionIso => LocalDateTimePatternPatterns.VariablePrecisionIsoPatternImpl;

  /// Gets the pattern text for this pattern, as supplied on creation.
  ///
  /// Returns the pattern text for this pattern, as supplied on creation.
  final String PatternText;

  /// Gets the localization information used in this pattern.
  ///
  /// Returns the localization information used in this pattern.
  final NodaFormatInfo _FormatInfo;

  /// Get the value used as a template for parsing: any field values unspecified
  /// in the pattern are taken from the template.
  ///
  /// Returns the value used as a template for parsing.
  final LocalDateTime TemplateValue;

  /// Maximum two-digit-year in the template to treat as the current century.
  /// If the value parsed is higher than this, the result is adjusted to the previous century.
  /// This value defaults to 30. To create a pattern with a different value, use [WithTwoDigitYearMax].
  ///
  /// Returns the value used for the maximum two-digit-year, in the range 0-99 inclusive.
  final int TwoDigitYearMax;

  /// Returns the pattern that this object delegates to. Mostly useful to avoid this public class
  /// implementing an internal interface.
  @internal
  final IPartialPattern<LocalDateTime> UnderlyingPattern;

  LocalDateTimePattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(String patternText, NodaFormatInfo formatInfo,
      LocalDateTime templateValue, int twoDigitYearMax, IPartialPattern<LocalDateTime> pattern)
      : PatternText = patternText,
        _FormatInfo = formatInfo,
        UnderlyingPattern = pattern,
        TemplateValue = templateValue,
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
  ParseResult<LocalDateTime> Parse(String text) => UnderlyingPattern.Parse(text);

  /// Formats the given local date/time as text according to the rules of this pattern.
  ///
  /// [value]: The local date/time to format.
  ///
  /// Returns the local date/time formatted according to this pattern.
  @override
  String Format(LocalDateTime value) => UnderlyingPattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(LocalDateTime value, StringBuffer builder) => UnderlyingPattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, and template value.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  /// [twoDigitYearMax]: Maximum two-digit-year in the template to treat as the current century.
  ///
  /// Returns a pattern for parsing and formatting local date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  @internal
  static LocalDateTimePattern CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      LocalDateTime templateValue, int twoDigitYearMax) {
    // Dart: null safety checks patternText and formatInfo.
    // Use the "fixed" parser for the common case of the default template value.
    IPattern<LocalDateTime> pattern = templateValue == DefaultTemplateValue && twoDigitYearMax == LocalDatePattern.DefaultTwoDigitYearMax
        ? formatInfo.LocalDateTimePatternParser.ParsePattern(patternText)
        : LocalDateTimePatternParser.NewTemplateValueTwoDigitYearMax(templateValue, twoDigitYearMax).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    pattern = pattern is LocalDateTimePattern ? pattern.UnderlyingPattern : pattern;
    final partialPattern = pattern as IPartialPattern<LocalDateTime>;
    return LocalDateTimePattern._NewPatternTextFormatInfoTemplateValueTwoDigitYearMaxPattern(patternText, formatInfo, templateValue, twoDigitYearMax, partialPattern);
  }

  /// Creates a pattern for the given pattern text, culture, and template value.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields (if omitted, a template value of midnight on 2000-01-01)
  ///
  /// Returns a pattern for parsing and formatting local date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalDateTimePattern Create(String patternText, NodaCultureInfo cultureInfo,
          [LocalDateTime? templateValue]) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), templateValue ?? DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the current thread's current culture.
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
  static LocalDateTimePattern CreateWithCurrentCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalDateTimePattern CreateWithInvariantCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  LocalDateTimePattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  LocalDateTimePattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern like this one, but with the specified template value.
  ///
  /// [newTemplateValue]: The template value for the new pattern, used to fill in unspecified fields.
  ///
  /// Returns a new pattern with the given template value.
  LocalDateTimePattern WithTemplateValue(LocalDateTime newTemplateValue) =>
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
  LocalDateTimePattern WithCalendar(CalendarSystem calendar) =>
      WithTemplateValue(TemplateValue.WithCalendar(calendar));

  /// Creates a pattern like this one, but with a different [TwoDigitYearMax] value.
  ///
  /// [twoDigitYearMax]: The value to use for [TwoDigitYearMax] in the new pattern, in the range 0-99 inclusive.
  ///
  /// Returns a new pattern with the specified maximum two-digit-year.
  LocalDateTimePattern WithTwoDigitYearMax(int twoDigitYearMax) =>
      CreateNodaFormatInfo(PatternText, _FormatInfo, TemplateValue, twoDigitYearMax);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
@internal
abstract final class LocalDateTimePatternPatterns {
  static final LocalDateTimePattern GeneralIsoPatternImpl = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss");
  static final LocalDateTimePattern ExtendedIsoPatternImpl = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF");
  static final LocalDateTimePattern BclRoundtripPatternImpl = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffff");
  static final LocalDateTimePattern FullRoundtripWithoutCalendarImpl = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff");
  static final LocalDateTimePattern FullRoundtripPatternImpl = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffff '('c')'");
  static final LocalDateTimePattern DateHourIsoPatternImpl = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH");
  static final LocalDateTimePattern DateHourMinuteIsoPatternImpl = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm");
  static final IPattern<LocalDateTime> VariablePrecisionIsoPatternImpl = (CompositePatternBuilder<LocalDateTime>()
        ..Add(ExtendedIsoPatternImpl, (time) => true)
        ..Add(DateHourMinuteIsoPatternImpl, (time) => time.Second == 0 && time.NanosecondOfSecond == 0)
        ..Add(DateHourIsoPatternImpl, (time) => time.Minute == 0 && time.Second == 0 && time.NanosecondOfSecond == 0))
      .Build();
}
