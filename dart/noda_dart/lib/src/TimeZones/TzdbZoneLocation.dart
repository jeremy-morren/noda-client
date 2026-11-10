// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/TzdbZoneLocation.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/InvalidNodaDataException.dart';
import '../Utility/Preconditions.dart';
import 'IO/IDateTimeZoneReader.dart';
import 'IO/IDateTimeZoneWriter.dart';
import 'TzdbDateTimeZoneSource.dart';

/// A location entry generated from the "zone.tab" file in a TZDB release. This can be used to provide
/// users with a choice of time zone, although it is not internationalized.
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class TzdbZoneLocation {
  final int _latitudeSeconds, _longitudeSeconds;

  /// Gets the latitude in degrees; positive for North, negative for South.
  ///
  /// The value will be in the range [-90, 90].
  double get Latitude => _latitudeSeconds / 3600.0;

  /// Gets the longitude in degrees; positive for East, negative for West.
  ///
  /// The value will be in the range [-180, 180].
  double get Longitude => _longitudeSeconds / 3600.0;

  /// Gets the English name of the country containing the location, which is never empty.
  final String CountryName;

  /// Gets the ISO-3166 2-letter country code for the country containing the location.
  final String CountryCode;

  /// The ID of the time zone for this location.
  ///
  /// If this mapping was fetched from a [TzdbDateTimeZoneSource], it will always be a valid ID within that source.
  final String ZoneId;

  /// Gets the comment (in English) for the mapping, if any.
  ///
  /// This is usually used to differentiate between locations in the same country.
  /// This will return an empty string if no comment was provided in the original data.
  final String Comment;

  /// Creates a new location.
  ///
  /// This constructor is only public for the sake of testability. Non-test code should
  /// usually obtain locations from a [TzdbDateTimeZoneSource].
  ///
  /// [latitudeSeconds]: Latitude of the location, in seconds.
  /// [longitudeSeconds]: Longitude of the location, in seconds.
  /// [countryName]: English country name of the location, in degrees. Must not be null.
  /// [countryCode]: ISO-3166 country code of the location. Must not be null.
  /// [zoneId]: Time zone identifier of the location. Must not be null.
  /// [comment]: Optional comment. Must not be null, but may be empty.
  ///
  /// Throws [RangeError] if the latitude or longitude is invalid.
  TzdbZoneLocation(int latitudeSeconds, int longitudeSeconds, String countryName, String countryCode, String zoneId,
      String comment)
      : _latitudeSeconds = latitudeSeconds,
        _longitudeSeconds = longitudeSeconds,
        // Dart: null safety checks countryName, countryCode, zoneId and comment.
        CountryName = countryName,
        CountryCode = countryCode,
        ZoneId = zoneId,
        Comment = comment {
    // Dart: C# checks the ranges before assigning the fields; nothing can be observed in between.
    Preconditions.CheckArgumentRange('latitudeSeconds', latitudeSeconds, -90 * 3600, 90 * 3600);
    Preconditions.CheckArgumentRange('longitudeSeconds', longitudeSeconds, -180 * 3600, 180 * 3600);
    Preconditions.CheckArgument(CountryName.isNotEmpty, 'countryName', 'Country name cannot be empty');
    Preconditions.CheckArgument(CountryCode.length == 2, 'countryCode', 'Country code must be two characters');
  }

  @internal
  void Write(IDateTimeZoneWriter writer) {
    writer.WriteSignedCount(_latitudeSeconds);
    writer.WriteSignedCount(_longitudeSeconds);
    writer.WriteString(CountryName);
    writer.WriteString(CountryCode);
    writer.WriteString(ZoneId);
    writer.WriteString(Comment);
  }

  @internal
  static TzdbZoneLocation Read(IDateTimeZoneReader reader) {
    int latitudeSeconds = reader.ReadSignedCount();
    int longitudeSeconds = reader.ReadSignedCount();
    String countryName = reader.ReadString();
    String countryCode = reader.ReadString();
    String zoneId = reader.ReadString();
    String comment = reader.ReadString();
    // We could duplicate the validation, but there's no good reason to. It's odd
    // to catch ArgumentException, but we're in pretty tight control of what's going on here.
    try {
      return TzdbZoneLocation(latitudeSeconds, longitudeSeconds, countryName, countryCode, zoneId, comment);
    } on ArgumentError catch (e) {
      throw InvalidNodaDataException('Invalid zone location data in stream', e);
    }
  }
}
