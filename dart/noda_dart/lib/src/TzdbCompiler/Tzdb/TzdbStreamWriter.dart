// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/TzdbStreamWriter.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../DateTimeZone.dart';
import '../../Instant.dart';
import '../../Offset.dart';
import '../../TimeZones/CachedDateTimeZone.dart';
import '../../TimeZones/Cldr/WindowsZones.dart';
import '../../TimeZones/FixedDateTimeZone.dart';
import '../../TimeZones/IO/DateTimeZoneWriter.DateTimeZoneType.generated.dart';
import '../../TimeZones/IO/DateTimeZoneWriter.dart';
import '../../TimeZones/IO/IDateTimeZoneWriter.dart';
import '../../TimeZones/IO/TzdbStreamFieldId.generated.dart';
import '../../TimeZones/PrecalculatedDateTimeZone.dart';
import '../../TimeZones/TzdbZone1970Location.dart';
import '../../TimeZones/TzdbZoneLocation.dart';
import '../../Utility/Stream.dart';
import '../Shims.dart';
import 'TzdbDatabase.dart';

/// Writes time zone data to a stream in nzd format.
///
/// The file format consists of four bytes indicating the file format version/type (mostly for
/// future expansion), followed by a number of fields. Each field is identified by a [TzdbStreamFieldId].
/// The fields are always written in order, and the format of a field consists of its field ID, a 7-bit-encoded
/// integer with the size of the data, and then the data itself.
///
/// The version number does not need to be increased if new fields are added, as the reader will simply ignore
/// unknown fields. It only needs to be increased for incompatible changes such as a different time zone format,
/// or if old fields are removed.
@internal
final class TzdbStreamWriter {
  static const int _Version = 0;

  void Write(
    TzdbDatabase database,
    WindowsZones cldrWindowsZones,
    Map<String, String> additionalWindowsNameToIdMappings,
    Stream stream,
  ) {
    final fields = _TzdbStreamWriterFieldCollection();

    final zones = database.GenerateDateTimeZones().toList();
    final stringPool = _CreateOptimizedStringPool(zones, database.ZoneLocations, database.Zone1970Locations, cldrWindowsZones);

    // First assemble the fields (writing to the string pool as we go)
    for (final zone in zones) {
      final zoneField = fields.AddField(TzdbStreamFieldId.TimeZone, stringPool);
      _WriteZone(zone, zoneField.Writer);
    }

    fields.AddField(TzdbStreamFieldId.TzdbVersion, null).Writer.WriteString(database.Version);

    // Normalize the aliases
    final timeZoneMap = <String, String>{};
    for (final key in database.Aliases.keys) {
      var value = database.Aliases[key]!;
      while (database.Aliases.containsKey(value)) {
        value = database.Aliases[value]!;
      }
      AddValue(timeZoneMap, key, value);
    }

    fields.AddField(TzdbStreamFieldId.TzdbIdMap, stringPool).Writer.WriteDictionary(timeZoneMap);

    // Windows mappings
    cldrWindowsZones.Write(fields.AddField(TzdbStreamFieldId.CldrSupplementalWindowsZones, stringPool).Writer);
    // Additional names from Windows Standard Name to canonical ID, used in Noda Time 1.x BclDateTimeZone, when we
    // didn't have access to TimeZoneInfo.Id.
    fields.AddField(TzdbStreamFieldId.WindowsAdditionalStandardNameToIdMapping, stringPool).Writer.WriteDictionary(
        // additionalWindowsNameToIdMappings.ToDictionary(pair => pair.Key, pair => cldrWindowsZones.PrimaryMapping[pair.Value])
        {
          for (final pair in additionalWindowsNameToIdMappings.entries)
            pair.key: GetValue(cldrWindowsZones.PrimaryMapping, pair.value),
        });

    // Zone locations, if any.
    final zoneLocations = database.ZoneLocations;
    if (zoneLocations != null) {
      final field = fields.AddField(TzdbStreamFieldId.ZoneLocations, stringPool);
      field.Writer.WriteCount(zoneLocations.length);
      for (final zoneLocation in zoneLocations) {
        zoneLocation.Write(field.Writer);
      }
    }

    // Zone 1970 locations, if any.
    final zone1970Locations = database.Zone1970Locations;
    if (zone1970Locations != null) {
      final field = fields.AddField(TzdbStreamFieldId.Zone1970Locations, stringPool);
      field.Writer.WriteCount(zone1970Locations.length);
      for (final zoneLocation in zone1970Locations) {
        zoneLocation.Write(field.Writer);
      }
    }

    final stringPoolField = fields.AddField(TzdbStreamFieldId.StringPool, null);
    stringPoolField.Writer.WriteCount(stringPool.length);
    for (final value in stringPool) {
      stringPoolField.Writer.WriteString(value);
    }

    // Now write all the fields out, in the right order.
    // new BinaryWriter(stream).Write(Version): a little-endian 32-bit integer.
    stream.Write(
        Uint8List.fromList([_Version & 0xff, (_Version >> 8) & 0xff, (_Version >> 16) & 0xff, (_Version >> 24) & 0xff]),
        0,
        4);
    fields.WriteTo(stream);
  }

