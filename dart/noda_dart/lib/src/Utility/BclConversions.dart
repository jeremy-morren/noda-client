// Ported from NodaTime 6e024dde: src/NodaTime/Utility/BclConversions.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../IsoDayOfWeek.generated.dart';

const int _DayOfWeekSunday = 0;
const int _DayOfWeekSaturday = 6;

/// Conversion methods which don't naturally fit into any other types - for example, for
/// enums which can't specify any other code. In most cases, conversions to and from BCL types
/// are provided within the type itself - such as [LocalDateTime.ToDateTimeUnspecified]
/// and [LocalDateTime.FromDateTime].
///
/// These methods are also available in the form of extension methods in the `NodaTime.Extensions` namespace.
///
/// noda_dart: .NET's `DayOfWeek` is its int value, 0 (Sunday) to 6 (Saturday).
abstract final class BclConversions {
  /// Converts from the Noda Time [IsoDayOfWeek] enum to the equivalent BCL
  /// `DayOfWeek` value. Other than Sunday, the BCL and ISO values are the same -
  /// but ISO 8601 defines Sunday as day 7, and the BCL defines it as day 0.
  ///
  /// [isoDayOfWeek]: ISO day of week value to convert.
  ///
  /// Returns the ISO day of week value equivalent to the one passed in.
  ///
  /// Throws [RangeError] if the [isoDayOfWeek] parameter is not a valid day of the week.
  static int ToDayOfWeek(IsoDayOfWeek isoDayOfWeek) {
    if (isoDayOfWeek.value < IsoDayOfWeek.Monday.value || isoDayOfWeek.value > IsoDayOfWeek.Sunday.value) {
      throw RangeError.value(isoDayOfWeek.value, 'isoDayOfWeek');
    }
    return isoDayOfWeek == IsoDayOfWeek.Sunday ? _DayOfWeekSunday : isoDayOfWeek.value;
  }

  /// Converts from the BCL `DayOfWeek` enum to the equivalent Noda Time [IsoDayOfWeek] value.
  /// Other than Sunday, the BCL and ISO values are the same - but ISO 8601 defines
  /// Sunday as day 7, and the BCL defines it as day 0.
  ///
  /// [dayOfWeek]: ISO day of week value to convert.
  ///
  /// Returns the BCL day of week value equivalent to the one passed in.
  ///
  /// Throws [RangeError] if the [dayOfWeek] parameter is not a valid day of the week.
  static IsoDayOfWeek ToIsoDayOfWeek(int dayOfWeek) {
    if (dayOfWeek < _DayOfWeekSunday || dayOfWeek > _DayOfWeekSaturday) {
      throw RangeError.value(dayOfWeek, 'dayOfWeek');
    }
    return dayOfWeek == _DayOfWeekSunday ? IsoDayOfWeek.Sunday : IsoDayOfWeek(dayOfWeek);
  }
}
