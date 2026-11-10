// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/TzdbZoneInfoParser.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../LocalTime.dart';
import '../../Offset.dart';
import '../../TimeZones/TransitionMode.generated.dart';
import '../../TimeZones/ZoneRecurrence.dart';
import '../../TimeZones/ZoneYearOffset.dart';
import '../../Utility/Int64.dart';
import '../../Utility/Preconditions.dart';
import '../../Utility/SystemExceptions.dart';
import '../Shims.dart';
import 'IoExtensions.dart';
import 'ParserHelper.dart';
import 'RuleLine.dart';
import 'Tokens.dart';
import 'TzdbDatabase.dart';
import 'ZoneLine.dart';

/// Provides a parser for TZDB time zone description files.
@internal
class TzdbZoneInfoParser {
  /// An offset that specifies the beginning of the year.
  static final ZoneYearOffset StartOfYearZoneOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
      TransitionMode.Wall, 1, 1, 0, false, LocalTime.Midnight);

  /// The keyword that specifies the line defines an alias link.
  static const String _KeywordLink = 'Link';

  /// The keyword that specifies the line defines a daylight savings rule.
  static const String _KeywordRule = 'Rule';

  /// The keyword that specifies the line defines a time zone.
  static const String _KeywordZone = 'Zone';

  /// The days of the week names as they appear in the TZDB zone files. They are
  /// always the short name in US English.
  static const List<String> _DaysOfWeek = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// The months of the year names as they appear in the TZDB zone files. Entries are usually
  /// abbreviated to (an unambiguous prefix of) the first three letters, e.g. "Jan", but older
  /// files sometimes spell them out in full, e.g. "January" in Greece's 96d rule. As the short
  /// form is always a prefix of the long form, matching against the long form alone covers both.
  static const List<String> _LongMonths = [
    '', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', //
    'December',
  ];

  /// Parses the next token as a month number (1-12).
  ///
  /// [tokens]: The tokens.
  /// [name]: The name of the expected value, for use in the exception if no value is available.
  int _NextMonth(Tokens tokens, String name) {
    final value = _NextString(tokens, name);
    return ParseMonth(value);
  }

  /// Parses the next token as an offset.
  ///
  /// [tokens]: The tokens.
  /// [name]: The name of the expected value, for use in the exception if no value is available.
  Offset _NextOffset(Tokens tokens, String name) => ParserHelper.ParseOffset(_NextString(tokens, name));

  /// Returns the next token, which is optional, converting "-" to null.
  ///
  /// [tokens]: The tokens.
  /// [name]: The name of the expected value, for use in the exception if no value is available.
  String? _NextOptional(Tokens tokens, String name) => ParserHelper.ParseOptional(_NextString(tokens, name));

  /// Returns the next string from the token stream.
  ///
  /// [tokens]: The tokens to parse from.
  /// [name]: The name of the expected value, for use in the exception if no value is available.
  String _NextString(Tokens tokens, String name) {
    if (!tokens.HasNextToken) {
      throw InvalidDataException('Missing zone info token: $name');
    }
    return tokens.NextToken(name);
  }

  /// Parses the next string from the token stream as a year.
  ///
  /// [tokens]: The tokens.
  /// [defaultValue]: The default value to return if the year isn't specified.
  static int _NextYear(Tokens tokens, int defaultValue) {
    var result = defaultValue;
    final (success, text) = tokens.TryNextToken();
    if (success) {
      result = ParserHelper.ParseYear(text, defaultValue);
    }
    return result;
  }

  /// Parses the TZDB time zone info file from the given stream and merges its information
  /// with the given database. The stream is not closed or disposed.
  ///
  /// noda_dart: the stream is its bytes, decoded as `new StreamReader(input, true)` does.
  ///
  /// [input]: The stream input to parse.
  /// [database]: The database to fill.
  void Parse(Uint8List input, TzdbDatabase database) {
    ParseTextReader(DecodeStream(input), database);
  }

  /// Parses the TZDB time zone info file from the given reader and merges its information
  /// with the given database. The reader is not closed or disposed.
  ///
  /// (NodaTime's `Parse(TextReader, TzdbDatabase)`: the TextReader is the text it reads.)
  ///
  /// [reader]: The reader to read.
  /// [database]: The database to fill.
  void ParseTextReader(String reader, TzdbDatabase database) {
    String? currentZone;
    for (final line in reader.ReadLines()) {
      currentZone = _ParseLine(line, currentZone, database);
    }
  }

  /// Parses the ZoneYearOffset for a rule or zone. This is something like "3rd Sunday of October at 2am".
  ///
  /// IN ON AT
  ///
  /// [tokens]: The tokens to parse.
  /// [forRule]: True if this is for a Rule line, in which case ON/AT are mandatory;
  /// false for a Zone line, in which case it's part of "until" and they're optional
  ///
  /// Returns the ZoneYearOffset object.
  ZoneYearOffset ParseDateTimeOfYear(Tokens tokens, bool forRule) {
    var mode = StartOfYearZoneOffset.Mode;
    var timeOfDay = StartOfYearZoneOffset.TimeOfDay;

    final monthOfYear = _NextMonth(tokens, 'MonthOfYear');

    var dayOfMonth = 1;
    var dayOfWeek = 0;
    var advanceDayOfWeek = false;
    var addDay = false;

    if (tokens.HasNextToken || forRule) {
      final on = _NextString(tokens, 'On');
      if (on.startsWith('last')) {
        dayOfMonth = -1;
        dayOfWeek = ParseDayOfWeek(on.substring(4));
      } else {
        var index = on.indexOf('>=');
        if (index > 0) {
          dayOfMonth = ParseInt32(on.substring(index + 2));
          dayOfWeek = ParseDayOfWeek(on.substring(0, index));
          advanceDayOfWeek = true;
        } else {
          index = on.indexOf('<=');
          if (index > 0) {
            dayOfMonth = ParseInt32(on.substring(index + 2));
            dayOfWeek = ParseDayOfWeek(on.substring(0, index));
          } else {
            try {
              dayOfMonth = ParseInt32(on);
              dayOfWeek = 0;
            } on FormatException catch (e) {
              throw ArgumentError('Unparsable ON token: $on ($e)');
            }
          }
        }
      }

      if (tokens.HasNextToken || forRule) {
        var atTime = _NextString(tokens, 'AT');
        if (atTime.isNotEmpty) {
          if (IsLetter(atTime[atTime.length - 1])) {
            final zoneCharacter = atTime[atTime.length - 1];
            mode = _ConvertModeCharacter(zoneCharacter);
            atTime = atTime.substring(0, atTime.length - 1);
          }
          if (atTime == '24:00') {
            timeOfDay = LocalTime.Midnight;
            addDay = true;
          }
          // As of TZDB 2018f, Japan's fallback transitions occur at 25:00. We can't
          // represent this entirely accurately, but this is as close as we can approximate it.
          else if (atTime == '25:00') {
            timeOfDay = LocalTime(1, 0);
            addDay = true;
          } else {
            timeOfDay = ParserHelper.ParseTime(atTime);
          }
        }
      }
    }
    return ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
        mode, monthOfYear, dayOfMonth, dayOfWeek, advanceDayOfWeek, timeOfDay, addDay);
  }

  /// Parses the day of week, which may be any case-insensitive, unambiguous prefix of a day
  /// name (matching the behavior of zic itself).
  ///
  /// [text]: The text.
  static int ParseDayOfWeek(String text) => _ParseUnambiguousNamePrefix(text, 'day of week', _DaysOfWeek);

  /// Parses a single line of an TZDB zone info file.
  ///
  /// TZDB files have a simple line based structure. Each line defines one item. Comments
  /// start with a hash or pound sign (#) and continue to the end of the line. Blank lines are
  /// ignored. Of the remaining there are four line types which are determined by the first
  /// keyword on the line.
  ///
  /// A line beginning with the keyword `Link` defines an alias between one time zone and
  /// another. Both time zones use the same definition but have different names.
  ///
  /// A line beginning with the keyword `Rule` defines a daylight savings time
  /// calculation rule.
  ///
  /// A line beginning with the keyword `Zone` defines a time zone.
  ///
  /// A line beginning with leading whitespace (an empty keyword) defines another part of the
  /// preceding time zone. As many lines as necessary to define the time zone can be listed,
  /// but they must all be together and only the first line can have a name.
  ///
  /// [line]: The line to parse.
  /// [previousZone]: The previous zone ID, or null if we don't have one.
  /// [database]: The database to fill.
  ///
  /// Returns the zone name just parsed, if any - so that it can be passed into the next call.
  String? _ParseLine(String line, String? previousZone, TzdbDatabase database) {
    // Trim end-of-line comments
    final index = line.indexOf('#');
    if (index >= 0) {
      line = line.substring(0, index);
    }
    line = TrimEnd(line);
    if (line.isEmpty) {
      // We can still continue with the previous zone
      return previousZone;
    }

    // Okay, everything left in the line should be "real" now.
    final tokens = Tokens.Tokenize(line);
    final keyword = _NextString(tokens, 'Keyword');
    switch (keyword) {
      case _KeywordRule:
        database.AddRule(ParseRule(tokens));
        return null;
      case _KeywordLink:
        final alias = ParseLink(tokens);
        database.AddAlias(alias.$1, alias.$2);
        return null;
      case _KeywordZone:
        final name = _NextString(tokens, 'GetName');
        database.AddZone(ParseZone(name, tokens));
        return name;
      default:
        if (keyword.isEmpty) {
          if (previousZone == null) {
            throw InvalidDataException('Zone continuation provided with no previous zone line');
          }
          database.AddZone(ParseZone(previousZone, tokens));
          return previousZone;
        } else {
          throw InvalidDataException('Unexpected zone database keyword: $keyword');
        }
    }
  }

  /// Parses an alias link and returns the ZoneAlias object.
  ///
  /// [tokens]: The tokens to parse.
  ///
  /// Returns the ZoneAlias object: the existing zone ID and the alias (C#'s `Tuple<string, string>`).
  (String, String) ParseLink(Tokens tokens) {
    final existing = _NextString(tokens, 'Existing');
    final alias = _NextString(tokens, 'Alias');
    return (existing, alias);
  }

  /// Parses the month, which may be any case-insensitive, unambiguous prefix of a month name
  /// (matching the behavior of zic itself).
  ///
  /// [text]: The text.
  ///
  /// Returns the month number in the range 1 to 12.
  ///
  /// Throws [InvalidDataException] if the month name can't be parsed, or is ambiguous.
  static int ParseMonth(String text) => _ParseUnambiguousNamePrefix(text, 'month', _LongMonths);

  /// Finds the index of the single entry in [names] (which has an unused entry
  /// at index 0) for which [text] is a case-insensitive prefix. Throws
  /// [InvalidDataException] if no entry matches, or if more than one does.
  static int _ParseUnambiguousNamePrefix(String text, String what, List<String> names) {
    Preconditions.CheckArgument(text.isNotEmpty, 'text', 'Value must not be empty or null');
    var match = 0;
    for (var i = 1; i < names.length; i++) {
      if (StartsWithOrdinalIgnoreCase(names[i], text)) {
        if (match != 0) {
          throw InvalidDataException('Ambiguous $what: $text');
        }
        match = i;
      }
    }
    if (match == 0) {
      throw InvalidDataException('Invalid $what: $text');
    }
    return match;
  }

  /// Parses a daylight savings rule and returns the Rule object.
  ///
  /// # Rule    NAME    FROM    TO    TYPE    IN    ON    AT    SAVE    LETTER/S
  ///
  /// [tokens]: The tokens to parse.
  ///
  /// Returns the Rule object.
  RuleLine ParseRule(Tokens tokens) {
    final name = _NextString(tokens, 'GetName');
    var fromYear = _NextYear(tokens, 0);

    // This basically doesn't happen these days, but if we have any recurrent rules
    // which start at the dawn of time, make them effective from 1900. This matches
    // zic behaviour in the only cases of this that we've seen, e.g. the systemv rules
    // prior to 2001a.
    if (fromYear == Int64.Int32MinValue) {
      fromYear = 1900;
    }

    final toYear = _NextYear(tokens, fromYear);
    if (toYear < fromYear) {
      throw ArgumentError('To year cannot be before the from year in a Rule: $toYear < $fromYear');
    }

    // We don't support types any more, but rather than just ignoring the value, we check that it's not specified.
    final type = _NextOptional(tokens, 'Type');
    if (type != null) {
      throw UnimplementedError("Zone rules with types are no longer supported. Recurrence '$name' has type '$type'");
    }

    final yearOffset = ParseDateTimeOfYear(tokens, true);
    final savings = _NextOffset(tokens, 'SaveMillis');
    final daylightSavingsIndicator = _NextOptional(tokens, 'LetterS');
    // The name of the zone recurrence is currently the name of the rule. Later (in ZoneRule.GetRecurrences)
    // it will be replaced with the formatted name. It's not ideal, but it avoids a lot of duplication.
    final recurrence = ZoneRecurrence(name, savings, yearOffset, fromYear, toYear);
    return RuleLine(recurrence, daylightSavingsIndicator);
  }

  /// Parses a time zone definition and returns the Zone object.
  ///
  /// # GMTOFF RULES FORMAT [ UntilYear [ UntilMonth [ UntilDay [ UntilTime [ ZoneCharacter ] ] ] ] ]
  ///
  /// [name]: The name of the zone being parsed.
  /// [tokens]: The tokens to parse.
  ///
  /// Returns the Zone object.
  ZoneLine ParseZone(String name, Tokens tokens) {
    final offset = _NextOffset(tokens, 'Gmt Offset');
    final rules = _NextOptional(tokens, 'Rules');
    final format = _NextString(tokens, 'Format');
    final year = _NextYear(tokens, Int64.Int32MaxValue);

    if (tokens.HasNextToken) {
      final until = ParseDateTimeOfYear(tokens, false);
      return ZoneLine(name, offset, rules, format, year, until);
    }

    return ZoneLine(name, offset, rules, format, year, StartOfYearZoneOffset);
  }

  /// Normalizes the transition mode character.
  ///
  /// [modeCharacter]: The character to normalize.
  ///
  /// Returns the [TransitionMode].
  static TransitionMode _ConvertModeCharacter(String modeCharacter) {
    switch (modeCharacter) {
      case 's':
      case 'S':
        return TransitionMode.Standard;
      case 'u':
      case 'U':
      case 'g':
      case 'G':
      case 'z':
      case 'Z':
        return TransitionMode.Utc;
      default:
        return TransitionMode.Wall;
    }
  }
}
