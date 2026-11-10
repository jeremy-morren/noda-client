// Ported from NodaTime 6e024dde: src/NodaTime/Text/OffsetTimePatternParser.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../LocalTime.dart';
import '../Offset.dart';
import '../Offset.dart' as nt show Offset;
import '../OffsetTime.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalTimePatternParser.dart';
import 'OffsetPattern.dart';
import 'OffsetTimePattern.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'Patterns/TimePatternHelper.dart';
import 'TextErrorMessages.generated.dart';

@internal
final class OffsetTimePatternParser implements IPatternParser<OffsetTime> {
  final OffsetTime _templateValue;

  static final Map<String, CharacterHandler<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '.': TimePatternHelper.CreatePeriodHandler<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ';': TimePatternHelper.CreateCommaDotHandler<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ':': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<OffsetTime>),
    'h': SteppedPatternBuilder.HandlePaddedField<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>
        (2, PatternFields.Hours12, 1, 12, (value) => value.ClockHourOfHalfDay, (bucket, value) => bucket.Time.Hours12 = value),
    'H': SteppedPatternBuilder.HandlePaddedField<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>
        (2, PatternFields.Hours24, 0, 23, (value) => value.Hour, (bucket, value) => bucket.Time.Hours24 = value),
    'm': SteppedPatternBuilder.HandlePaddedField<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>
        (2, PatternFields.Minutes, 0, 59, (value) => value.Minute, (bucket, value) => bucket.Time.Minutes = value),
    's': SteppedPatternBuilder.HandlePaddedField<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>
        (2, PatternFields.Seconds, 0, 59, (value) => value.Second, (bucket, value) => bucket.Time.Seconds = value),
    'f': TimePatternHelper.CreateFractionHandler<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    'F': TimePatternHelper.CreateFractionHandler<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    't': TimePatternHelper.CreateAmPmHandler<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>((time) => time.Hour, (bucket, value) => bucket.Time.AmPm = value),
    'o': _HandleOffset,
    'l': (cursor, builder) => builder.AddEmbeddedTimePattern(cursor.Current, cursor.GetEmbeddedPattern(), (bucket) => bucket.Time, (value) => value.TimeOfDay),
  };

  OffsetTimePatternParser.NewTemplateValue(OffsetTime templateValue) : _templateValue = templateValue;

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<OffsetTime> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Nullity check is performed in OffsetTimePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length == 1) {
      return switch (patternText[0]) {
        'G' => OffsetTimePatternPatterns.GeneralIsoPatternImpl,
        'o' => OffsetTimePatternPatterns.ExtendedIsoPatternImpl,
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText[0], ParseResult.TypeName(OffsetTime)])
      };
    }

    var patternBuilder = SteppedPatternBuilder<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket>.NewFormatInfoBucketProvider(formatInfo,
        () => _OffsetTimePatternParserOffsetTimeParseBucket.NewTemplateValue(_templateValue));
    patternBuilder.ParseCustomPattern(patternText, _PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    // Need to reconstruct the template value from the bits...
    return patternBuilder.Build(_templateValue);
  }

  static void _HandleOffset(PatternCursor pattern,
      SteppedPatternBuilder<OffsetTime, _OffsetTimePatternParserOffsetTimeParseBucket> builder) {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    String embeddedPattern = pattern.GetEmbeddedPattern();
    var offsetPattern = OffsetPattern.CreateNodaFormatInfo(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern<Offset>(offsetPattern, (bucket, offset) => bucket.Offset = offset, (zdt) => zdt.Offset);
  }
}

final class _OffsetTimePatternParserOffsetTimeParseBucket extends ParseBucket<OffsetTime> {
  final LocalTimePatternParserLocalTimeParseBucket Time;
  nt.Offset Offset;

  _OffsetTimePatternParserOffsetTimeParseBucket.NewTemplateValue(OffsetTime templateValue)
      : Time = LocalTimePatternParserLocalTimeParseBucket.NewTemplateValue(templateValue.TimeOfDay),
        Offset = templateValue.Offset;

  @override
  ParseResult<OffsetTime> CalculateValue(PatternFields usedFields, String text) {
    ParseResult<LocalTime> timeResult = Time.CalculateValue(usedFields & PatternFields.AllTimeFields, text, OffsetTime);
    if (!timeResult.Success) {
      return timeResult.ConvertError<OffsetTime>();
    }
    LocalTime date = timeResult.Value;
    return ParseResult.ForValue<OffsetTime>(date.WithOffset(Offset));
  }
}
