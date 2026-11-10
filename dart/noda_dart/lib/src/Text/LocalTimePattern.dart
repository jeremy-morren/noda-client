// Ported from NodaTime 6e024dde: src/NodaTime/Text/LocalTimePattern.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../LocalTime.dart';
import 'CompositePatternBuilder.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'LocalTimePatternParser.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

const String _DefaultFormatPattern = "T"; // Long

/// Represents a pattern for parsing and formatting [LocalTime] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class LocalTimePattern implements IPattern<LocalTime> {
  /// Gets an invariant local time pattern which is ISO-8601 compatible, providing up to 9 decimal places.
  /// (These digits are omitted when unnecessary.)
  /// This corresponds to the text pattern "HH':'mm':'ss;FFFFFFFFF".
  ///
  /// This pattern corresponds to the 'o' standard pattern.
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible, providing up to 9 decimal places.
  static LocalTimePattern get ExtendedIso => LocalTimePatternPatterns.ExtendedIsoPatternImpl;

  /// Gets an invariant local time pattern which is ISO-8601 compatible, providing exactly 9 decimal places.
  /// This corresponds to the text pattern "HH':'mm':'ss;fffffffff".
  ///
  /// This pattern corresponds to the 'O' standard pattern.
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible, providing exactly 9 decimal places.
  static LocalTimePattern get LongExtendedIso => LocalTimePatternPatterns.LongExtendedIsoPatternImpl;

  /// Gets an invariant local time pattern which is ISO-8601 compatible, with precision of just seconds.
  /// This corresponds to the text pattern "HH':'mm':'ss".
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible, with no sub-second precision.
  static LocalTimePattern get GeneralIso => LocalTimePatternPatterns.GeneralIsoPatternImpl;

  /// Gets an invariant local time pattern which is ISO-8601 compatible, with precision of just minutes.
  /// This corresponds to the text pattern "HH':'mm".
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible, with no sub-minute precision.
  static LocalTimePattern get HourMinuteIso => LocalTimePatternPatterns.HourMinuteIsoPatternImpl;

  /// Gets an invariant local time pattern which is ISO-8601 compatible, with a precision of just hours.
  /// This corresponds to the text pattern "HH".
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible, with no sub-hour precision.
  static LocalTimePattern get HourIso => LocalTimePatternPatterns.HourIsoPatternImpl;

  /// Gets an invariant local time pattern which can parse any ISO-8601 compatible value
  /// (in extended format, that is, with separators), regardless of precision.
  /// Valid values include "just hours", "hours and minutes", "hours, minutes and seconds",
  /// and values with fractions of seconds (as far as nanoseconds).
  ///
  /// This is expressed as an [IPattern] rather than a [LocalTimePattern],
  /// as it has no single pattern text.
  ///
  /// Returns an invariant local time pattern which is ISO-8601 compatible for all precisions.
  static IPattern<LocalTime> get VariablePrecisionIso => LocalTimePatternPatterns.VariablePrecisionIsoPatternImpl;

  @internal
  static final PatternBclSupport<LocalTime> BclSupport =
      PatternBclSupport<LocalTime>.NewDefaultFormatPatternPatternParser(_DefaultFormatPattern, (fi) => fi.LocalTimePatternParser);

  /// Returns the pattern that this object delegates to. Mostly useful to avoid this public class
  /// implementing an internal interface.
  @internal
  final IPartialPattern<LocalTime> UnderlyingPattern;

  /// Gets the pattern text for this pattern, as supplied on creation.
  ///
  /// Returns the pattern text for this pattern, as supplied on creation.
  final String PatternText;

  /// Gets the localization information used in this pattern.
  final NodaFormatInfo _FormatInfo;

  /// Gets the value used as a template for parsing: any field values unspecified
  /// in the pattern are taken from the template.
  ///
  /// Returns the value used as a template for parsing.
  final LocalTime TemplateValue;

  LocalTimePattern._NewPatternTextFormatInfoTemplateValuePattern(
      this.PatternText, this._FormatInfo, this.TemplateValue, IPartialPattern<LocalTime> pattern)
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
  ParseResult<LocalTime> Parse(String text) => UnderlyingPattern.Parse(text);

  /// Formats the given local time as text according to the rules of this pattern.
  ///
  /// [value]: The local time to format.
  ///
  /// Returns the local time formatted according to this pattern.
  @override
  String Format(LocalTime value) => UnderlyingPattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(LocalTime value, StringBuffer builder) => UnderlyingPattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, and template value.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  ///
  /// Returns a pattern for parsing and formatting local times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  @internal
  static LocalTimePattern CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      LocalTime templateValue) {
    // Dart: null safety checks patternText and formatInfo.
    // Use the "fixed" parser for the common case of the default template value.
    IPattern<LocalTime> pattern = templateValue == LocalTime.Midnight
        ? formatInfo.LocalTimePatternParser.ParsePattern(patternText)
        : LocalTimePatternParser(templateValue).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    // (Alternatively, we could just return it directly, instead of creating a new object.)
    pattern = pattern is LocalTimePattern ? pattern.UnderlyingPattern : pattern;
    final partialPattern = pattern as IPartialPattern<LocalTime>;
    return LocalTimePattern._NewPatternTextFormatInfoTemplateValuePattern(patternText, formatInfo, templateValue, partialPattern);
  }

  /// Creates a pattern for the given pattern text, culture, and template value.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields (if omitted, a template value of midnight)
  ///
  /// Returns a pattern for parsing and formatting local times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalTimePattern Create(String patternText, NodaCultureInfo cultureInfo, [LocalTime? templateValue]) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), templateValue ?? LocalTime.Midnight);

  /// Creates a pattern for the given pattern text in the current thread's current culture.
  ///
  /// See the user guide for the available pattern text options. Note that the current culture
  /// is captured at the time this method is called - it is not captured at the point of parsing
  /// or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalTimePattern CreateWithCurrentCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, LocalTime.Midnight);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static LocalTimePattern CreateWithInvariantCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, LocalTime.Midnight);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  LocalTimePattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  LocalTimePattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern like this one, but with the specified template value.
  ///
  /// [newTemplateValue]: The template value for the new pattern, used to fill in unspecified fields.
  ///
  /// Returns a new pattern with the given template value.
  LocalTimePattern WithTemplateValue(LocalTime newTemplateValue) =>
      CreateNodaFormatInfo(PatternText, _FormatInfo, newTemplateValue);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
