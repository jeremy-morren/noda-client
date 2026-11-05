// Ported from NodaTime 3.3.0: src/NodaTime/Text/ZonedDateTimePatternParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  AmbiguousTimeError,
  DatePatternHelper,
  DateTimeZone,
  InvalidOperationError,
  InvalidPatternError,
  LocalDatePatternParserLocalDateParseBucket,
  LocalDateTimePatternParserLocalDateTimeParseBucket,
  LocalTimePatternParserLocalTimeParseBucket,
  Offset,
  OffsetPattern,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SkippedTimeError,
  SteppedPatternBuilder,
  TextErrorMessages,
  TimePatternHelper,
  ZonedDateTimePattern,
} from "../internal.ts";
import type {
  CharacterHandler,
  IDateTimeZoneProvider,
  IPattern,
  IPatternParser,
  NodaFormatInfo,
  PatternCursor,
  ValueCursor,
  ZoneLocalMappingResolver,
  ZonedDateTime,
} from "../internal.ts";

let patternCharacterHandlers: Map<string, CharacterHandler<ZonedDateTime, ZonedDateTimePatternParserZonedDateTimeParseBucket>> | undefined;

class ZonedDateTimePatternParserZonedDateTimeParseBucket extends ParseBucket<ZonedDateTime> {
  readonly Date: LocalDatePatternParserLocalDateParseBucket;
  readonly Time: LocalTimePatternParserLocalTimeParseBucket;
  private _zone: DateTimeZone;
  Offset: Offset;
  private readonly _resolver: ZoneLocalMappingResolver | null;
  private readonly _zoneProvider: IDateTimeZoneProvider | null;

  constructor(templateValue: ZonedDateTime, resolver: ZoneLocalMappingResolver | null, zoneProvider: IDateTimeZoneProvider | null, twoDigitYearMax: number) {
    super();
    this.Date = new LocalDatePatternParserLocalDateParseBucket(templateValue.Date, twoDigitYearMax);
    this.Time = new LocalTimePatternParserLocalTimeParseBucket(templateValue.TimeOfDay);
    this._zone = templateValue.Zone;
    // Not assigned in NodaTime's constructor, so it has the default value (an offset of zero).
    this.Offset = Offset.Zero;
    this._resolver = resolver;
    this._zoneProvider = zoneProvider;
  }

  ParseZone(value: ValueCursor): ParseResult<ZonedDateTime> | null {
    const zone: DateTimeZone | null = ZonedDateTimePatternParserZonedDateTimeParseBucket.TryParseFixedZone(value) ?? this.TryParseProviderZone(value);

    if (zone === null) {
      return ParseResult.NoMatchingZoneId<ZonedDateTime>(value);
    }
    this._zone = zone;
    return null;
  }

  /**
   * Attempts to parse a fixed time zone from "UTC" with an optional
   * offset, expressed as +HH, +HH:mm, +HH:mm:ss or +HH:mm:ss.fff - i.e. the
   * general format. If it manages, it will move the cursor and return the
   * zone. Otherwise, it will return null and the cursor will remain where
   * it was.
   */
  private static TryParseFixedZone(value: ValueCursor): DateTimeZone | null {
    if (value.CompareOrdinal(DateTimeZone.UtcId) !== 0) {
      return null;
    }
    value.Move(value.Index + 3);
    const pattern = OffsetPattern.GeneralInvariant.UnderlyingPattern;
    const parseResult = pattern.ParsePartial(value);
    return parseResult.Success ? DateTimeZone.ForOffset(parseResult.Value) : DateTimeZone.Utc;
  }

