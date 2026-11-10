// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IZoneIntervalMap.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Instant.dart';
import '../Offset.dart';
import 'ZoneInterval.dart';

/// The core part of a DateTimeZone: mapping an Instant to an Interval.
/// Separating this out into an interface allows for flexible caching.
///
/// Benchmarking shows that a delegate may be slightly faster here, but the difference
/// isn't very significant even for very fast calls (cache hits). The interface ends up
/// feeling slightly cleaner elsewhere in the code.
@internal
abstract interface class IZoneIntervalMap {
  ZoneInterval GetZoneInterval(Instant instant);
  Offset get MinOffset;
  Offset get MaxOffset;
}
