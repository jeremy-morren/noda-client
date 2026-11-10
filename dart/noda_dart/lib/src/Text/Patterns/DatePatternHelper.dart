// Ported from NodaTime 6e024dde: src/NodaTime/Text/Patterns/DatePatternHelper.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../CalendarSystem.dart';
import '../../Calendars/Era.dart';
import '../../Globalization/NodaFormatInfo.dart';
import '../Delegates.dart';
import '../InvalidPatternException.dart';
import '../LocalDatePatternParser.dart';
import '../ParseBucket.dart';
import '../ParseResult.dart';
import '../TextErrorMessages.generated.dart';
import 'PatternFields.dart';
import 'SteppedPatternBuilder.dart';

/// Common methods used when parsing dates - these are used from both LocalDateTimePatternParser
/// and LocalDatePatternParser.
@internal
abstract final class DatePatternHelper {
  /// Creates a character handler for the year-of-era specifier (y).
  static CharacterHandler<TResult, TBucket> CreateYearOfEraHandler<TResult, TBucket extends ParseBucket<TResult>>(
      int Function(TResult) yearGetter, void Function(TBucket, int) setter) {
    return (pattern, builder) {
      int count = pattern.GetRepeatCount(4);
      builder.AddField(PatternFields.YearOfEra, pattern.Current);
      switch (count) {
        case 2:
          builder.AddParseValueAction(2, 2, 'y', 0, 99, setter);
          // Force the year into the range 0-99.
          builder.AddFormatLeftPad(2, (value) => ((yearGetter(value).remainder(100)) + 100).remainder(100),
              /* assumeNonNegative: */ true,
              /* assumeFitsInCount: */ true);
          // Just remember that we've set this particular field. We can't set it twice as we've already got the YearOfEra flag set.
          builder.AddField(PatternFields.YearTwoDigits, pattern.Current);
          break;
        case 4:
          // Left-pad to 4 digits when formatting; parse exactly 4 digits.
          builder.AddParseValueAction(4, 4, 'y', 1, 9999, setter);
          builder.AddFormatLeftPad(4, yearGetter,
              /* assumeNonNegative: */ false,
              /* assumeFitsInCount: */ true);
          break;
        default:
          throw InvalidPatternException.NewFormatStringParameters(
              TextErrorMessages.InvalidRepeatCount, [pattern.Current, count]);
      }
    };
  }

  /// Creates a character handler for the month-of-year specifier (M).
  static CharacterHandler<TResult, TBucket> CreateMonthOfYearHandler<TResult, TBucket extends ParseBucket<TResult>>(
      int Function(TResult) numberGetter, void Function(TBucket, int) textSetter, void Function(TBucket, int) numberSetter) {
    return (pattern, builder) {
      int count = pattern.GetRepeatCount(4);
      PatternFields field;
      switch (count) {
        case 1:
        case 2:
          field = PatternFields.MonthOfYearNumeric;
          // Handle real maximum value in the bucket
          builder.AddParseValueAction(count, 2, pattern.Current, 1, 99, numberSetter);
          builder.AddFormatLeftPad(count, numberGetter, /* assumeNonNegative: */ true, /* assumeFitsInCount: */ count == 2);
          break;
        case 3:
        case 4:
          field = PatternFields.MonthOfYearText;
          var format = builder.FormatInfo;
          List<String> nonGenitiveTextValues = count == 3 ? format.ShortMonthNames : format.LongMonthNames;
          List<String> genitiveTextValues = count == 3 ? format.ShortMonthGenitiveNames : format.LongMonthGenitiveNames;
          if (identical(nonGenitiveTextValues, genitiveTextValues)) {
            builder.AddParseLongestTextAction(pattern.Current, textSetter, format.CompareInfo, nonGenitiveTextValues);
          } else {
            builder.AddParseLongestTextAction(
                pattern.Current, textSetter, format.CompareInfo, genitiveTextValues, nonGenitiveTextValues);
          }

          // Hack: see below
          // (noda_dart: the holder is passed as the action's target; see SteppedPatternBuilder.AddFormatAction.)
          var holder = _MonthFormatActionHolder<TResult, TBucket>(format, count, numberGetter);
          builder.AddFormatAction(holder._DummyMethod, holder);
          break;
        default:
          throw StateError('Invalid count!');
      }
      builder.AddField(field, pattern.Current);
    };
  }

