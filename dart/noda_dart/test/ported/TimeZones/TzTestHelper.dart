// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/TzTestHelper.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/CachedDateTimeZone.dart';

/// Extension methods to help with time zone testing, and other helper methods.
extension TzTestHelper on DateTimeZone {
  /// Returns the uncached version of the given zone. If the zone isn't
  /// an instance of CachedDateTimeZone, the same reference is returned back.
  DateTimeZone Uncached() {
    var cached = this is CachedDateTimeZone ? this as CachedDateTimeZone : null;
    return cached == null ? this : cached.TimeZone;
  }
}
