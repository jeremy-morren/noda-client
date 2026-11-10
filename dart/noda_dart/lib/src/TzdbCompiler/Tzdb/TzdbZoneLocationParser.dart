// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/TzdbZoneLocationParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../TimeZones/TzdbZone1970Location.dart';
import '../../TimeZones/TzdbZoneLocation.dart';
import '../../Utility/Preconditions.dart';
import '../Shims.dart';

/// Separate class for parsing zone location data from zone.tab and iso3166.tab.
/// Stateless, simply static methods - only separated from TzdbZoneInfoCompiler to make the
/// organization a little cleaner.
@internal
abstract final class TzdbZoneLocationParser {
  static TzdbZoneLocation ParseLocation(String line, Map<String, String> countryMapping) {
    final bits = line.split('\t');
    Preconditions.CheckArgument(bits.length == 3 || bits.length == 4, 'line', 'Line must have 3 or 4 tab-separated values');
    final countryCode = bits[0];
    final countryName = GetValue(countryMapping, countryCode);
    final latLong = ParseCoordinates(bits[1]);
    final zoneId = bits[2];
    final comment = bits.length == 4 ? bits[3] : '';
    return TzdbZoneLocation(latLong[0], latLong[1], countryName, countryCode, zoneId, comment);
  }

  static TzdbZone1970Location ParseEnhancedLocation(String line, Map<String, TzdbZone1970LocationCountry> countryMapping) {
    final bits = line.split('\t');
    Preconditions.CheckArgument(bits.length == 3 || bits.length == 4, 'line', 'Line must have 3 or 4 tab-separated values');
    final countryCodes = bits[0];
    final countries = countryCodes.split(',').map((code) => GetValue(countryMapping, code)).toList();
    final latLong = ParseCoordinates(bits[1]);
    final zoneId = bits[2];
    final comment = bits.length == 4 ? bits[3] : '';
    return TzdbZone1970Location(latLong[0], latLong[1], countries, zoneId, comment);
  }

  // Internal for testing
  /// Parses a string such as "-7750+16636" or "+484531-0913718" into a pair of Int32
  /// values: the latitude and longitude of the coordinates, in seconds.
  static List<int> ParseCoordinates(String text) {
    Preconditions.CheckArgument(text.length == 11 || text.length == 15, 'point', 'Invalid coordinates');
    int latDegrees;
    int latMinutes;
    var latSeconds = 0;
    int latSign;
    int longDegrees;
    int longMinutes;
    var longSeconds = 0;
    int longSign;

    if (text.length == 11 /* +-DDMM+-DDDMM */) {
      latSign = text[0] == '-' ? -1 : 1;
      latDegrees = ParseInt32(text.substring(1, 3));
      latMinutes = ParseInt32(text.substring(3, 5));
      longSign = text[5] == '-' ? -1 : 1;
      longDegrees = ParseInt32(text.substring(6, 9));
      longMinutes = ParseInt32(text.substring(9, 11));
    } else /* +-DDMMSS+-DDDMMSS */ {
      latSign = text[0] == '-' ? -1 : 1;
      latDegrees = ParseInt32(text.substring(1, 3));
      latMinutes = ParseInt32(text.substring(3, 5));
      latSeconds = ParseInt32(text.substring(5, 7));
      longSign = text[7] == '-' ? -1 : 1;
      longDegrees = ParseInt32(text.substring(8, 11));
      longMinutes = ParseInt32(text.substring(11, 13));
      longSeconds = ParseInt32(text.substring(13, 15));
    }
    return [
      latSign * (latDegrees * 3600 + latMinutes * 60 + latSeconds),
      longSign * (longDegrees * 3600 + longMinutes * 60 + longSeconds),
    ];
  }
}