  /// Creates a character handler for the day specifier (d).
  static CharacterHandler<TResult, TBucket> CreateDayHandler<TResult, TBucket extends ParseBucket<TResult>>(
      int Function(TResult) dayOfMonthGetter,
      int Function(TResult) dayOfWeekGetter,
      void Function(TBucket, int) dayOfMonthSetter,
      void Function(TBucket, int) dayOfWeekSetter) {
    return (pattern, builder) {
      int count = pattern.GetRepeatCount(4);
      PatternFields field;
      switch (count) {
        case 1:
        case 2:
          field = PatternFields.DayOfMonth;
          // Handle real maximum value in the bucket
          builder.AddParseValueAction(count, 2, pattern.Current, 1, 99, dayOfMonthSetter);
          builder.AddFormatLeftPad(
              count, dayOfMonthGetter, /* assumeNonNegative: */ true, /* assumeFitsInCount: */ count == 2);
          break;
        case 3:
        case 4:
          field = PatternFields.DayOfWeek;
          var format = builder.FormatInfo;
          List<String> textValues = count == 3 ? format.ShortDayNames : format.LongDayNames;
          builder.AddParseLongestTextAction(pattern.Current, dayOfWeekSetter, format.CompareInfo, textValues);
          builder.AddFormatAction((value, sb) => sb.write(textValues[dayOfWeekGetter(value)]));
          break;
        default:
          throw StateError('Invalid count!');
      }
      builder.AddField(field, pattern.Current);
    };
  }

  /// Creates a character handler for the era specifier (g).
  static CharacterHandler<TResult, TBucket> CreateEraHandler<TResult, TBucket extends ParseBucket<TResult>>(
      Era Function(TResult) eraFromValue, LocalDatePatternParserLocalDateParseBucket Function(TBucket) dateBucketFromBucket) {
    return (pattern, builder) {
      pattern.GetRepeatCount(2);
      builder.AddField(PatternFields.Era, pattern.Current);
      var formatInfo = builder.FormatInfo;
      // Note: currently the count is ignored. More work needed to determine whether abbreviated era names should be used for just "g".
      builder.AddParseAction((cursor, bucket) {
        var dateBucket = dateBucketFromBucket(bucket);
        return dateBucket.ParseEra<TResult>(formatInfo, cursor);
      });
      builder.AddFormatAction((value, sb) => sb.write(formatInfo.GetEraPrimaryName(eraFromValue(value))));
    };
  }

  /// Creates a character handler for the calendar specifier (c).
  static CharacterHandler<TResult, TBucket> CreateCalendarHandler<TResult, TBucket extends ParseBucket<TResult>>(
      CalendarSystem Function(TResult) getter, void Function(TBucket, CalendarSystem) setter) {
    return (pattern, builder) {
      builder.AddField(PatternFields.Calendar, pattern.Current);

      builder.AddParseAction((cursor, bucket) {
        for (var id in CalendarSystem.Ids) {
          if (cursor.Match(id)) {
            setter(bucket, CalendarSystem.ForId(id));
            return null;
          }
        }
        return ParseResult.NoMatchingCalendarSystem<TResult>(cursor);
      });
      builder.AddFormatAction((value, sb) => sb.write(getter(value).Id));
    };
  }
}

// Hacky way of building an action which depends on the final set of pattern fields to determine whether to format a month
// using the genitive form or not.
final class _MonthFormatActionHolder<TResult, TBucket extends ParseBucket<TResult>>
    implements SteppedPatternBuilderIPostPatternParseFormatAction<TResult> {
  final int _count;
  final NodaFormatInfo _formatInfo;
  final int Function(TResult) _getter;

  _MonthFormatActionHolder(NodaFormatInfo formatInfo, int count, int Function(TResult) getter)
      : _count = count,
        _formatInfo = formatInfo,
        _getter = getter;

  void _DummyMethod(TResult value, StringBuffer builder) {
    // This method is never called. We use it to create a delegate with a target that implements
    // IPostPatternParseFormatAction. There's no test for this throwing.
    // This method must be an instance method, so that we can get the target of the method in SteppedPatternBuilder.Build.
    throw StateError('This method should never be called');
  }

  @override
  SteppedPatternBuilderFormatAction<TResult> BuildFormatAction(PatternFields finalFields) {
    bool genitive = (finalFields & PatternFields.DayOfMonth) != PatternFields.None;
    List<String> textValues = _count == 3
        ? (genitive ? _formatInfo.ShortMonthGenitiveNames : _formatInfo.ShortMonthNames)
        : (genitive ? _formatInfo.LongMonthGenitiveNames : _formatInfo.LongMonthNames);
    return (value, sb) => sb.write(textValues[_getter(value)]);
  }
}
