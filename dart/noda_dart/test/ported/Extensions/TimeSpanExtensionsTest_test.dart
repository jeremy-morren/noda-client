// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/TimeSpanExtensionsTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator; runs with `runExcluded`. core.Duration counts microseconds: 123456789012340.

import 'dart:core';
import 'dart:core' as core;

import 'package:noda_dart/src/Extensions/TimeSpanExtensions.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/TimeSpanExtensionsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'ToDuration': (args) {
      var timeSpan = core.Duration(microseconds: 12345678901234);
      var duration = timeSpan.ToDuration();
      Assert.AreEqual(123456789012340, duration.BclCompatibleTicks);
    },
  }, runExcluded: true);
}
