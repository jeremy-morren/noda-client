// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/IO/TzdbStreamFieldTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/TimeZones/IO/TzdbStreamField.dart';
import 'package:noda_dart/src/Utility/InvalidNodaDataException.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TimeZones/IO/TzdbStreamFieldTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // Only tests for situations which aren't covered elsewhere

    'InsufficientData': (args) {
      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      writer.WriteByte(1);
      writer.WriteCount(10);

      stream.Position = 0;
      var iterator = TzdbStreamField.ReadFields(stream).iterator;

      Assert.Throws<InvalidNodaDataException>(() => iterator.moveNext());
    },
  });
}
