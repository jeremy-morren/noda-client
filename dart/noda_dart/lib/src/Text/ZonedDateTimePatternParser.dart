// Ported from NodaTime 6e024dde: src/NodaTime/Text/ZonedDateTimePatternParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../AmbiguousTimeException.dart';
import '../DateTimeZone.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../IDateTimeZoneProvider.dart';
import '../Offset.dart';
import '../Offset.dart' as nt show Offset;
import '../SkippedTimeException.dart';
import '../TimeZones/Delegates.dart';
import '../Utility/Preconditions.dart';
import '../ZonedDateTime.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalDatePatternParser.dart';
import 'LocalDateTimePatternParser.dart';
import 'LocalTimePatternParser.dart';
import 'OffsetPattern.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/DatePatternHelper.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'Patterns/TimePatternHelper.dart';
import 'TextErrorMessages.generated.dart';
import 'ValueCursor.dart';
import 'ZonedDateTimePattern.dart';

@internal
final class ZonedDateTimePatternParser implements IPatternParser<ZonedDateTime> {
  final ZonedDateTime _templateValue;
  final IDateTimeZoneProvider? _zoneProvider;
  final ZoneLocalMappingResolver? _resolver;
  final int _twoDigitYearMax;

  static final Map<String, CharacterHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '/': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<ZonedDateTime>),
    'T': (pattern, builder) => builder.AddLiteralChar('T', ParseResult.MismatchedCharacter<ZonedDateTime>),
    'y': DatePatternHelper.CreateYearOfEraHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>((value) => value.YearOfEra, (bucket, value) => bucket.Date.YearOfEra = value),
    'u': SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>
        (4, PatternFields.Year, -9998, 9999, (value) => value.Year, (bucket, value) => bucket.Date.Year = value),
    'M': DatePatternHelper.CreateMonthOfYearHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>
        ((value) => value.Month, (bucket, value) => bucket.Date.MonthOfYearText = value, (bucket, value) => bucket.Date.MonthOfYearNumeric = value),
    'd': DatePatternHelper.CreateDayHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>
        ((value) => value.Day, (value) => value.DayOfWeek.value, (bucket, value) => bucket.Date.DayOfMonth = value, (bucket, value) => bucket.Date.DayOfWeek = value),
    '.': TimePatternHelper.CreatePeriodHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ';': TimePatternHelper.CreateCommaDotHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ':': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<ZonedDateTime>),
    'h': SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>
        (2, PatternFields.Hours12, 1, 12, (value) => value.ClockHourOfHalfDay, (bucket, value) => bucket.Time.Hours12 = value),
    'H': SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>
        (2, PatternFields.Hours24, 0, 24, (value) => value.Hour, (bucket, value) => bucket.Time.Hours24 = value),
    'm': SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>
        (2, PatternFields.Minutes, 0, 59, (value) => value.Minute, (bucket, value) => bucket.Time.Minutes = value),
    's': SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>
        (2, PatternFields.Seconds, 0, 59, (value) => value.Second, (bucket, value) => bucket.Time.Seconds = value),
    'f': TimePatternHelper.CreateFractionHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    'F': TimePatternHelper.CreateFractionHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    't': TimePatternHelper.CreateAmPmHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>((time) => time.Hour, (bucket, value) => bucket.Time.AmPm = value),
    'c': DatePatternHelper.CreateCalendarHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>((value) => value.LocalDateTime.Calendar, (bucket, value) => bucket.Date.Calendar = value),
    'g': DatePatternHelper.CreateEraHandler<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>((value) => value.Era, (bucket) => bucket.Date),
    'z': _HandleZone,
    'x': _HandleZoneAbbreviation,
    'o': _HandleOffset,
    'l': (cursor, builder) => builder.AddEmbeddedLocalPartial(cursor, (bucket) => bucket.Date, (bucket) => bucket.Time, (value) => value.Date, (value) => value.TimeOfDay, (value) => value.LocalDateTime),
  };

  ZonedDateTimePatternParser.NewTemplateValueResolverZoneProviderTwoDigitYearMax(ZonedDateTime templateValue, ZoneLocalMappingResolver? resolver, IDateTimeZoneProvider? zoneProvider, int twoDigitYearMax)
      : _templateValue = templateValue,
        _resolver = resolver,
        _zoneProvider = zoneProvider,
        _twoDigitYearMax = twoDigitYearMax {
    Preconditions.CheckArgumentRange('twoDigitYearMax', twoDigitYearMax, 0, 99);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<ZonedDateTime> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Nullity check is performed in ZonedDateTimePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length == 1) {
      return switch (patternText[0]) {
        'G' => ZonedDateTimePatternPatterns.GeneralFormatOnlyPatternImpl
            .WithZoneProvider(_zoneProvider)
            .WithResolver(_resolver),
        'F' => ZonedDateTimePatternPatterns.ExtendedFormatOnlyPatternImpl
            .WithZoneProvider(_zoneProvider)
            .WithResolver(_resolver),
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(ZonedDateTime)])
      };
    }

    var patternBuilder = SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket>.NewFormatInfoBucketProvider(formatInfo,
        () => _ZonedDateTimePatternParserZonedDateTimeParseBucket.NewTemplateValueResolverZoneProviderTwoDigitYearMax(_templateValue, _resolver, _zoneProvider, _twoDigitYearMax));
    if (_zoneProvider == null || _resolver == null) {
      patternBuilder.SetFormatOnly();
    }
    patternBuilder.ParseCustomPattern(patternText, _PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    return patternBuilder.Build(_templateValue);
  }

  static void _HandleZone(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket> builder) {
    builder.AddField(PatternFields.Zone, pattern.Current);
    builder.AddParseAction(_ParseZone);
    builder.AddFormatAction((value, sb) => sb.write(value.Zone.Id));
  }

  static void _HandleZoneAbbreviation(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket> builder) {
    builder.AddField(PatternFields.ZoneAbbreviation, pattern.Current);
    builder.SetFormatOnly();
    builder.AddFormatAction((value, sb) => sb.write(value.GetZoneInterval().Name));
  }

  static void _HandleOffset(PatternCursor pattern,
      SteppedPatternBuilder<ZonedDateTime, _ZonedDateTimePatternParserZonedDateTimeParseBucket> builder) {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    String embeddedPattern = pattern.GetEmbeddedPattern();
    var offsetPattern = OffsetPattern.CreateNodaFormatInfo(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern<Offset>(offsetPattern, (bucket, offset) => bucket.Offset = offset, (zdt) => zdt.Offset);
  }

  static ParseResult<ZonedDateTime>? _ParseZone(ValueCursor value, _ZonedDateTimePatternParserZonedDateTimeParseBucket bucket) => bucket.ParseZone(value);
}

