// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/ParserHelper.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../LocalTime.dart';
import '../../NodaConstants.dart';
import '../../Offset.dart';
import '../../Text/LocalTimePattern.dart';
import '../../Utility/Int64.dart';
import '../Shims.dart';

/// Contains helper methods for parsing the TZDB files.
@internal
abstract final class ParserHelper {
  static final List<LocalTimePattern> _TimePatterns = [
    LocalTimePattern.CreateWithInvariantCulture('H:mm:ss.FFF'),
    LocalTimePattern.CreateWithInvariantCulture('H:mm'),
    LocalTimePattern.CreateWithInvariantCulture('%H'),
    // Handle "somewhat broken" data such as a DAVT rule in Antarctica 2009r, with a date/time of "2009 Oct 18 2:0"
    LocalTimePattern.CreateWithInvariantCulture('H:m'),
  ];

  /// Converts an hour string to its long value.
  ///
  /// [text]: The text to convert.
  ///
  /// Returns the hour in the range [-23, 23].
  ///
  /// Throws [FormatException] if the text is not a valid integer in the range [-23, 23].
  static int ConvertHourToTicks(String text) {
    // Dart: null safety checks text.
    final value = ParseInt32(text);
    if (value < -23 || value > 23) {
      throw FormatException('hours out of valid range of [-23, 23]: $value');
    }
    return value * NodaConstants.TicksPerHour;
  }

  /// Converts a minute string to its long value.
  ///
  /// [text]: The text to convert.
  ///
  /// Returns the minute in the range [0, 59].
  ///
  /// Throws [FormatException] if the text is not a valid integer in the range [0, 59].
  static int ConvertMinuteToTicks(String text) {
    // Dart: null safety checks text.
    final value = ParseInt32(text, false);
    if (value < 0 || value > 59) {
      throw FormatException('minutes out of valid range of [0, 59]: $value');
    }
    return value * NodaConstants.TicksPerMinute;
  }

  /// Converts a second string to its double value.
  ///
  /// [text]: The text to convert.
  ///
  /// Returns the second in the range [0, 60).
  ///
  /// Throws [FormatException] if the text is not a valid integer in the range [0, 60).
  static int ConvertSecondsWithFractionalToTicks(String text) {
    // Dart: null safety checks text.
    final number = ParseDecimalDouble(text);
    if (number < 0.0 || number >= 60.0) {
      throw FormatException('seconds out of valid range of [0, 60): $number');
    }
    final value = (number * NodaConstants.MillisecondsPerSecond).truncate() * NodaConstants.TicksPerMillisecond;
    return value;
  }

  /// Formats an optional, converting null input to "-".
  ///
  /// [value]: The value.
  static String FormatOptional(String? value) => value ?? '-';

  /// Parses the given text for an integer. Leading and trailing white space is ignored.
  ///
  /// [text]: The text to parse.
  /// [defaultValue]: The default value to use if the number cannot be parsed.
  ///
  /// Returns an integer.
  ///
  /// Throws [FormatException] if the text is not a valid integer.
  static int ParseInteger(String? text, int defaultValue) {
    var value = defaultValue;
    if (text != null) {
      final parsed = TryParseInt32(text);
      if (parsed == null) {
        value = defaultValue;
      } else {
        value = parsed;
      }
    }
    return value;
  }

  /// Parses a time offset string into an integer number of ticks.
  ///
  /// [text]: The value to parse.
  ///
  /// Returns an integer number of ticks
  static Offset ParseOffset(String text) {
    // Some old files use "-" for 0 in a few places.
    // Example: Tonga, 1999f.
    if (text == '-') {
      return Offset.Zero;
    }
    // TODO(2.0): Use normal parsers!
    // Dart: null safety checks text.
    var sign = 1;
    if (text.startsWith('-')) {
      sign = -1;
      text = text.substring(1);
    }
    final parts = text.split(':');
    if (parts.length > 3) {
      throw FormatException('Offset has too many colon separated parts (max of 3 allowed): $text');
    }
    var ticks = ConvertHourToTicks(parts[0]);
    if (parts.length > 1) {
      ticks += ConvertMinuteToTicks(parts[1]);
      if (parts.length > 2) {
        ticks += ConvertSecondsWithFractionalToTicks(parts[2]);
      }
    }
    ticks = ticks * sign;
    return Offset.FromTicks(ticks);
  }

  static LocalTime ParseTime(String text) {
    for (final pattern in _TimePatterns) {
      final result = pattern.Parse(text);
      if (result.Success) {
        return result.Value;
      }
    }
    throw FormatException('Invalid time in rules: $text');
  }

  /// Parses an optional value. If the string value is "-" then null is returned otherwise the
  /// input string is returned.
  ///
  /// [text]: The value to parse.
  ///
  /// Returns the input string or null.
  static String? ParseOptional(String text) {
    // Dart: null safety checks text.
    return text == '-' ? null : text;
  }

  /// Parses the year.
  ///
  /// [text]: The text to parse.
  /// [defaultValue]: The default value.
  ///
  /// Returns the parsed year.
  static int ParseYear(String text, int defaultValue) {
    text = text.toLowerCase();
    switch (text) {
      case 'min':
      case 'minimum':
        return Int64.Int32MinValue;
      case 'max':
      case 'maximum':
        return Int64.Int32MaxValue;
      case 'only':
        return defaultValue;
      default:
        return ParseInt32(text);
    }
  }
}
