// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/IO/TzdbStreamData.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:collection';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../DateTimeZone.dart';
import '../../Utility/InvalidNodaDataException.dart';
import '../../Utility/Stream.dart';
import '../../Utility/SystemExceptions.dart';
import '../CachedDateTimeZone.dart';
import '../Cldr/WindowsZones.dart';
import '../FixedDateTimeZone.dart';
import '../PrecalculatedDateTimeZone.dart';
import '../TzdbZone1970Location.dart';
import '../TzdbZoneLocation.dart';
import 'DateTimeZoneReader.dart';
import 'DateTimeZoneWriter.DateTimeZoneType.generated.dart';
import 'TzdbStreamField.dart';
import 'TzdbStreamFieldId.generated.dart';

/// Provides the raw data exposed by [TzdbDateTimeZoneSource].
@internal
final class TzdbStreamData {
  static final Map<TzdbStreamFieldId, void Function(TzdbStreamDataBuilder, TzdbStreamField)> _FieldHandlers =
      <TzdbStreamFieldId, void Function(TzdbStreamDataBuilder, TzdbStreamField)>{
    TzdbStreamFieldId.StringPool: (builder, field) => builder.HandleStringPoolField(field),
    TzdbStreamFieldId.TimeZone: (builder, field) => builder.HandleZoneField(field),
    TzdbStreamFieldId.TzdbIdMap: (builder, field) => builder.HandleTzdbIdMapField(field),
    TzdbStreamFieldId.TzdbVersion: (builder, field) => builder.HandleTzdbVersionField(field),
    TzdbStreamFieldId.CldrSupplementalWindowsZones: (builder, field) => builder.HandleSupplementalWindowsZonesField(field),
    TzdbStreamFieldId.ZoneLocations: (builder, field) => builder.HandleZoneLocationsField(field),
    TzdbStreamFieldId.Zone1970Locations: (builder, field) => builder.HandleZone1970LocationsField(field)
  };

  static const int _AcceptedVersion = 0;

  final List<String> _stringPool;
  final Map<String, TzdbStreamField> _zoneFields;

  /// Returns the TZDB version string.
  final String TzdbVersion;

  /// Returns the TZDB ID dictionary (alias to canonical ID).
  final Map<String, String> TzdbIdMap;

  /// Returns the Windows mapping dictionary. (As the type is immutable, it can be exposed directly
  /// to callers.)
  final WindowsZones WindowsMapping;

  /// Returns the zone locations for the source, or null if no location data is available.
  final List<TzdbZoneLocation>? ZoneLocations;

  /// Returns the "zone 1970" locations for the source, or null if no such location data is available.
  final List<TzdbZone1970Location>? Zone1970Locations;

  @visibleForTesting
  @internal
  factory TzdbStreamData.NewBuilder(TzdbStreamDataBuilder builder) {
    var stringPool = _CheckNotNull(builder.stringPool, 'string pool');
    var mutableIdMap = _CheckNotNull(builder.tzdbIdMap, 'TZDB alias map');
    var tzdbVersion = _CheckNotNull(builder.tzdbVersion, 'TZDB version');
    var windowsMapping = _CheckNotNull(builder.windowsMapping, 'CLDR Supplemental Windows Zones');
    var zoneFields = builder.zoneFields;

    // Add in the canonical IDs as mappings to themselves.
    for (var id in zoneFields.keys) {
      mutableIdMap[id] = id;
    }
    return TzdbStreamData._(stringPool, zoneFields, tzdbVersion, UnmodifiableMapView<String, String>(mutableIdMap),
        windowsMapping, builder.zoneLocations, builder.zone1970Locations);
  }

  // Dart: the fields of TzdbStreamData(Builder), which the factory above computes as the C# constructor does.
  TzdbStreamData._(this._stringPool, this._zoneFields, this.TzdbVersion, this.TzdbIdMap, this.WindowsMapping,
      this.ZoneLocations, this.Zone1970Locations);

  /// Creates the [DateTimeZone] for the given canonical ID, which will definitely
  /// be one of the values of the TzdbAliases dictionary.
  ///
  /// [id]: ID for the returned zone, which may be an alias.
  /// [canonicalId]: Canonical ID for zone data
  DateTimeZone CreateZone(String id, String canonicalId) {
    // Dart: null safety checks id and canonicalId.
    final field = _zoneFields[canonicalId];
    if (field == null) {
      // Dart: the dictionary indexer's KeyNotFoundException.
      throw ArgumentError("The given key '$canonicalId' was not present in the dictionary.");
    }
    // Dart: C#'s using is dropped (disposing a MemoryStream releases nothing).
    var stream = field.CreateStream();
    var reader = DateTimeZoneReader.NewInputStringPool(stream, _stringPool);
    // Skip over the ID before the zone data itself
    reader.ReadString();
    var type = DateTimeZoneWriterDateTimeZoneType(reader.ReadByte());
    return switch (type) {
      DateTimeZoneWriterDateTimeZoneType.Fixed => FixedDateTimeZone.Read(reader, id),
      DateTimeZoneWriterDateTimeZoneType.Precalculated =>
        CachedDateTimeZone.ForZone(PrecalculatedDateTimeZone.Read(reader, id)),
      _ => throw InvalidNodaDataException('Unknown time zone type ${type.Name}')
    };
  }

