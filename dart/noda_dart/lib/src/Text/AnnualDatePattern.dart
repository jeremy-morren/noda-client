// Ported from NodaTime 6e024dde: src/NodaTime/Text/AnnualDatePattern.cs
// Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../AnnualDate.dart';
import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import 'AnnualDatePatternParser.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';

const String _DefaultFormatPattern = "G"; // General, ISO-like

/// Represents a pattern for parsing and formatting [AnnualDate] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class AnnualDatePattern implements IPattern<AnnualDate> {
  @internal
  static final AnnualDate DefaultTemplateValue = AnnualDate(1, 1);

  @internal
  static final PatternBclSupport<AnnualDate> BclSupport =
      PatternBclSupport<AnnualDate>.NewDefaultFormatPatternPatternParser(_DefaultFormatPattern, (fi) => fi.AnnualDatePatternParser);

  /// Gets an invariant annual date pattern which is compatible with the month/day part of ISO-8601.
  /// This corresponds to the text pattern "MM'-'dd".
  ///
  /// Returns an invariant annual date pattern which is compatible with the month/day part of ISO-8601.
  static AnnualDatePattern get Iso => _AnnualDatePatternPatterns.IsoPatternImpl;

  /// Returns the pattern that this object delegates to. Mostly useful to avoid this public class
  /// implementing an internal interface.
  @internal
  final IPartialPattern<AnnualDate> UnderlyingPattern;

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
  final AnnualDate TemplateValue;

  AnnualDatePattern._NewPatternTextFormatInfoTemplateValuePattern(
      this.PatternText, this._FormatInfo, this.TemplateValue, IPartialPattern<AnnualDate> pattern)
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
  ParseResult<AnnualDate> Parse(String text) => UnderlyingPattern.Parse(text);

  /// Formats the given annual date as text according to the rules of this pattern.
  ///
  /// [value]: The annual date to format.
  ///
  /// Returns the annual date formatted according to this pattern.
  @override
  String Format(AnnualDate value) => UnderlyingPattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(AnnualDate value, StringBuffer builder) => UnderlyingPattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, and template value.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  ///
  /// Returns a pattern for parsing and formatting annual dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  @internal
  static AnnualDatePattern CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      AnnualDate templateValue) {
    // Dart: null safety checks patternText and formatInfo.
    // Use the "fixed" parser for the common case of the default template value.
    IPattern<AnnualDate> pattern = templateValue == DefaultTemplateValue
        ? formatInfo.AnnualDatePatternParser.ParsePattern(patternText)
        : AnnualDatePatternParser.NewTemplateValue(templateValue).ParsePattern(patternText, formatInfo);
    // If ParsePattern returns a standard pattern instance, we need to get the underlying partial pattern.
    pattern = pattern is AnnualDatePattern ? pattern.UnderlyingPattern : pattern;
    final partialPattern = pattern as IPartialPattern<AnnualDate>;
    return AnnualDatePattern._NewPatternTextFormatInfoTemplateValuePattern(patternText, formatInfo, templateValue, partialPattern);
  }

  /// Creates a pattern for the given pattern text, culture, and template value.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields (if omitted, a template value of 2000-01-01)
  ///
  /// Returns a pattern for parsing and formatting annual dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static AnnualDatePattern Create(String patternText, NodaCultureInfo cultureInfo, [AnnualDate? templateValue]) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), templateValue ?? DefaultTemplateValue);

  /// Creates a pattern for the given pattern text in the current thread's current culture.
  ///
  /// See the user guide for the available pattern text options. Note that the current culture
  /// is captured at the time this method is called - it is not captured at the point of parsing
  /// or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting annual dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static AnnualDatePattern CreateWithCurrentCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, DefaultTemplateValue);

  /// Creates a pattern for the given pattern text in the invariant culture.
  ///
  /// See the user guide for the available pattern text options.
  ///
  /// [patternText]: Pattern text to create the pattern for
  ///
  /// Returns a pattern for parsing and formatting annual dates.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static AnnualDatePattern CreateWithInvariantCulture(String patternText) =>
      CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, DefaultTemplateValue);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  AnnualDatePattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      CreateNodaFormatInfo(PatternText, formatInfo, TemplateValue);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  AnnualDatePattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern like this one, but with the specified template value.
  ///
  /// [newTemplateValue]: The template value for the new pattern, used to fill in unspecified fields.
  ///
  /// Returns a new pattern with the given template value.
  AnnualDatePattern WithTemplateValue(AnnualDate newTemplateValue) =>
      CreateNodaFormatInfo(PatternText, _FormatInfo, newTemplateValue);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
abstract final class _AnnualDatePatternPatterns {
  static final AnnualDatePattern IsoPatternImpl = AnnualDatePattern.CreateWithInvariantCulture("MM'-'dd");
}
