// Ported from NodaTime 6e024dde: src/NodaTime/TimeAdjusters.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// C#'s get-only static properties holding one delegate each are static final fields.
// ignore_for_file: prefer_function_declarations_over_variables

import 'LocalTime.dart';

/// Factory class for time adjusters: functions from [LocalTime] to `LocalTime`,
/// which can be applied to [LocalTime], `LocalDateTime`, and `OffsetDateTime`.
abstract final class TimeAdjusters {
  /// Gets a time adjuster to truncate the time to the second, discarding fractional seconds.
  static final LocalTime Function(LocalTime) TruncateToSecond =
      (time) => LocalTime(time.Hour, time.Minute, time.Second);

  /// Gets a time adjuster to truncate the time to the minute, discarding fractional minutes.
  static final LocalTime Function(LocalTime) TruncateToMinute =
      (time) => LocalTime(time.Hour, time.Minute);

  /// Get a time adjuster to truncate the time to the hour, discarding fractional hours.
  static final LocalTime Function(LocalTime) TruncateToHour =
      (time) => LocalTime(time.Hour, 0);
}
