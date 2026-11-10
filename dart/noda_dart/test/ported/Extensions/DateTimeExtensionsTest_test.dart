// Ported from NodaTime 6e024dde: src/NodaTime.Test/Extensions/DateTimeExtensionsTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator (no cases); plain [Test]s run with `runExcluded`. Non-UTC DateTimes are local.

import 'dart:core';
import 'dart:core' as core;

import 'package:noda_dart/src/Extensions/DateTimeExtensions.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Extensions/DateTimeExtensionsTest.generated.dart' as scenarios;

final core.DateTime DateTimeLocal = core.DateTime(2017, 8, 21, 12, 46, 13);
final core.DateTime DateTimeUnspecified = core.DateTime(2017, 8, 21, 12, 46, 13);
final core.DateTime DateTimeUtc = core.DateTime.utc(2017, 8, 21, 12, 46, 13);

void main() {
  port(scenarios.fixture, {
    'ToLocalDateTime_LocalKind': (args) {
      var expected = LocalDateTime(2017, 8, 21, 12, 46, 13);
      var actual = DateTimeLocal.ToLocalDateTime();
      Assert.AreEqual(expected, actual);
    },

    'ToLocalDateTime_UnspecifiedKind': (args) {
      var expected = LocalDateTime(2017, 8, 21, 12, 46, 13);
      var actual = DateTimeUnspecified.ToLocalDateTime();
      Assert.AreEqual(expected, actual);
    },

    'ToLocalDateTime_UtcKind': (args) {
      var expected = LocalDateTime(2017, 8, 21, 12, 46, 13);
      var actual = DateTimeUtc.ToLocalDateTime();
      Assert.AreEqual(expected, actual);
    },

    'ToInstant_LocalKind': (args) => Assert.Throws<ArgumentError>(() => DateTimeLocal.ToInstant()),

    'ToInstant_UnspecifiedKind': (args) => Assert.Throws<ArgumentError>(() => DateTimeUnspecified.ToInstant()),

    'ToInstant_UtcKind': (args) {
      var expected = Instant.FromUtc(2017, 8, 21, 12, 46, 13);
      var actual = DateTimeUtc.ToInstant();
      Assert.AreEqual(expected, actual);
    },
  }, runExcluded: true);
}
