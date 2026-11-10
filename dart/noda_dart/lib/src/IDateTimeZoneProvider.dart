// Ported from NodaTime 6e024dde: src/NodaTime/IDateTimeZoneProvider.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'DateTimeZone.dart';

/// Provides stable, performant time zone data.
///
/// Consumers should be able to treat an [IDateTimeZoneProvider] like a cache:
/// lookups should be quick (after at most one lookup of a given ID), and multiple calls for a given ID must
/// always return references to equal instances, even if they are not references to a single instance.
/// Consumers should not feel the need to cache data accessed through this interface.
///
/// Implementations designed to work with any `IDateTimeZoneSource` implementation (such as
/// `DateTimeZoneCache`) should not attempt to handle exceptions thrown by the source. A source-specific
/// provider may do so, as it has more detailed knowledge of what can go wrong and how it can best be handled.
abstract interface class IDateTimeZoneProvider {
  /// Gets the version ID of this provider.
  String get VersionId;

  /// Gets the list of valid time zone ids advertised by this provider.
  ///
  /// This list will be sorted in ordinal lexicographic order. It cannot be modified by callers, and
  /// must not be modified by the provider either: client code can safely treat it as thread-safe
  /// and deeply immutable.
  ///
  /// In addition to the list returned here, providers always support the fixed-offset timezones with IDs "UTC"
  /// and "UTC+/-Offset". These may or may not be included explicitly in this list.
  List<String> get Ids;

  /// Gets the time zone from this provider that matches the system default time zone, if a matching time zone is
  /// available.
  ///
  /// Callers should be aware that this method will throw `DateTimeZoneNotFoundException` if no matching
  /// time zone is found. For the built-in Noda Time providers, this is unlikely to occur in practice (assuming
  /// the system is using a standard Windows time zone), but can occur even then, if no mapping is found. The TZDB
  /// source contains mappings for almost all Windows system time zones, but a few (such as "Mid-Atlantic Standard Time")
  /// are unmappable.
  ///
  /// If it is necessary to handle this case, callers can construct a
  /// `SystemDateTimeZone` (NodaTime's `BclDateTimeZone`) via `SystemDateTimeZone.ForSystemDefault`, which returns a
  /// [DateTimeZone] that wraps the system local time zone, and which always
  /// succeeds.
  ///
  /// Throws `DateTimeZoneNotFoundException` if the system default time zone is not mapped by
  /// this provider.
  ///
  /// Returns the provider-specific representation of the system default time zone.
  DateTimeZone GetSystemDefault();

  /// Returns the time zone for the given ID, if it's available.
  ///
  /// Note that this may return a [DateTimeZone] that has a different ID to that requested, if the ID
  /// provided is an alias.
  ///
  /// Note also that this method is not required to return the same [DateTimeZone] instance for
  /// successive requests for the same ID; however, all instances returned for a given ID must compare
  /// as equal.
  ///
  /// The fixed-offset timezones with IDs "UTC" and "UTC+/-Offset" are always available.
  ///
  /// [id]: The time zone ID to find.
  ///
  /// Returns the [DateTimeZone] for the given ID or null if the provider does not support
  /// the given ID.
  DateTimeZone? GetZoneOrNull(String id);

  /// Returns the time zone for the given ID.
  ///
  /// Unlike [GetZoneOrNull], this indexer will never return a null reference. If the ID is not
  /// supported by this provider, it will throw `DateTimeZoneNotFoundException`.
  ///
  /// Note that this may return a [DateTimeZone] that has a different ID to that requested, if the ID
  /// provided is an alias.
  ///
  /// Note also that this method is not required to return the same [DateTimeZone] instance for
  /// successive requests for the same ID; however, all instances returned for a given ID must compare
  /// as equal.
  ///
  /// The fixed-offset timezones with IDs "UTC" and "UTC+/-Offset" are always available.
  ///
  /// [id]: The time zone id to find.
  ///
  /// Throws `DateTimeZoneNotFoundException` if this provider does not support the given ID.
  DateTimeZone operator [](String id);
}
