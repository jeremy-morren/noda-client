// Ported from NodaTime 6e024dde: src/NodaTime/Text/ZonedDateTimePattern.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../Globalization/NodaCultureInfo.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../IDateTimeZoneProvider.dart';
import '../LocalDateTime.dart';
import '../TimeZones/Delegates.dart';
import '../TimeZones/Resolvers.dart';
import '../ZonedDateTime.dart';
import 'IPattern.dart';
import 'LocalDatePattern.dart';
import 'ParseResult.dart';
import 'Patterns/PatternBclSupport.dart';
import 'ZonedDateTimePatternParser.dart';

/// Represents a pattern for parsing and formatting [ZonedDateTime] values.
///
/// Thread safety: When used with a read-only [NodaCultureInfo], this type is immutable and instances
/// may be shared freely between threads. We recommend only using read-only cultures for patterns, although this is
/// not currently enforced.
// [Immutable] // Well, assuming an immutable culture...
final class ZonedDateTimePattern implements IPattern<ZonedDateTime> {
  @internal
  static final ZonedDateTime DefaultTemplateValue = LocalDateTime(2000, 1, 1, 0, 0).InUtc();

  /// Gets an zoned local date/time pattern based on ISO-8601 (down to the second) including offset from UTC and zone ID.
  /// It corresponds to a custom pattern of "uuuu'-'MM'-'dd'T'HH':'mm':'ss z '('o&lt;g&gt;')'" and is available
  /// as the 'G' standard pattern.
  ///
  /// The calendar system is not formatted as part of this pattern, and it cannot be used for parsing as no time zone
  /// provider is included. Call [WithZoneProvider] on the value of this property to obtain a
  /// pattern which can be used for parsing.
  ///
  /// Returns an zoned local date/time pattern based on ISO-8601 (down to the second) including offset from UTC and zone ID.
  static ZonedDateTimePattern get GeneralFormatOnlyIso => ZonedDateTimePatternPatterns.GeneralFormatOnlyPatternImpl;

  /// Returns an invariant zoned date/time pattern based on ISO-8601 (down to the nanosecond) including offset from UTC and zone ID.
  /// It corresponds to a custom pattern of "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF z '('o&lt;g&gt;')'" and is available
  /// as the 'F' standard pattern.
  ///
  /// The calendar system is not formatted as part of this pattern, and it cannot be used for parsing as no time zone
  /// provider is included. Call [WithZoneProvider] on the value of this property to obtain a
  /// pattern which can be used for parsing.
  ///
  /// Returns an invariant zoned date/time pattern based on ISO-8601 (down to the nanosecond) including offset from UTC and zone ID.
  static ZonedDateTimePattern get ExtendedFormatOnlyIso => ZonedDateTimePatternPatterns.ExtendedFormatOnlyPatternImpl;

  final IPattern<ZonedDateTime> _pattern;

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
  final ZonedDateTime TemplateValue;

  /// Gets the resolver which is used to map local date/times to zoned date/times,
  /// handling skipped and ambiguous times appropriately (where the offset isn't specified in the pattern).
  /// This may be null, in which case the pattern can only be used for formatting (not parsing).
  ///
  /// Returns the resolver which is used to map local date/times to zoned date/times.
  final ZoneLocalMappingResolver? Resolver;

  /// Gets the provider which is used to look up time zones when parsing a pattern
  /// which contains a time zone identifier. This may be null, in which case the pattern can
  /// only be used for formatting (not parsing).
  ///
  /// Returns the provider which is used to look up time zones when parsing a pattern
  /// which contains a time zone identifier.
  final IDateTimeZoneProvider? ZoneProvider;

  /// Maximum two-digit-year in the template to treat as the current century.
  /// If the value parsed is higher than this, the result is adjusted to the previous century.
  /// This value defaults to 30. To create a pattern with a different value, use [WithTwoDigitYearMax].
  ///
  /// Returns the value used for the maximum two-digit-year, in the range 0-99 inclusive.
  final int TwoDigitYearMax;