  static void _WriteZone(DateTimeZone zone, IDateTimeZoneWriter writer) {
    writer.WriteString(zone.Id);
    // For cached zones, simply uncache first.
    final cachedZone = zone is CachedDateTimeZone ? zone : null;
    if (cachedZone != null) {
      zone = cachedZone.TimeZone;
    }
    final fixedZone = zone is FixedDateTimeZone ? zone : null;
    if (fixedZone != null) {
      writer.WriteByte(DateTimeZoneWriterDateTimeZoneType.Fixed.value);
      fixedZone.Write(writer);
    } else {
      final precalculatedZone = zone is PrecalculatedDateTimeZone ? zone : null;
      if (precalculatedZone != null) {
        writer.WriteByte(DateTimeZoneWriterDateTimeZoneType.Precalculated.value);
        precalculatedZone.Write(writer);
      } else {
        throw ArgumentError('Unserializable DateTimeZone type ${zone.runtimeType}');
      }
    }
  }

  /// Creates a string pool which contains the most commonly-used strings within the given set
  /// of zones first. This will allow them to be more efficiently represented when we write them out for real.
  static List<String> _CreateOptimizedStringPool(
    Iterable<DateTimeZone> zones,
    Iterable<TzdbZoneLocation>? zoneLocations,
    Iterable<TzdbZone1970Location>? zone1970Locations,
    WindowsZones cldrWindowsZones,
  ) {
    final optimizingWriter = _TzdbStreamWriterStringPoolOptimizingFakeWriter();
    for (final zone in zones) {
      optimizingWriter.WriteString(zone.Id);
      _WriteZone(zone, optimizingWriter);
    }
    if (zoneLocations != null) {
      for (final location in zoneLocations) {
        location.Write(optimizingWriter);
      }
    }
    if (zone1970Locations != null) {
      for (final location in zone1970Locations) {
        location.Write(optimizingWriter);
      }
    }
    cldrWindowsZones.Write(optimizingWriter);
    return optimizingWriter.CreatePool();
  }
}

/// Writer which only cares about strings. It builds a complete list of all strings written for the given
/// zones, then creates a distinct list in most-prevalent-first order. This allows the most frequently-written
/// strings to be the ones which are cheapest to write.
///
/// (NodaTime's private nested class `TzdbStreamWriter.StringPoolOptimizingFakeWriter`.)
final class _TzdbStreamWriterStringPoolOptimizingFakeWriter implements IDateTimeZoneWriter {
  final List<String> _allStrings = <String>[];

  List<String> CreatePool() {
    // allStrings.GroupBy(x => x).OrderByDescending(g => g.Count()).Select(g => g.Key).ToList():
    // groups in order of first occurrence, then a stable sort by descending count (Dart's List.sort isn't stable, so
    // ties are ordered by first occurrence).
    final counts = <String, int>{};
    for (final value in _allStrings) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final groups = <({String key, int count, int index})>[];
    for (final MapEntry(:key, value: count) in counts.entries) {
      groups.add((key: key, count: count, index: groups.length));
    }
    groups.sort((x, y) => x.count != y.count ? y.count - x.count : x.index - y.index);
    return groups.map((g) => g.key).toList();
  }

  @override
  void WriteString(String value) {
    _allStrings.add(value);
  }

  @override
  void WriteMilliseconds(int millis) {}
  @override
  void WriteOffset(Offset offset) {}
  @override
  void WriteCount(int count) {}
  @override
  void WriteByte(int value) {}
  @override
  void WriteSignedCount(int count) {}
  @override
  void WriteZoneIntervalTransition(Instant? previous, Instant value) {}

  @override
  void WriteDictionary(Map<String, String> dictionary) {
    for (final entry in dictionary.entries) {
      WriteString(entry.key);
      WriteString(entry.value);
    }
  }
}

/// The data for a field, including the field number itself.
///
/// (NodaTime's private nested class `TzdbStreamWriter.FieldData`.)
final class _TzdbStreamWriterFieldData {
  final MemoryStream _stream;

  _TzdbStreamWriterFieldData._NewFieldIdStringPool(TzdbStreamFieldId fieldId, List<String>? stringPool)
      : this._NewFieldIdStream(fieldId, MemoryStream(), stringPool);

  // noda_dart: creates the writer in the initializer list (Dart's final fields).
  _TzdbStreamWriterFieldData._NewFieldIdStream(this.FieldId, MemoryStream stream, List<String>? stringPool)
      : _stream = stream,
        Writer = DateTimeZoneWriter.NewOutputStringPool(stream, stringPool);

  final IDateTimeZoneWriter Writer;
  final TzdbStreamFieldId FieldId;

  void WriteTo(Stream output) {
    output.WriteByte(FieldId.value);
    final length = _stream.Length;
    // We've got a 7-bit-encoding routine... might as well use it.
    DateTimeZoneWriter.NewOutputStringPool(output, null).WriteCount(length);
    _stream.WriteTo(output);
  }
}

/// (NodaTime's private nested class `TzdbStreamWriter.FieldCollection`.)
final class _TzdbStreamWriterFieldCollection {
  final List<_TzdbStreamWriterFieldData> _fields = <_TzdbStreamWriterFieldData>[];

  _TzdbStreamWriterFieldData AddField(TzdbStreamFieldId fieldNumber, List<String>? stringPool) {
    final ret = _TzdbStreamWriterFieldData._NewFieldIdStringPool(fieldNumber, stringPool);
    _fields.add(ret);
    return ret;
  }

  void WriteTo(Stream stream) {
    // fields.OrderBy(field => field.FieldId): a stable sort (Dart's List.sort isn't stable, so ties are ordered by
    // index).
    final ordered = [for (var index = 0; index < _fields.length; index++) (field: _fields[index], index: index)];
    ordered.sort((x, y) =>
        x.field.FieldId.value != y.field.FieldId.value ? x.field.FieldId.value - y.field.FieldId.value : x.index - y.index);
    for (final (:field, index: _) in ordered) {
      field.WriteTo(stream);
    }
  }
}