@internal
abstract final class LocalTimePatternPatterns {
  static final LocalTimePattern ExtendedIsoPatternImpl = LocalTimePattern.CreateWithInvariantCulture("HH':'mm':'ss;FFFFFFFFF");
  static final LocalTimePattern LongExtendedIsoPatternImpl = LocalTimePattern.CreateWithInvariantCulture("HH':'mm':'ss;fffffffff");
  static final LocalTimePattern GeneralIsoPatternImpl = LocalTimePattern.CreateWithInvariantCulture("HH':'mm':'ss");
  static final LocalTimePattern HourIsoPatternImpl = LocalTimePattern.CreateWithInvariantCulture("HH");
  static final LocalTimePattern HourMinuteIsoPatternImpl = LocalTimePattern.CreateWithInvariantCulture("HH':'mm");
  static final IPattern<LocalTime> VariablePrecisionIsoPatternImpl = (CompositePatternBuilder<LocalTime>()
        ..Add(ExtendedIsoPatternImpl, (time) => true)
        ..Add(HourMinuteIsoPatternImpl, (time) => time.Second == 0 && time.NanosecondOfSecond == 0)
        ..Add(HourIsoPatternImpl, (time) => time.Minute == 0 && time.Second == 0 && time.NanosecondOfSecond == 0))
      .Build();
}
