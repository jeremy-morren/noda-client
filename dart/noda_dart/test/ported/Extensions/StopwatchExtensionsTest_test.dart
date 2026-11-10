// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/StopwatchExtensionsTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator; runs with `runExcluded`. No sync sleep on the web, so it awaits 1ms.

import 'dart:core';
import 'dart:core' as core;

import 'package:noda_dart/src/Extensions/StopwatchExtensions.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/StopwatchExtensionsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'ElapsedDuration': (args) async {
      var stopwatch = core.Stopwatch()..start();
      await Future<void>.delayed(const core.Duration(milliseconds: 1));
      stopwatch.stop();
      var duration = stopwatch.ElapsedDuration();
      var timespan = stopwatch.elapsed;
      Assert.AreEqual(timespan.inMicroseconds * 10, duration.BclCompatibleTicks);
    },
  }, runExcluded: true);
}