  /**
   * Tries to parse a time zone ID from the provider. Returns the zone
   * on success (after moving the cursor to the end of the ID) or null on failure
   * (leaving the cursor where it was).
   */
  private TryParseProviderZone(value: ValueCursor): DateTimeZone | null {
    // Note: this method only called when zoneProvider is non-null, i.e. not a format-only pattern.

    // The IDs from the provider are guaranteed to be in order (using ordinal comparisons).
    // Use a binary search to find a match, then make sure it's the longest possible match.
    const ids = this._zoneProvider!.Ids;
    let lowerBound = 0;          // Inclusive
    let upperBound = ids.length; // Exclusive
    while (lowerBound < upperBound) {
      const guess = (lowerBound + upperBound) >> 1;
      const result = value.CompareOrdinal(ids[guess]!);
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

        let longestSoFar = ids[guess]!;
        for (let i = guess + 1; i < upperBound; i++) {
          const candidate = ids[i]!;
          if (candidate.length < longestSoFar.length) {
            break;
          }
          // string.CompareOrdinal(longestSoFar, 0, candidate, 0, longestSoFar.Length) != 0
          if (!candidate.startsWith(longestSoFar)) {
            break;
          }
          if (value.CompareOrdinal(candidate) === 0) {
            longestSoFar = candidate;
          }
        }
        value.Move(value.Index + longestSoFar.length);
        return this._zoneProvider!.get(longestSoFar);
      }
    }
    return null;
  }

  /** @inheritDoc */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<ZonedDateTime> {
    const localResult = LocalDateTimePatternParserLocalDateTimeParseBucket.CombineBuckets(usedFields, this.Date, this.Time, text);
    if (!localResult.Success) {
      return localResult.ConvertError<ZonedDateTime>();
    }

    const localDateTime = localResult.Value;

    // No offset - so just use the resolver
    if ((usedFields & PatternFields.EmbeddedOffset) === 0) {
      try {
        // Note: this method is only called when resolver is non-null, i.e. not a format-only pattern.
        return ParseResult.ForValue(this._zone.ResolveLocal(localDateTime, this._resolver!));
      } catch (e) {
        if (e instanceof SkippedTimeError) {
          return ParseResult.SkippedLocalTime<ZonedDateTime>(text);
        }
        if (e instanceof AmbiguousTimeError) {
          return ParseResult.AmbiguousLocalTime<ZonedDateTime>(text);
        }
        throw e;
      }
    }

    // We were given an offset, so we can resolve and validate using that
    const mapping = this._zone.MapLocal(localDateTime);
    let result: ZonedDateTime;
    switch (mapping.Count) {
      // If the local time was skipped, the offset has to be invalid.
      case 0:
        return ParseResult.InvalidOffset<ZonedDateTime>(text);
      case 1:
        result = mapping.First(); // We'll validate in a minute
        break;
      case 2:
        result = mapping.First().Offset.Equals(this.Offset) ? mapping.First() : mapping.Last();
        break;
      default:
        throw new InvalidOperationError("Mapping has count outside range 0-2; should not happen.");
    }
    if (!result.Offset.Equals(this.Offset)) {
      return ParseResult.InvalidOffset<ZonedDateTime>(text);
    }
    return ParseResult.ForValue(result);
  }
}

/** @internal */
export class ZonedDateTimePatternParser implements IPatternParser<ZonedDateTime> {
  private readonly _templateValue: ZonedDateTime;
  private readonly _zoneProvider: IDateTimeZoneProvider | null;
  private readonly _resolver: ZoneLocalMappingResolver | null;
  private readonly _twoDigitYearMax: number;

