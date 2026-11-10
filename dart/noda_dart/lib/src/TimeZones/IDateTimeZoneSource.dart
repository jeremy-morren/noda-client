// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IDateTimeZoneSource.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../DateTimeZone.dart';

/// Provides the interface for objects that can retrieve time zone definitions given an ID.
///
/// The interface presumes that the available time zones are static; there is no mechanism for
/// updating the list of available time zones. Any time zone ID that is returned in [GetIds]
/// must be resolved by [ForId] for the life of the source.
///
/// Implementations need not cache time zones or the available time zone IDs.
/// Caching is typically provided by [DateTimeZoneCache], which most consumers should use instead of
/// consuming [IDateTimeZoneSource] directly in order to get better performance.
///
/// It is expected that any exceptions thrown are implementation-specific; nothing is explicitly
/// specified in the interface. Typically this would be unusual to the point that callers would not
/// try to catch them; any implementation which may break in ways that are sensible to catch should advertise
/// this clearly, so that clients will know to handle the exceptions appropriately. No wrapper exception
/// type is provided by Noda Time to handle this situation, and code in Noda Time does not try to catch
/// such exceptions.
abstract interface class IDateTimeZoneSource {
  /// Returns an unordered enumeration of the IDs available from this source.
  ///
  /// Every value in this enumeration must return a valid time zone from [ForId] for the life of the source.
  /// The enumeration may be empty, but must not be null, and must not contain any elements which are null.  It
  /// should not contain duplicates: this is not enforced, and while it may not have a significant impact on
  /// clients in some cases, it is generally unfriendly.  The built-in implementations never return duplicates.
  ///
  /// The source is not required to provide the IDs in any particular order, although they should be distinct.
  ///
  /// Note that this list may optionally contain any of the fixed-offset timezones (with IDs "UTC" and
  /// "UTC+/-Offset"), but there is no requirement they be included.
  ///
  /// Returns the IDs available from this source.
  Iterable<String> GetIds();

  /// Returns an appropriate version ID for diagnostic purposes, which must not be null.
  ///
  /// This doesn't have any specific format; it's solely for diagnostic purposes.
  /// The included sources return strings of the format "source identifier: source version" indicating where the
  /// information comes from and which version of the source information has been loaded.
  String get VersionId;

  /// Returns the time zone definition associated with the given ID.
  ///
  /// Note that this is permitted to return a [DateTimeZone] that has a different ID to that
  /// requested, if the ID provided is an alias.
  ///
  /// Note also that this method is not required to return the same [DateTimeZone] instance for
  /// successive requests for the same ID; however, all instances returned for a given ID must compare as equal.
  ///
  /// It is advised that sources should document their behaviour regarding any fixed-offset timezones
  /// (i.e. "UTC" and "UTC+/-Offset") that are included in the list returned by [GetIds].
  /// (These IDs will not be requested by [DateTimeZoneCache], but any users calling
  /// into the source directly may care.)
  ///
  /// The source need not attempt to cache time zones; caching is typically provided by
  /// [DateTimeZoneCache].
  ///
  /// [id]: The ID of the time zone to return. This must be one of the IDs
  /// returned by [GetIds].
  ///
  /// Returns the [DateTimeZone] for the given ID.
  ///
  /// Throws [ArgumentError] if [id] is not supported by this source.
  DateTimeZone ForId(String id);

  /// Returns this source's ID for the system default time zone.
  ///
  /// Returns the ID for the system default time zone for this source,
  /// or null if the system default time zone has no mapping in this source.
  String? GetSystemDefaultId();
}
