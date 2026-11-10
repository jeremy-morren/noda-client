// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/EraTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the eras (found by reflection in C#) arrive as NamedWrapper<Era> values.

import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/NamedWrapper.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/EraTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'ResourcePresence': (args) {
      final [NamedWrapper<Era> eraWrapper] = args;
      var era = eraWrapper.Value;
      var valueByName = NodaCultureInfo.InvariantCulture.GetPatternResource(era.ResourceIdentifier);
      Assert.NotNull(valueByName, 'Missing resource for ${era.ResourceIdentifier}');
    },

    'ToStringReturnsName': (args) {
      final [NamedWrapper<Era> eraWrapper] = args;
      var era = eraWrapper.Value;
      Assert.AreEqual(era.Name, era.toString());
    },
  });
}