final class _ZonedDateTimePatternParserZonedDateTimeParseBucket extends ParseBucket<ZonedDateTime> {
  final LocalDatePatternParserLocalDateParseBucket Date;
  final LocalTimePatternParserLocalTimeParseBucket Time;
  DateTimeZone _Zone;
  nt.Offset Offset = nt.Offset.Zero;
  final ZoneLocalMappingResolver? _resolver;
  final IDateTimeZoneProvider? _zoneProvider;

  _ZonedDateTimePatternParserZonedDateTimeParseBucket.NewTemplateValueResolverZoneProviderTwoDigitYearMax(ZonedDateTime templateValue, ZoneLocalMappingResolver? resolver, IDateTimeZoneProvider? zoneProvider, int twoDigitYearMax)
      : Date = LocalDatePatternParserLocalDateParseBucket.NewTemplateValueTwoDigitYearMax(templateValue.Date, twoDigitYearMax),
        Time = LocalTimePatternParserLocalTimeParseBucket.NewTemplateValue(templateValue.TimeOfDay),
        _Zone = templateValue.Zone,
        _resolver = resolver,
        _zoneProvider = zoneProvider;

  ParseResult<ZonedDateTime>? ParseZone(ValueCursor value) {
    DateTimeZone? zone = _TryParseFixedZone(value) ?? _TryParseProviderZone(value);

    if (zone == null) {
      return ParseResult.NoMatchingZoneId<ZonedDateTime>(value);
    }
    _Zone = zone;
    return null;
  }

  /// Attempts to parse a fixed time zone from "UTC" with an optional
  /// offset, expressed as +HH, +HH:mm, +HH:mm:ss or +HH:mm:ss.fff - i.e. the
  /// general format. If it manages, it will move the cursor and return the
  /// zone. Otherwise, it will return null and the cursor will remain where
  /// it was.
  static DateTimeZone? _TryParseFixedZone(ValueCursor value) {
    if (value.CompareOrdinal(DateTimeZone.UtcId) != 0) {
      return null;
    }
    value.Move(value.Index + 3);
    var pattern = OffsetPattern.GeneralInvariant.UnderlyingPattern;
    var parseResult = pattern.ParsePartial(value);
    return parseResult.Success ? DateTimeZone.ForOffset(parseResult.Value) : DateTimeZone.Utc;
  }

