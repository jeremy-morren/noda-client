// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/IO/TzdbStreamDataTest.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: no reflection: handlers are looked up in a table (_GetMethod), so errors aren't wrapped.

import 'dart:typed_data';

import 'package:noda_dart/src/TimeZones/Cldr/MapZone.dart';
import 'package:noda_dart/src/TimeZones/Cldr/WindowsZones.dart';
import 'package:noda_dart/src/TimeZones/IO/TzdbStreamData.dart';
import 'package:noda_dart/src/TimeZones/IO/TzdbStreamField.dart';
import 'package:noda_dart/src/TimeZones/IO/TzdbStreamFieldId.generated.dart';
import 'package:noda_dart/src/Utility/InvalidNodaDataException.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TimeZones/IO/TzdbStreamDataTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Minimal': (args) {
      var data = TzdbStreamData.NewBuilder(CreateMinimalBuilder());
      Assert.NotNull(data.TzdbVersion);
    },

    'MissingStringPool()': (args) {
      var builder = CreateMinimalBuilder();
      builder.stringPool = null;
      Assert.Throws<InvalidNodaDataException>(() => TzdbStreamData.NewBuilder(builder));
    },

    'MissingTzdbAliasMap': (args) {
      var builder = CreateMinimalBuilder();
      builder.tzdbIdMap = null;
      Assert.Throws<InvalidNodaDataException>(() => TzdbStreamData.NewBuilder(builder));
    },

    'MissingTzdbVersion': (args) {
      var builder = CreateMinimalBuilder();
      builder.tzdbVersion = null;
      Assert.Throws<InvalidNodaDataException>(() => TzdbStreamData.NewBuilder(builder));
    },

    'MissingWindowsMapping': (args) {
      var builder = CreateMinimalBuilder();
      builder.windowsMapping = null;
      Assert.Throws<InvalidNodaDataException>(() => TzdbStreamData.NewBuilder(builder));
    },

    'InvalidVersion': (args) {
      // It's hard to create a stream that's valid apart from the version, so we'll just
      // give one with an invalid version and check that it looks like the right message.
      var stream = MemoryStream(Uint8List.fromList([0, 0, 0, 1]));
      var exception = Assert.Throws<InvalidNodaDataException>(() => TzdbStreamData.FromStream(stream));
      Assert.IsTrue(exception.message.contains('version'));
    },

    'MissingStringPool(object, string)': (args) {
      final [Object fieldIdObject, String handlerMethodName] = args;
      var fieldId = TzdbStreamFieldId(fieldIdObject as int);
      var field = TzdbStreamField.NewIdData(fieldId, Uint8List(1));
      var builder = TzdbStreamDataBuilder();
      var method = _GetMethod(builder, handlerMethodName) ?? (throw Exception("Can't find method $handlerMethodName"));

      Assert.Throws<InvalidNodaDataException>(() => method(field));
    },

    // Note: we don't test this with a CldrSupplementalWindowsZones field, as they're both awkward to build.
    // All other fields are valid with a single byte of 0, which is usually a count. This is very convenient.
    'DuplicateField': (args) {
      final [Object fieldIdObject, String handlerMethodName] = args;
      var fieldId = TzdbStreamFieldId(fieldIdObject as int);

      var field = TzdbStreamField.NewIdData(fieldId, Uint8List(1));
      var builder = TzdbStreamDataBuilder();
      var method =
          _GetMethod(builder, handlerMethodName) ?? (throw Exception("Can't find handler method $handlerMethodName"));
      // Provide an empty string pool if we're not checking for a duplicate string pool.
      if (fieldId != TzdbStreamFieldId.StringPool) {
        builder.stringPool = <String>[];
      }

      // First call should be okay
      method(field);

      // Second call should throw
      Assert.Throws<InvalidNodaDataException>(() => method(field));
    },

    'DuplicateTimeZoneField': (args) {
      // This isn't really a valid field, but we don't parse the data yet anyway - it's
      // enough to give the ID.
      var zoneField = TzdbStreamField.NewIdData(TzdbStreamFieldId.StringPool, Uint8List(1));

      var builder = TzdbStreamDataBuilder();
      builder.stringPool = <String>['zone1'];
      builder.HandleZoneField(zoneField);
      Assert.Throws<InvalidNodaDataException>(() => builder.HandleZoneField(zoneField));
    },
  });
}

TzdbStreamDataBuilder CreateMinimalBuilder() => TzdbStreamDataBuilder()
  ..stringPool = <String>[]
  ..tzdbIdMap = <String, String>{}
  ..tzdbVersion = 'tzdb-version'
  ..windowsMapping = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones(
      'cldr-version', 'tzdb-version', 'windows-version', <MapZone>[]);

/// noda_dart: `typeof(TzdbStreamData.Builder).GetMethod(handlerMethodName, ...)`, bound to [builder].
void Function(TzdbStreamField)? _GetMethod(TzdbStreamDataBuilder builder, String handlerMethodName) =>
    switch (handlerMethodName) {
      'HandleStringPoolField' => builder.HandleStringPoolField,
      'HandleZoneField' => builder.HandleZoneField,
      'HandleTzdbVersionField' => builder.HandleTzdbVersionField,
      'HandleTzdbIdMapField' => builder.HandleTzdbIdMapField,
      'HandleSupplementalWindowsZonesField' => builder.HandleSupplementalWindowsZonesField,
      'HandleZoneLocationsField' => builder.HandleZoneLocationsField,
      'HandleZone1970LocationsField' => builder.HandleZone1970LocationsField,
      _ => null,
    };
