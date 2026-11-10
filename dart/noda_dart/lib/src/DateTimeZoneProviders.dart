// Ported from NodaTime 6e024dde: src/NodaTime/DateTimeZoneProviders.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'IDateTimeZoneProvider.dart';
import 'TimeZones/DateTimeZoneCache.dart';
import 'TimeZones/TzdbDateTimeZoneSource.dart';

/// Static access to date/time zone providers built into Noda Time and for global configuration where this is unavoidable.
/// All properties are thread-safe, and the providers returned by the read-only properties cache their results.
abstract final class DateTimeZoneProviders {
  /// Gets a time zone provider which uses a [TzdbDateTimeZoneSource].
  /// The underlying source is [TzdbDateTimeZoneSource.Default], which is initialized from
  /// resources within the NodaTime assembly.
  ///
  /// noda_dart: the bundled tzdb data, decoded on first use.
  static IDateTimeZoneProvider get Tzdb => _TzdbHolder.TzdbImpl;

  // Not ported: Bcl (see `package:noda_dart/system.dart`).

  // Not ported: Serialization (obsolete; XML serialization isn't ported).
}

// This class exists to force TZDB initialization to be lazy. We don't want using
// DateTimeZoneProviders.Bcl to force a read/parse of TZDB data.
// (Dart: a static final field is initialized on first use.)
abstract final class _TzdbHolder {
  static final DateTimeZoneCache TzdbImpl = DateTimeZoneCache(TzdbDateTimeZoneSource.Default);
}