  private static get PatternCharacterHandlers(): Map<string, CharacterHandler<ZonedDateTime, ZonedDateTimePatternParserZonedDateTimeParseBucket>> {
    type B = ZonedDateTimePatternParserZonedDateTimeParseBucket;
    return (patternCharacterHandlers ??= new Map<string, CharacterHandler<ZonedDateTime, B>>([
      ["%", SteppedPatternBuilder.HandlePercent],
      ["'", SteppedPatternBuilder.HandleQuote],
      ["\"", SteppedPatternBuilder.HandleQuote],
      ["\\", SteppedPatternBuilder.HandleBackslash],
      ["/", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch)],
      ["T", (pattern, builder) => builder.AddLiteral("T", ParseResult.MismatchedCharacter)],
      ["y", DatePatternHelper.CreateYearOfEraHandler<ZonedDateTime, B>(value => value.YearOfEra, (bucket, value) => (bucket.Date.YearOfEra = value))],
      ["u", SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, B>(
        4, PatternFields.Year, -9999, 9999, value => value.Year, (bucket, value) => (bucket.Date.Year = value))],
      ["M", DatePatternHelper.CreateMonthOfYearHandler<ZonedDateTime, B>(
        value => value.Month, (bucket, value) => (bucket.Date.MonthOfYearText = value), (bucket, value) => (bucket.Date.MonthOfYearNumeric = value))],
      ["d", DatePatternHelper.CreateDayHandler<ZonedDateTime, B>(
        value => value.Day, value => value.DayOfWeek, (bucket, value) => (bucket.Date.DayOfMonth = value), (bucket, value) => (bucket.Date.DayOfWeek = value))],
      [".", TimePatternHelper.CreatePeriodHandler<ZonedDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      [";", TimePatternHelper.CreateCommaDotHandler<ZonedDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      [":", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch)],
      ["h", SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, B>(
        2, PatternFields.Hours12, 1, 12, value => value.ClockHourOfHalfDay, (bucket, value) => (bucket.Time.Hours12 = value))],
      ["H", SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, B>(
        2, PatternFields.Hours24, 0, 24, value => value.Hour, (bucket, value) => (bucket.Time.Hours24 = value))],
      ["m", SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, B>(
        2, PatternFields.Minutes, 0, 59, value => value.Minute, (bucket, value) => (bucket.Time.Minutes = value))],
      ["s", SteppedPatternBuilder.HandlePaddedField<ZonedDateTime, B>(
        2, PatternFields.Seconds, 0, 59, value => value.Second, (bucket, value) => (bucket.Time.Seconds = value))],
      ["f", TimePatternHelper.CreateFractionHandler<ZonedDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      ["F", TimePatternHelper.CreateFractionHandler<ZonedDateTime, B>(9, value => value.NanosecondOfSecond, (bucket, value) => (bucket.Time.FractionalSeconds = value))],
      ["t", TimePatternHelper.CreateAmPmHandler<ZonedDateTime, B>(time => time.Hour, (bucket, value) => (bucket.Time.AmPm = value))],
      ["c", DatePatternHelper.CreateCalendarHandler<ZonedDateTime, B>(value => value.LocalDateTime.Calendar, (bucket, value) => (bucket.Date.Calendar = value))],
      ["g", DatePatternHelper.CreateEraHandler<ZonedDateTime, B>(value => value.Era, bucket => bucket.Date)],
      ["z", ZonedDateTimePatternParser.HandleZone],
      ["x", ZonedDateTimePatternParser.HandleZoneAbbreviation],
      ["o", ZonedDateTimePatternParser.HandleOffset],
      ["l", (cursor, builder) => builder.AddEmbeddedLocalPartial(cursor, bucket => bucket.Date, bucket => bucket.Time, value => value.Date, value => value.TimeOfDay, value => value.LocalDateTime)],
    ]));
  }

  constructor(templateValue: ZonedDateTime, resolver: ZoneLocalMappingResolver | null, zoneProvider: IDateTimeZoneProvider | null, twoDigitYearMax: number) {
    Preconditions.CheckArgumentRange("twoDigitYearMax", twoDigitYearMax, 0, 99);
    this._templateValue = templateValue;
    this._resolver = resolver;
    this._zoneProvider = zoneProvider;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  static NewTemplateValueResolverZoneProviderTwoDigitYearMax(templateValue: ZonedDateTime, resolver: ZoneLocalMappingResolver | null,
    zoneProvider: IDateTimeZoneProvider | null, twoDigitYearMax: number): ZonedDateTimePatternParser {
    return new ZonedDateTimePatternParser(templateValue, resolver, zoneProvider, twoDigitYearMax);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<ZonedDateTime> {
    // Nullity check is performed in ZonedDateTimePattern.
    if (patternText.length === 0) {
      throw new InvalidPatternError(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length === 1) {
      switch (patternText[0]) {
        case "G":
          return ZonedDateTimePattern.Patterns.GeneralFormatOnlyPatternImpl
            .WithZoneProvider(this._zoneProvider)
            .WithResolver(this._resolver);
        case "F":
          return ZonedDateTimePattern.Patterns.ExtendedFormatOnlyPatternImpl
            .WithZoneProvider(this._zoneProvider)
            .WithResolver(this._resolver);
        default:
          throw new InvalidPatternError(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.ZonedDateTime");
      }
    }

    const { _templateValue, _resolver, _zoneProvider, _twoDigitYearMax } = this;
    const patternBuilder = new SteppedPatternBuilder<ZonedDateTime, ZonedDateTimePatternParserZonedDateTimeParseBucket>(formatInfo,
      () => new ZonedDateTimePatternParserZonedDateTimeParseBucket(_templateValue, _resolver, _zoneProvider, _twoDigitYearMax));
    if (_zoneProvider === null || _resolver === null) {
      patternBuilder.SetFormatOnly();
    }
    patternBuilder.ParseCustomPattern(patternText, ZonedDateTimePatternParser.PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    return patternBuilder.Build(_templateValue);
  }

  private static HandleZone(pattern: PatternCursor,
    builder: SteppedPatternBuilder<ZonedDateTime, ZonedDateTimePatternParserZonedDateTimeParseBucket>): void {
    builder.AddField(PatternFields.Zone, pattern.Current);
    builder.AddParseAction(ZonedDateTimePatternParser.ParseZone);
    builder.AddFormatAction((value, sb) => sb.Append(value.Zone.Id));
  }

  private static HandleZoneAbbreviation(pattern: PatternCursor,
    builder: SteppedPatternBuilder<ZonedDateTime, ZonedDateTimePatternParserZonedDateTimeParseBucket>): void {
    builder.AddField(PatternFields.ZoneAbbreviation, pattern.Current);
    builder.SetFormatOnly();
    builder.AddFormatAction((value, sb) => sb.Append(value.GetZoneInterval().Name));
  }

  private static HandleOffset(pattern: PatternCursor,
    builder: SteppedPatternBuilder<ZonedDateTime, ZonedDateTimePatternParserZonedDateTimeParseBucket>): void {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    const embeddedPattern = pattern.GetEmbeddedPattern();
    const offsetPattern = OffsetPattern.Create(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern(offsetPattern, (bucket, offset) => (bucket.Offset = offset), zdt => zdt.Offset);
  }

  private static ParseZone(value: ValueCursor, bucket: ZonedDateTimePatternParserZonedDateTimeParseBucket): ParseResult<ZonedDateTime> | null {
    return bucket.ParseZone(value);
  }
}
