// Ported from NodaTime 6e024dde: src/NodaTime.Test/TestObjects.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Utility/Preconditions.dart';

/// Helper methods for creating objects of various kinds.
abstract final class TestObjects {
  /// Creates a positive offset from the given values.
  ///
  /// [hours]: The number of hours, in the range [0, 24).
  /// [minutes]: The number of minutes, in the range [0, 60).
  /// [seconds]: The number of seconds, in the range [0, 60).
  ///
  /// Returns a new [Offset] representing the given values.
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  static Offset CreatePositiveOffset(int hours, int minutes, int seconds) {
    Preconditions.CheckArgumentRange('hours', hours, 0, 23);
    Preconditions.CheckArgumentRange('minutes', minutes, 0, 59);
    Preconditions.CheckArgumentRange('seconds', seconds, 0, 59);
    seconds += minutes * NodaConstants.SecondsPerMinute;
    seconds += hours * NodaConstants.SecondsPerHour;
    return Offset.FromSeconds(seconds);
  }

  /// Creates a negative offset from the given values.
  ///
  /// [hours]: The number of hours, in the range [0, 24).
  /// [minutes]: The number of minutes, in the range [0, 60).
  /// [seconds]: The number of seconds, in the range [0, 60).
  ///
  /// Returns a new [Offset] representing the given values.
  ///
  /// Throws [RangeError] if the result of the operation is outside the range of Offset.
  static Offset CreateNegativeOffset(int hours, int minutes, int seconds) {
    return Offset.FromSeconds(-CreatePositiveOffset(hours, minutes, seconds).Seconds);
  }
}
