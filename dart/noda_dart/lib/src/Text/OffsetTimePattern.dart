// Ported from NodaTime 6e024dde: src/NodaTime/Text/OffsetTimePattern.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../LocalTime.dart';
import '../Offset.dart';
import '../OffsetTime.dart';
import 'IPattern.dart';
import 'OffsetTimePatternParser.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

/// Represents a pattern for parsing and formatting [OffsetTime] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class OffsetTimePattern implements IPattern<OffsetTime> {
  @internal
  static final OffsetTime DefaultTemplateValue = LocalTime.Midnight.WithOffset(Offset.Zero);

  /// Gets an invariant offset time pattern based on ISO-8601 (down to the second), including offset from UTC.
  ///
  /// This corresponds to a custom pattern of "HH':'mm':'sso&lt;G&gt;". It is available as the "G"
  /// standard pattern (even though it is invariant).
  ///
  /// Returns an invariant offset time pattern based on ISO-8601 (down to the second), including offset from UTC.
  static OffsetTimePattern get GeneralIso => OffsetTimePatternPatterns.GeneralIsoPatternImpl;

  /// Gets an invariant offset time pattern based on ISO-8601 (down to the nanosecond), including offset from UTC.
  ///
  /// This corresponds to a custom pattern of "HH':'mm':'ss;FFFFFFFFFo&lt;G&gt;".
  /// This will round-trip all values, and is available as the "o" standard pattern.
  ///
  /// Returns an invariant offset time pattern based on ISO-8601 (down to the nanosecond), including offset from UTC.
  static OffsetTimePattern get ExtendedIso => OffsetTimePatternPatterns.ExtendedIsoPatternImpl;

  /// Gets an invariant offset time pattern based on RFC 3339 (down to the nanosecond), including offset from UTC
  /// as hours and minutes only.
  ///
  /// The minutes part of the offset is always included, but any sub-minute component
  /// of the offset is lost. An offset of zero is formatted as 'Z', but all of 'Z', '+00:00' and '-00:00' are parsed
  /// the same way. The RFC 3339 meaning of '-00:00' is not supported by Noda Time.
  /// Note that parsing is case-sensitive (so 'T' and 'Z' must be upper case).
  /// This pattern corresponds to a custom pattern of
  /// "HH':'mm':'ss;FFFFFFFFFo&lt;Z+HH:mm&gt;".
  ///
  /// Returns an invariant offset time pattern based on RFC 3339 (down to the nanosecond), including offset from UTC
  /// as hours and minutes only.
  static OffsetTimePattern get Rfc3339 => OffsetTimePatternPatterns.Rfc3339PatternImpl;

  final IPattern<OffsetTime> _pattern;

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
  final OffsetTime TemplateValue;

  OffsetTimePattern._NewPatternTextFormatInfoTemplateValuePattern(String patternText, NodaFormatInfo formatInfo, OffsetTime templateValue,
      IPattern<OffsetTime> pattern)
      : PatternText = patternText,
        FormatInfo = formatInfo,
        TemplateValue = templateValue,
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
  ParseResult<OffsetTime> Parse(String text) => _pattern.Parse(text);

  /// Formats the given offset time as text according to the rules of this pattern.
  ///
  /// [value]: The offset time to format.
  ///
  /// Returns the offset time formatted according to this pattern.
  @override
  String Format(OffsetTime value) => _pattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(OffsetTime value, StringBuffer builder) => _pattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, and template value.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  ///
  /// Returns a pattern for parsing and formatting offset times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetTimePattern _CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      OffsetTime templateValue) {
    // Dart: null safety checks patternText and formatInfo.
    var pattern = OffsetTimePatternParser.NewTemplateValue(templateValue).ParsePattern(patternText, formatInfo);
    return OffsetTimePattern._NewPatternTextFormatInfoTemplateValuePattern(patternText, formatInfo, templateValue, pattern);
  }

  /// Creates a pattern for the given pattern text, culture, and template value.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  ///
  /// Returns a pattern for parsing and formatting local times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetTimePattern Create(String patternText, NodaCultureInfo cultureInfo, OffsetTime templateValue) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), templateValue);

  /// Creates a pattern for the given pattern text in the invariant culture, using the default
  /// template value of midnight January 1st 2000 at an offset of 0.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting local times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static OffsetTimePattern CreateWithInvariantCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, DefaultTemplateValue);

  /// Creates a pattern for the given pattern text in the current culture, using the default
  /// template value of midnight January 1st 2000 at an offset of 0.
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
  static OffsetTimePattern CreateWithCurrentCulture(String patternText) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, DefaultTemplateValue);

  /// Creates a pattern for the same original localization information as this pattern, but with the specified
  /// pattern text.
  ///
  /// [patternText]: The pattern text to use in the new pattern.
  ///
  /// Returns a new pattern with the given pattern text.
  OffsetTimePattern WithPatternText(String patternText) =>
      _CreateNodaFormatInfo(patternText, FormatInfo, TemplateValue);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  OffsetTimePattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      _CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  OffsetTimePattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern for the same original pattern text and culture as this pattern, but with
  /// the specified template value.
  ///
  /// [newTemplateValue]: The template value to use in the new pattern.
  ///
  /// Returns a new pattern with the given template value.
  OffsetTimePattern WithTemplateValue(OffsetTime newTemplateValue) =>
      _CreateNodaFormatInfo(PatternText, FormatInfo, newTemplateValue);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
@internal
abstract final class OffsetTimePatternPatterns {
  static final OffsetTimePattern GeneralIsoPatternImpl = OffsetTimePattern._CreateNodaFormatInfo("HH':'mm':'sso<G>", NodaFormatInfo.InvariantInfo, OffsetTimePattern.DefaultTemplateValue);
  static final OffsetTimePattern ExtendedIsoPatternImpl = OffsetTimePattern._CreateNodaFormatInfo("HH':'mm':'ss;FFFFFFFFFo<G>", NodaFormatInfo.InvariantInfo, OffsetTimePattern.DefaultTemplateValue);
  static final OffsetTimePattern Rfc3339PatternImpl = OffsetTimePattern._CreateNodaFormatInfo("HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>", NodaFormatInfo.InvariantInfo, OffsetTimePattern.DefaultTemplateValue);
  static final PatternBclSupport<OffsetTime> BclSupport =
      PatternBclSupport<OffsetTime>.NewDefaultFormatPatternPatternParser("G", (fi) => fi.OffsetTimePatternParser);
}
