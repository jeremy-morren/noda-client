// Ported from NodaTime 6e024dde: src/NodaTime/Extensions/DateTimeZoneProviderExtensions.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../DateTimeZone.dart';
import '../IDateTimeZoneProvider.dart';

/// Extensions for [IDateTimeZoneProvider]
extension DateTimeZoneProviderExtensions on IDateTimeZoneProvider {
  /// Returns a lazily-evaluated sequence of time zones from the specified provider,
  /// in the same order in which the IDs are returned by the provider.
  ///
  /// Returns all the time zones from the provider.
  Iterable<DateTimeZone> GetAllZones() {
    // Dart: null safety checks provider.
    return Ids.map((id) => this[id]);
  }
}