  // Like Preconditions.CheckNotNull, but specifically for incomplete data.
  static T _CheckNotNull<T extends Object>(T? input, String name) {
    if (input == null) {
      throw InvalidNodaDataException('Incomplete TZDB data. Missing field: $name');
    }
    return input;
  }

  @internal
  static TzdbStreamData FromStream(Stream stream) {
    // Dart: null safety checks stream.

    // Dart: BinaryReader.ReadInt32 (little-endian), which throws EndOfStreamException at the end of the stream.
    int version = 0;
    for (int i = 0; i < 4; i++) {
      int b = stream.ReadByte();
      if (b == -1) {
        throw EndOfStreamException();
      }
      version |= (b & 0xff) << (8 * i);
    }
    version = version.toSigned(32);
    if (version != _AcceptedVersion) {
      throw InvalidNodaDataException('Unable to read stream with version $version');
    }
    TzdbStreamDataBuilder builder = TzdbStreamDataBuilder();
    for (var field in TzdbStreamField.ReadFields(stream)) {
      // Only handle fields we know about
      final handler = _FieldHandlers[field.Id];
      if (handler != null) {
        handler(builder, field);
      }
    }
    return TzdbStreamData.NewBuilder(builder);
  }

  /// noda_dart: reads the data from the bytes of an NZD file.
  @internal
  static TzdbStreamData FromBytes(Uint8List bytes) {
    // Dart: null safety checks bytes.
    return FromStream(MemoryStream(bytes));
  }
}

/// Mutable builder class used during parsing.
///
/// (NodaTime's nested `TzdbStreamData.Builder`.)
@visibleForTesting
@internal
class TzdbStreamDataBuilder {
  @internal
  List<String>? stringPool;
  @internal
  String? tzdbVersion;
  // Note: deliberately mutable, as this is useful later when we map the canonical IDs to themselves.
  // This is a mapping of the aliases from TZDB, at this point.
  @internal
  Map<String, String>? tzdbIdMap;
  @internal
  List<TzdbZoneLocation>? zoneLocations;
  @internal
  List<TzdbZone1970Location>? zone1970Locations;
  @internal
  WindowsZones? windowsMapping;
  @internal
  final Map<String, TzdbStreamField> zoneFields = <String, TzdbStreamField>{};

  @internal
  void HandleStringPoolField(TzdbStreamField field) {
    _CheckSingleField(field, stringPool);
    var stream = field.CreateStream();
    var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
    int count = reader.ReadCount();
    var stringPoolArray = List<String>.filled(count, '');
    for (int i = 0; i < count; i++) {
      stringPoolArray[i] = reader.ReadString();
    }
    stringPool = stringPoolArray;
  }

  @internal
  void HandleZoneField(TzdbStreamField field) {
    _CheckStringPoolPresence(field);
    // Just read the ID from the zone - we don't parse the data yet.
    // (We could, but we might as well be lazy.)
    var stream = field.CreateStream();
    var reader = DateTimeZoneReader.NewInputStringPool(stream, stringPool);
    String id = reader.ReadString();
    if (zoneFields.containsKey(id)) {
      throw InvalidNodaDataException('Multiple definitions for zone $id');
    }
    zoneFields[id] = field;
  }

  @internal
  void HandleTzdbVersionField(TzdbStreamField field) {
    _CheckSingleField(field, tzdbVersion);
    tzdbVersion = field.ExtractSingleValue((reader) => reader.ReadString(), null);
  }

  @internal
  void HandleTzdbIdMapField(TzdbStreamField field) {
    _CheckSingleField(field, tzdbIdMap);
    tzdbIdMap = field.ExtractSingleValue((reader) => reader.ReadDictionary(), stringPool);
  }

  @internal
  void HandleSupplementalWindowsZonesField(TzdbStreamField field) {
    _CheckSingleField(field, windowsMapping);
    windowsMapping = field.ExtractSingleValue(WindowsZones.Read, stringPool);
  }

  @internal
  void HandleZoneLocationsField(TzdbStreamField field) {
    _CheckSingleField(field, zoneLocations);
    _CheckStringPoolPresence(field);
    var stream = field.CreateStream();
    var reader = DateTimeZoneReader.NewInputStringPool(stream, stringPool);
    var count = reader.ReadCount();
    var array = <TzdbZoneLocation>[];
    for (int i = 0; i < count; i++) {
      array.add(TzdbZoneLocation.Read(reader));
    }
    zoneLocations = List<TzdbZoneLocation>.unmodifiable(array);
  }

  @internal
  void HandleZone1970LocationsField(TzdbStreamField field) {
    _CheckSingleField(field, zone1970Locations);
    _CheckStringPoolPresence(field);
    var stream = field.CreateStream();
    var reader = DateTimeZoneReader.NewInputStringPool(stream, stringPool);
    var count = reader.ReadCount();
    var array = <TzdbZone1970Location>[];
    for (int i = 0; i < count; i++) {
      array.add(TzdbZone1970Location.Read(reader));
    }
    zone1970Locations = List<TzdbZone1970Location>.unmodifiable(array);
  }

  static void _CheckSingleField(TzdbStreamField field, Object? expectedNullField) {
    if (expectedNullField != null) {
      throw InvalidNodaDataException('Multiple fields of ID ${field.Id.Name}');
    }
  }

  void _CheckStringPoolPresence(TzdbStreamField field) {
    if (stringPool == null) {
      throw InvalidNodaDataException('String pool must be present before field ${field.Id.Name}');
    }
  }
}
