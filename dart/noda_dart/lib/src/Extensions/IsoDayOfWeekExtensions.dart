// Ported from NodaTime 6e024dde: src/NodaTime/Extensions/IsoDayOfWeekExtensions.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../IsoDayOfWeek.generated.dart';
import '../Utility/BclConversions.dart';

/// Extension methods
extension IsoDayOfWeekExtensions on IsoDayOfWeek {
  /// Converts a [IsoDayOfWeek] into the corresponding .NET `DayOfWeek` value.
  ///
  /// This is a convenience method which calls [BclConversions.ToDayOfWeek].
  ///
  /// noda_dart: the `DayOfWeek` value, 0 (Sunday) to 6.
  ///
  /// Returns the `DayOfWeek` equivalent to this value.
  int ToDayOfWeek() => BclConversions.ToDayOfWeek(this);
}
