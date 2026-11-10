// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/TzdbZone1970Location.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/HashCodeHelper.dart';
import '../Utility/InvalidNodaDataException.dart';
import '../Utility/Preconditions.dart';
import 'IO/IDateTimeZoneReader.dart';
import 'IO/IDateTimeZoneWriter.dart';
import 'TzdbDateTimeZoneSource.dart';

// Do not nest type X.
// The rule is somewhat subjective, but more importantly these have been available
// publicly for a while, so we can't change them now anyway.

/// A location entry generated from the "zone1970.tab" file in a TZDB release. This can be used to provide
/// users with a choice of time zone, although it is not internationalized. This is equivalent to
/// [TzdbZoneLocation], except that multiple countries may be represented.
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class TzdbZone1970Location {
  final int _latitudeSeconds, _longitudeSeconds;

  /// Gets the latitude in degrees; positive for North, negative for South.
  ///
  /// The value will be in the range [-90, 90].
  double get Latitude => _latitudeSeconds / 3600.0;

  /// Gets the longitude in degrees; positive for East, negative for West.
  ///
  /// The value will be in the range [-180, 180].
  double get Longitude => _longitudeSeconds / 3600.0;

  /// Gets the list of countries associated with this location.
  ///
  /// The list is immutable, and will always contain at least one entry. The list is
  /// in the order specified in "zone1970.tab", so the first entry is always the
  /// country containing the position indicated by the latitude and longitude, and
  /// is the most populous country in the list. No entry in this list is ever null.
  final List<TzdbZone1970LocationCountry> Countries;

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
  /// [countries]: Countries associated with this location. Must not be null, must have at least
  /// one entry, and all entries must be non-null.
  /// [zoneId]: Time zone identifier of the location. Must not be null.
  /// [comment]: Optional comment. Must not be null, but may be empty.
  ///
  /// Throws [RangeError] if the latitude or longitude is invalid.
  TzdbZone1970Location(int latitudeSeconds, int longitudeSeconds, Iterable<TzdbZone1970LocationCountry> countries,
      String zoneId, String comment)
      : _latitudeSeconds = latitudeSeconds,
        _longitudeSeconds = longitudeSeconds,
        // Dart: null safety checks countries (and its entries), zoneId and comment.
        Countries = List<TzdbZone1970LocationCountry>.unmodifiable(countries),
        ZoneId = zoneId,
        Comment = comment {
    // Dart: C# checks the ranges before assigning the fields; nothing can be observed in between.
    Preconditions.CheckArgumentRange('latitudeSeconds', latitudeSeconds, -90 * 3600, 90 * 3600);
    Preconditions.CheckArgumentRange('longitudeSeconds', longitudeSeconds, -180 * 3600, 180 * 3600);
    Preconditions.CheckArgument(Countries.isNotEmpty, 'countries', 'Collection must contain at least one entry');
    // Dart: null safety ensures no entry is null ("Collection must not contain null entries").
  }

  @internal
  void Write(IDateTimeZoneWriter writer) {
    writer.WriteSignedCount(_latitudeSeconds);
    writer.WriteSignedCount(_longitudeSeconds);
    writer.WriteCount(Countries.length);
    // We considered writing out the ISO-3166 file as a separate field,
    // so we can reuse objects, but we don't actually waste very much space this way,
    // due to the string pool... and the increased code complexity isn't worth it.
    for (var country in Countries) {
      writer.WriteString(country.Name);
      writer.WriteString(country.Code);
    }
    writer.WriteString(ZoneId);
    writer.WriteString(Comment);
  }

  @internal
  static TzdbZone1970Location Read(IDateTimeZoneReader reader) {
    int latitudeSeconds = reader.ReadSignedCount();
    int longitudeSeconds = reader.ReadSignedCount();
    int countryCount = reader.ReadCount();
    var countries = <TzdbZone1970LocationCountry>[];
    for (int i = 0; i < countryCount; i++) {
      String countryName = reader.ReadString();
      String countryCode = reader.ReadString();
      // Dart: C#'s named arguments (code:, name:) are passed by position.
      countries.add(TzdbZone1970LocationCountry(countryName, countryCode));
    }
    String zoneId = reader.ReadString();
    String comment = reader.ReadString();
    // We could duplicate the validation, but there's no good reason to. It's odd
    // to catch ArgumentException, but we're in pretty tight control of what's going on here.
    try {
      return TzdbZone1970Location(latitudeSeconds, longitudeSeconds, countries, zoneId, comment);
    } on ArgumentError catch (e) {
      throw InvalidNodaDataException('Invalid zone location data in stream', e);
    }
  }
}

/// A country represented within an entry in the "zone1970.tab" file, with the English name
/// mapped from the "iso3166.tab" file.
///
/// Equality is defined component-wise: two values are considered equal if their country names are equal to
/// each other, and their country codes are equal to each other.
///
/// (NodaTime's nested `TzdbZone1970Location.Country`.)
final class TzdbZone1970LocationCountry {
  /// Gets the English name of the country.
  final String Name;

  /// Gets the ISO-3166 2-letter country code for the country.
  final String Code;

  /// Constructs a new country from its name and ISO-3166 2-letter code.
  ///
  /// [name]: Country name; must not be empty.
  /// [code]: 2-letter code
  TzdbZone1970LocationCountry(String name, String code)
      // Dart: null safety checks name and code.
      : Name = name,
        Code = code {
    Preconditions.CheckArgument(Name.isNotEmpty, 'name', 'Country name cannot be empty');
    Preconditions.CheckArgument(Code.length == 2, 'code', 'Country code must be two characters');
  }

  /// Compares countries for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The country to compare with this one.
  ///
  /// Returns `true` if the given country has the same name and code as this one; `false` otherwise.
  bool Equals(TzdbZone1970LocationCountry? other) => other != null && other.Code == Code && other.Name == Name;

  /// Compares countries for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The object to compare this one with.
  ///
  /// Returns `true` if the given object is a country with the same name and code as this one; `false` otherwise.
  @override
  bool operator ==(Object other) => other is TzdbZone1970LocationCountry && Equals(other);

  /// Returns a hash code for this country.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this country.
  @override
  int get hashCode => HashCodeHelper.HashStatic(Name, Code);

  /// Returns a string representation of this country, including the code and name.
  ///
  /// Returns a string representation of this country.
  @override
  String toString() => '$Code ($Name)';
}