  ZonedDateTimePattern._NewPatternTextFormatInfoTemplateValueResolverZoneProviderTwoDigitYearMaxPattern(String patternText, NodaFormatInfo formatInfo, ZonedDateTime templateValue,
      ZoneLocalMappingResolver? resolver, IDateTimeZoneProvider? zoneProvider, int twoDigitYearMax, IPattern<ZonedDateTime> pattern)
      : PatternText = patternText,
        _FormatInfo = formatInfo,
        TemplateValue = templateValue,
        Resolver = resolver,
        ZoneProvider = zoneProvider,
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
  ParseResult<ZonedDateTime> Parse(String text) => _pattern.Parse(text);

  /// Formats the given zoned date/time as text according to the rules of this pattern.
  ///
  /// [value]: The zoned date/time to format.
  ///
  /// Returns the zoned date/time formatted according to this pattern.
  @override
  String Format(ZonedDateTime value) => _pattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(ZonedDateTime value, StringBuffer builder) => _pattern.AppendFormat(value, builder);

  /// Creates a pattern for the given pattern text, format info, template value, mapping resolver and time zone provider.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [formatInfo]: The format info to use in the pattern
  /// [templateValue]: Template value to use for unspecified fields
  /// [resolver]: Resolver to apply when mapping local date/time values into the zone.
  /// [zoneProvider]: Time zone provider, used when parsing text which contains a time zone identifier.
  /// [twoDigitYearMax]: Maximum two-digit-year in the template to treat as the current century.
  ///
  /// Returns a pattern for parsing and formatting zoned date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static ZonedDateTimePattern _CreateNodaFormatInfo(String patternText, NodaFormatInfo formatInfo,
      ZoneLocalMappingResolver? resolver, IDateTimeZoneProvider? zoneProvider, ZonedDateTime templateValue, int twoDigitYearMax) {
    // Dart: null safety checks patternText and formatInfo.
    var pattern = ZonedDateTimePatternParser.NewTemplateValueResolverZoneProviderTwoDigitYearMax(templateValue, resolver, zoneProvider, twoDigitYearMax).ParsePattern(patternText, formatInfo);
    return ZonedDateTimePattern._NewPatternTextFormatInfoTemplateValueResolverZoneProviderTwoDigitYearMaxPattern(patternText, formatInfo, templateValue, resolver, zoneProvider, twoDigitYearMax, pattern);
  }

  /// Creates a pattern for the given pattern text, culture, resolver, time zone provider, and template value.
  ///
  /// See the user guide for the available pattern text options.
  /// If [zoneProvider] is null, the resulting pattern can be used for formatting
  /// but not parsing.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [cultureInfo]: The culture to use in the pattern
  /// [resolver]: Resolver to apply when mapping local date/time values into the zone.
  /// [zoneProvider]: Time zone provider, used when parsing text which contains a time zone identifier.
  /// [templateValue]: Template value to use for unspecified fields
  ///
  /// Returns a pattern for parsing and formatting zoned date/times.
  ///
  /// Throws [InvalidPatternException] if the pattern text was invalid.
  static ZonedDateTimePattern Create(String patternText, NodaCultureInfo cultureInfo,
          ZoneLocalMappingResolver? resolver, IDateTimeZoneProvider? zoneProvider, ZonedDateTime templateValue) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.GetFormatInfo(cultureInfo), resolver, zoneProvider, templateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text and time zone provider, using a strict resolver, the invariant
  /// culture, and a default template value of midnight January 1st 2000 UTC.
  ///
  /// The resolver is only used if the pattern text doesn't include an offset.
  /// If [zoneProvider] is null, the resulting pattern can be used for formatting
  /// but not parsing.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [zoneProvider]: Time zone provider, used when parsing text which contains a time zone identifier.
  ///
  /// Returns a pattern for parsing and formatting zoned date/times.
  static ZonedDateTimePattern CreateWithInvariantCulture(String patternText, IDateTimeZoneProvider? zoneProvider) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.InvariantInfo, Resolvers.StrictResolver, zoneProvider, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the given pattern text and time zone provider, using a strict resolver, the current
  /// culture, and a default template value of midnight January 1st 2000 UTC.
  ///
  /// The resolver is only used if the pattern text doesn't include an offset.
  /// If [zoneProvider] is null, the resulting pattern can be used for formatting
  /// but not parsing. Note that the current culture is captured at the time this method is called
  /// - it is not captured at the point of parsing or formatting values.
  ///
  /// [patternText]: Pattern text to create the pattern for
  /// [zoneProvider]: Time zone provider, used when parsing text which contains a time zone identifier.
  ///
  /// Returns a pattern for parsing and formatting zoned date/times.
  static ZonedDateTimePattern CreateWithCurrentCulture(String patternText, IDateTimeZoneProvider? zoneProvider) =>
      _CreateNodaFormatInfo(patternText, NodaFormatInfo.CurrentInfo, Resolvers.StrictResolver, zoneProvider, DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax);

  /// Creates a pattern for the same original localization information as this pattern, but with the specified
  /// pattern text.
  ///
  /// [patternText]: The pattern text to use in the new pattern.
  ///
  /// Returns a new pattern with the given pattern text.
  ZonedDateTimePattern WithPatternText(String patternText) =>
      _CreateNodaFormatInfo(patternText, _FormatInfo, Resolver, ZoneProvider, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// localization information.
  ///
  /// [formatInfo]: The localization information to use in the new pattern.
  ///
  /// Returns a new pattern with the given localization information.
  ZonedDateTimePattern _WithFormatInfo(NodaFormatInfo formatInfo) =>
      _CreateNodaFormatInfo(PatternText, formatInfo, Resolver, ZoneProvider, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// culture.
  ///
  /// [cultureInfo]: The culture to use in the new pattern.
  ///
  /// Returns a new pattern with the given culture.
  ZonedDateTimePattern WithCulture(NodaCultureInfo cultureInfo) =>
      _WithFormatInfo(NodaFormatInfo.GetFormatInfo(cultureInfo));

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// resolver.
  ///
  /// [resolver]: The new local mapping resolver to use.
  ///
  /// Returns a new pattern with the given resolver.
  ZonedDateTimePattern WithResolver(ZoneLocalMappingResolver? resolver) =>
      Resolver == resolver ? this : _CreateNodaFormatInfo(PatternText, _FormatInfo, resolver, ZoneProvider, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern for the same original pattern text as this pattern, but with the specified
  /// time zone provider.
  ///
  /// If [newZoneProvider] is null, the resulting pattern can be used for formatting
  /// but not parsing.
  ///
  /// [newZoneProvider]: The new time zone provider to use.
  ///
  /// Returns a new pattern with the given time zone provider.
  ZonedDateTimePattern WithZoneProvider(IDateTimeZoneProvider? newZoneProvider) =>
      newZoneProvider == ZoneProvider ? this : _CreateNodaFormatInfo(PatternText, _FormatInfo, Resolver, newZoneProvider, TemplateValue, TwoDigitYearMax);

  /// Creates a pattern like this one, but with the specified template value.
  ///
  /// [newTemplateValue]: The template value for the new pattern, used to fill in unspecified fields.
  ///
  /// Returns a new pattern with the given template value.
  ZonedDateTimePattern WithTemplateValue(ZonedDateTime newTemplateValue) =>
      newTemplateValue == TemplateValue ? this : _CreateNodaFormatInfo(PatternText, _FormatInfo, Resolver, ZoneProvider, newTemplateValue, TwoDigitYearMax);

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
  ZonedDateTimePattern WithCalendar(CalendarSystem calendar) =>
      WithTemplateValue(TemplateValue.WithCalendar(calendar));

  /// Creates a pattern like this one, but with a different [TwoDigitYearMax] value.
  ///
  /// [twoDigitYearMax]: The value to use for [TwoDigitYearMax] in the new pattern, in the range 0-99 inclusive.
  ///
  /// Returns a new pattern with the specified maximum two-digit-year.
  ZonedDateTimePattern WithTwoDigitYearMax(int twoDigitYearMax) =>
      _CreateNodaFormatInfo(PatternText, _FormatInfo, Resolver, ZoneProvider, TemplateValue, twoDigitYearMax);
}

/// Class whose existence is solely to avoid type initialization order issues, most of which stem
/// from needing NodaFormatInfo.InvariantInfo...
@internal
abstract final class ZonedDateTimePatternPatterns {
  static final ZonedDateTimePattern GeneralFormatOnlyPatternImpl = ZonedDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss z '('o<g>')'", null);
  static final ZonedDateTimePattern ExtendedFormatOnlyPatternImpl = ZonedDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF z '('o<g>')'", null);
  static final PatternBclSupport<ZonedDateTime> BclSupport =
      PatternBclSupport<ZonedDateTime>.NewDefaultFormatPatternPatternParser("G", (fi) => fi.ZonedDateTimePatternParser);
}
