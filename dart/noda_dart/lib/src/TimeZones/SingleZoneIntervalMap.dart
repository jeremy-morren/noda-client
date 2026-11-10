// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/SingleZoneIntervalMap.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Instant.dart';
import '../Offset.dart';
import 'IZoneIntervalMap.dart';
import 'ZoneInterval.dart';

/// Implementation of IZoneIntervalMap which just returns a single interval (provided on construction) regardless of
/// the instant requested.
@internal
final class SingleZoneIntervalMap implements IZoneIntervalMap {
  final ZoneInterval _interval;

  @override
  Offset get MinOffset => _interval.WallOffset;
  @override
  Offset get MaxOffset => _interval.WallOffset;

  @internal
  SingleZoneIntervalMap.NewInterval(ZoneInterval interval) : _interval = interval;

  @override
  ZoneInterval GetZoneInterval(Instant instant) => _interval;
}