  /// Tries to parse a time zone ID from the provider. Returns the zone
  /// on success (after moving the cursor to the end of the ID) or null on failure
  /// (leaving the cursor where it was).
  DateTimeZone? _TryParseProviderZone(ValueCursor value) {
    // Note: this method only called when zoneProvider is non-null, i.e. not a format-only pattern.

    // The IDs from the provider are guaranteed to be in order (using ordinal comparisons).
    // Use a binary search to find a match, then make sure it's the longest possible match.
    var ids = _zoneProvider!.Ids;
    int lowerBound = 0;          // Inclusive
    int upperBound = ids.length; // Exclusive
    while (lowerBound < upperBound) {
      int guess = (lowerBound + upperBound) ~/ 2;
      int result = value.CompareOrdinal(ids[guess]);
      if (result < 0) {
        // Guess is later than our text: lower the upper bound
        upperBound = guess;
      } else if (result > 0) {
        // Guess is earlier than our text: raise the lower bound
        lowerBound = guess + 1;
      } else {
        // We've found a match! But it may not be as long as it
        // could be. Keep track of a "longest match so far" (starting with the match we've found),
        // and keep looking through the IDs until we find an ID which doesn't start with that "longest
        // match so far", at which point we know we're done.
        //
        // We can't just look through all the IDs from "guess" to "lowerBound" and stop when we hit
        // a non-match against "value", because of situations like this:
        // value=Etc/GMT-12
        // guess=Etc/GMT-1
        // IDs includes { Etc/GMT-1, Etc/GMT-10, Etc/GMT-11, Etc/GMT-12, Etc/GMT-13 }
        // We can't stop when we hit Etc/GMT-10, because otherwise we won't find Etc/GMT-12.
        // We *can* stop when we get to Etc/GMT-13, because by then our longest match so far will
        // be Etc/GMT-12, and we know that anything beyond Etc/GMT-13 won't match that.
        // We can also stop when we hit upperBound, without any more comparisons.

        String longestSoFar = ids[guess];
        for (int i = guess + 1; i < upperBound; i++) {
          String candidate = ids[i];
          if (candidate.length < longestSoFar.length) {
            break;
          }
          // Dart: string.CompareOrdinal(longestSoFar, 0, candidate, 0, longestSoFar.Length).
          if (longestSoFar.compareTo(candidate.substring(0, longestSoFar.length)) != 0) {
            break;
          }
          if (value.CompareOrdinal(candidate) == 0) {
            longestSoFar = candidate;
          }
        }
        value.Move(value.Index + longestSoFar.length);
        return _zoneProvider[longestSoFar];
      }
    }
    return null;
  }

  @override
  ParseResult<ZonedDateTime> CalculateValue(PatternFields usedFields, String text) {
    var localResult = LocalDateTimePatternParserLocalDateTimeParseBucket.CombineBuckets(usedFields, Date, Time, text);
    if (!localResult.Success) {
      return localResult.ConvertError<ZonedDateTime>();
    }

    var localDateTime = localResult.Value;

    // No offset - so just use the resolver
    if ((usedFields & PatternFields.EmbeddedOffset) == PatternFields.None) {
      try {
        // Note: this method is only called when resolver is non-null, i.e. not a format-only pattern.
        return ParseResult.ForValue<ZonedDateTime>(_Zone.ResolveLocal(localDateTime, _resolver!));
      } on SkippedTimeException {
        return ParseResult.SkippedLocalTime<ZonedDateTime>(text);
      } on AmbiguousTimeException {
        return ParseResult.AmbiguousLocalTime<ZonedDateTime>(text);
      }
    }

    // We were given an offset, so we can resolve and validate using that
    var mapping = _Zone.MapLocal(localDateTime);
    ZonedDateTime result;
    switch (mapping.Count) {
      // If the local time was skipped, the offset has to be invalid.
      case 0:
        return ParseResult.InvalidOffset<ZonedDateTime>(text);
      case 1:
        result = mapping.First(); // We'll validate in a minute
        break;
      case 2:
        result = mapping.First().Offset == Offset ? mapping.First() : mapping.Last();
        break;
      default:
        throw StateError("Mapping has count outside range 0-2; should not happen.");
    }
    if (result.Offset != Offset) {
      return ParseResult.InvalidOffset<ZonedDateTime>(text);
    }
    return ParseResult.ForValue<ZonedDateTime>(result);
  }
}
