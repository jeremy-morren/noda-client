// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/ParisTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Offset.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestObjects.dart';
import '../../scenarios/TimeZones/ParisTest.generated.dart' as scenarios;
import 'TzTestHelper.dart';

// Tests for the Paris time zone. This exercises functionality within various classes.
// Paris varies between +1 (standard) and +2 (DST); transitions occur at 2am or 3am wall time,
// which is always 1am UTC.
// 2009 fall transition: October 25th
// 2010 spring transition: March 28th
// 2010 fall transition: October 31st
// 2011 spring transition: March 27th

// Make sure we deal with the uncached time zone
final DateTimeZone Paris = DateTimeZoneProviders.Tzdb['Europe/Paris'].Uncached();

// Until 1911, Paris was 9 minutes and 21 seconds off UTC.
final Offset InitialOffset = TestObjects.CreatePositiveOffset(0, 9, 21);

void main() {
  port(scenarios.fixture, {
    'FirstTransitions': (args) {
      // Paris had a name change in 1891, and then moved from +0:09:21 to UTC in 1911
      var nameChangeInstant = Instant.FromUtc(1891, 3, 15, 23, 50, 39);
      var utcChangeInstant = Instant.FromUtc(1911, 3, 10, 23, 50, 39);

      var beforeNameChange = Paris.GetZoneInterval(nameChangeInstant.MinusDuration(Duration.Epsilon));
      var afterNameChange = Paris.GetZoneInterval(nameChangeInstant);
      var afterSmallChange = Paris.GetZoneInterval(utcChangeInstant);

      Assert.AreEqual('LMT', beforeNameChange.Name);
      Assert.AreEqual(InitialOffset, beforeNameChange.WallOffset);

      Assert.AreEqual('PMT', afterNameChange.Name);
      Assert.AreEqual(InitialOffset, afterNameChange.WallOffset);

      Assert.AreEqual('WET', afterSmallChange.Name);
      Assert.AreEqual(Offset.Zero, afterSmallChange.WallOffset);
    },
  });
}
